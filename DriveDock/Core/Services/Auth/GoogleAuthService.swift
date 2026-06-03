import Foundation
import AppKit
import CryptoKit

// MARK: - Simple OAuth HTTP Server

final class OAuthHTTPServer {
    private var serverSocket: Int32 = -1
    private var callbackHandler: ((String) -> Void)?
    private var running = false
    private let port: UInt16 = 18923

    func start(handler: @escaping (String) -> Void) -> Bool {
        self.callbackHandler = handler

        // Create socket
        serverSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard serverSocket >= 0 else {
            print("[OAuth] Failed to create socket: \(errno)")
            return false
        }

        // Allow address reuse
        var reuse: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        // Bind
        var addr = sockaddr_in()
        addr.sin_family = UInt8(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            print("[OAuth] Failed to bind to port \(port): \(errno)")
            Darwin.close(serverSocket)
            serverSocket = -1
            return false
        }

        // Listen
        guard listen(serverSocket, 1) == 0 else {
            print("[OAuth] Failed to listen: \(errno)")
            Darwin.close(serverSocket)
            serverSocket = -1
            return false
        }

        running = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.acceptConnections()
        }

        print("[OAuth] Server started on port \(port)")
        return true
    }

    func stop() {
        running = false
        if serverSocket >= 0 {
            Darwin.shutdown(serverSocket, SHUT_RDWR)
            Darwin.close(serverSocket)
            serverSocket = -1
        }
    }

    private func acceptConnections() {
        while running {
            var clientAddr = sockaddr_in()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let client = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.accept(serverSocket, $0, &clientAddrLen)
                }
            }

            guard client >= 0 else {
                if running { continue }
                break
            }

            handleClient(client)
        }
    }

    private func handleClient(_ client: Int32) {
        // Set receive timeout
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = recv(client, &buffer, buffer.count - 1, 0)

        guard bytesRead > 0 else {
            Darwin.close(client)
            return
        }

        let request = String(cString: buffer)

        // Parse: GET /oauth2callback?code=XXX&state=YYY HTTP/1.1
        guard let firstLine = request.components(separatedBy: "\r\n").first,
              firstLine.hasPrefix("GET ") else {
            sendResponse(client, status: "400 Bad Request", body: "Bad Request")
            Darwin.close(client)
            return
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(client, status: "400 Bad Request", body: "Bad Request")
            Darwin.close(client)
            return
        }

        let path = parts[1]

        if path.contains("/oauth2callback") && path.contains("code=") {
            let callbackURL = "http://127.0.0.1:\(port)\(path)"

            let html = """
            <!DOCTYPE html><html><head><meta charset="utf-8"><title>DriveDock - Connected</title>
            <style>body{font-family:-apple-system,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:linear-gradient(135deg,#1a9f4d,#0d7a3a);color:white;text-align:center}.box{padding:60px;border-radius:24px;background:rgba(255,255,255,0.12)}h1{font-size:2.5em;margin:0 0 10px}.check{font-size:5em}</style>
            </head><body><div class="box"><div class="check">&#10003;</div><h1>Connected!</h1><p>Close this tab and return to DriveDock.</p></div></body></html>
            """

            sendResponse(client, status: "200 OK", body: html)

            DispatchQueue.main.async { [weak self] in
                self?.callbackHandler?(callbackURL)
            }
        } else {
            sendResponse(client, status: "404 Not Found", body: "Not Found")
        }

        Darwin.close(client)
    }

    private func sendResponse(_ client: Int32, status: String, body: String) {
        let response = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        response.withCString { ptr in
            _ = Darwin.send(client, ptr, strlen(ptr), 0)
        }
    }
}

// MARK: - OAuth Models

struct OAuthTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let scope: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
        case tokenType = "token_type"
    }
}

struct OAuthUserInfo: Codable {
    let id: String
    let email: String
    let name: String?
    let picture: String?

    enum CodingKeys: String, CodingKey {
        case id, email, name, picture
    }
}

struct StoredToken: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
}

// MARK: - Google Auth Service

@Observable
final class GoogleAuthService {
    static let shared = GoogleAuthService()

    private let keychain = KeychainService.shared
    let clientID: String
    let clientSecret: String
    private let redirectURI = "http://127.0.0.1:18923/oauth2callback"

    private let scopes = [
        "https://www.googleapis.com/auth/drive.file",
        "https://www.googleapis.com/auth/drive.readonly",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile"
    ]

    private(set) var accounts: [DriveAccount] = []
    private(set) var activeAccount: DriveAccount?
    private(set) var isAuthenticating = false
    private(set) var authError: String?

    private var codeVerifier: String?
    private var pendingAuthContinuation: CheckedContinuation<Void, Error>?
    private var callbackServer: OAuthHTTPServer?
    private var activeRefreshTasks: [String: Task<String, Error>] = [:]

    private init() {
        self.clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String ?? ""
        self.clientSecret = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_SECRET") as? String ?? ""
        loadAccounts()
    }

    // MARK: - OAuth Flow

    func startAuthentication() async throws {
        isAuthenticating = true
        authError = nil

        codeVerifier = generateCodeVerifier()
        guard let verifier = codeVerifier else {
            isAuthenticating = false
            throw AuthError.codeVerifierGenerationFailed
        }

        let codeChallenge = generateCodeChallenge(from: verifier)

        // Start local HTTP server
        let server = OAuthHTTPServer()
        let started = server.start { [weak self] callbackURL in
            Task { @MainActor in
                self?.handleOAuthCallback(callbackURL)
            }
        }

        guard started else {
            isAuthenticating = false
            throw AuthError.serverStartFailed
        }
        self.callbackServer = server

        // Build OAuth URL
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let url = components.url else {
            isAuthenticating = false
            server.stop()
            throw AuthError.invalidAuthURL
        }

        // Open browser
        NSWorkspace.shared.open(url)

        // Wait for callback
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.pendingAuthContinuation = continuation
        }
    }

    func cancelAuthentication() {
        isAuthenticating = false
        callbackServer?.stop()
        callbackServer = nil
        pendingAuthContinuation?.resume(throwing: AuthError.userCancelled)
        pendingAuthContinuation = nil
    }

    // MARK: - Token Management

    func getAccessToken(for accountID: String) async throws -> String {
        guard let tokenData = try? keychain.loadString(key: "token_\(accountID)") else {
            throw AuthError.noToken
        }
        guard let data = tokenData.data(using: .utf8),
              let token = try? JSONDecoder().decode(StoredToken.self, from: data) else {
            throw AuthError.tokenDecodingFailed
        }
        if let expiresAt = token.expiresAt, Date() < expiresAt.addingTimeInterval(-120) {
            return token.accessToken
        }
        guard let refreshToken = token.refreshToken else {
            updateAccountStatus(accountID, status: .expired)
            throw AuthError.tokenExpired
        }
        if let existingTask = activeRefreshTasks[accountID] {
            return try await existingTask.value
        }
        let task = Task<String, Error> {
            defer { activeRefreshTasks.removeValue(forKey: accountID) }
            return try await refreshAccessTokenWithRetry(refreshToken: refreshToken, accountID: accountID)
        }
        activeRefreshTasks[accountID] = task
        return try await task.value
    }

    func disconnectAccount(_ accountID: String) throws {
        try? keychain.delete(key: "token_\(accountID)")
        accounts.removeAll { $0.id == accountID }
        if activeAccount?.id == accountID {
            activeAccount = accounts.first
        }
        saveAccountList()
    }

    func setActiveAccount(_ account: DriveAccount) {
        activeAccount = account
    }

    func updateAccountStatus(_ accountID: String, status: DriveAccount.TokenStatus) {
        if let index = accounts.firstIndex(where: { $0.id == accountID }) {
            accounts[index].tokenStatus = status
            if activeAccount?.id == accountID {
                activeAccount = accounts[index]
            }
            saveAccountList()
        }
    }

    // MARK: - Private

    private func handleOAuthCallback(_ urlString: String) {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            isAuthenticating = false
            authError = "Invalid callback"
            callbackServer?.stop()
            callbackServer = nil
            pendingAuthContinuation?.resume(throwing: AuthError.invalidCallback)
            pendingAuthContinuation = nil
            return
        }

        guard let verifier = codeVerifier else {
            isAuthenticating = false
            authError = "Code verifier lost"
            callbackServer?.stop()
            callbackServer = nil
            pendingAuthContinuation?.resume(throwing: AuthError.noCodeVerifier)
            pendingAuthContinuation = nil
            return
        }

        Task {
            do {
                let tokenResponse = try await exchangeCodeForTokens(code: code, codeVerifier: verifier)
                let userInfo = try await fetchUserInfo(accessToken: tokenResponse.accessToken)

                let account = DriveAccount(
                    id: userInfo.id,
                    email: userInfo.email,
                    displayName: userInfo.name ?? userInfo.email,
                    avatarURL: userInfo.picture.flatMap(URL.init),
                    connectedDate: Date(),
                    isActive: true,
                    tokenStatus: .valid
                )

                try saveTokens(accountID: account.id, response: tokenResponse)

                if !accounts.contains(where: { $0.id == account.id }) {
                    accounts.append(account)
                }
                activeAccount = account
                saveAccountList()

                await MainActor.run {
                    isAuthenticating = false
                    callbackServer?.stop()
                    callbackServer = nil
                    pendingAuthContinuation?.resume()
                    pendingAuthContinuation = nil
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    authError = error.localizedDescription
                    callbackServer?.stop()
                    callbackServer = nil
                    pendingAuthContinuation?.resume(throwing: error)
                    pendingAuthContinuation = nil
                }
            }
        }
    }

    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> OAuthTokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code": code,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            print("[OAuth] Token exchange failed: \(msg)")
            throw AuthError.tokenExchangeFailed
        }

        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }

    private func refreshAccessTokenWithRetry(refreshToken: String, accountID: String, retries: Int = 3) async throws -> String {
        var lastError: Error?
        for attempt in 0..<retries {
            do {
                return try await refreshAccessToken(refreshToken: refreshToken, accountID: accountID)
            } catch {
                lastError = error
                if attempt < retries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                }
            }
        }
        throw lastError ?? AuthError.tokenRefreshFailed
    }

    private func refreshAccessToken(refreshToken: String, accountID: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "refresh_token": refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret,
            "grant_type": "refresh_token"
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            updateAccountStatus(accountID, status: .expired)
            throw AuthError.tokenRefreshFailed
        }

        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)

        let stored = StoredToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )
        let storedData = try JSONEncoder().encode(stored)
        try keychain.save(storedData, for: "token_\(accountID)")

        updateAccountStatus(accountID, status: .valid)
        return tokenResponse.accessToken
    }

    private func fetchUserInfo(accessToken: String) async throws -> OAuthUserInfo {
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.userInfoFailed
        }

        return try JSONDecoder().decode(OAuthUserInfo.self, from: data)
    }

    private func saveTokens(accountID: String, response: OAuthTokenResponse) throws {
        let stored = StoredToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
        )
        let data = try JSONEncoder().encode(stored)
        try keychain.save(data, for: "token_\(accountID)")
    }

    private func loadAccounts() {
        guard let data = UserDefaults.standard.data(forKey: "accounts"),
              let list = try? JSONDecoder().decode([DriveAccount].self, from: data) else { return }
        accounts = list
        activeAccount = list.first { $0.isActive } ?? list.first
    }

    private func saveAccountList() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: "accounts")
        }
    }

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

enum AuthError: LocalizedError {
    case codeVerifierGenerationFailed, invalidAuthURL, invalidCallback, noCodeVerifier
    case noToken, tokenDecodingFailed, tokenExpired, tokenExchangeFailed
    case tokenRefreshFailed, userInfoFailed, userCancelled, serverStartFailed

    var errorDescription: String? {
        switch self {
        case .codeVerifierGenerationFailed: return "Failed to generate authentication code"
        case .invalidAuthURL: return "Invalid authentication URL"
        case .invalidCallback: return "Invalid callback from Google"
        case .noCodeVerifier: return "Authentication state lost"
        case .noToken: return "No saved token found"
        case .tokenDecodingFailed: return "Failed to decode saved token"
        case .tokenExpired: return "Authentication expired. Please reconnect."
        case .tokenExchangeFailed: return "Failed to exchange code for token"
        case .tokenRefreshFailed: return "Failed to refresh authentication"
        case .userInfoFailed: return "Failed to fetch account info"
        case .userCancelled: return "Authentication was cancelled"
        case .serverStartFailed: return "Failed to start local server on port 18923. Is another instance running?"
        }
    }
}
