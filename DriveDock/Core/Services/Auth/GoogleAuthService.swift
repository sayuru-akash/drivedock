import Foundation
import CryptoKit

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
        case id
        case email
        case name
        case picture
    }
}

@Observable
final class GoogleAuthService {
    static let shared = GoogleAuthService()

    private let keychain = KeychainService.shared
    private let clientID: String
    private let redirectURI = "com.googleusercontent.apps.drivedock:/oauth2callback"
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

    private init() {
        self.clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String ?? ""
        loadAccounts()
    }

    // MARK: - OAuth Flow

    func startAuthentication() async throws -> URL {
        isAuthenticating = true
        authError = nil

        codeVerifier = generateCodeVerifier()
        guard let verifier = codeVerifier else {
            throw AuthError.codeVerifierGenerationFailed
        }

        let codeChallenge = generateCodeChallenge(from: verifier)
        let state = UUID().uuidString

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let url = components.url else {
            throw AuthError.invalidAuthURL
        }

        return url
    }

    func handleCallback(url: URL) async throws -> DriveAccount {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.invalidCallback
        }

        guard let verifier = codeVerifier else {
            throw AuthError.noCodeVerifier
        }

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

        if accounts.isEmpty {
            activeAccount = account
        }
        accounts.append(account)
        saveAccountList()

        isAuthenticating = false
        return account
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

        if let expiresAt = token.expiresAt, Date() < expiresAt.addingTimeInterval(-60) {
            return token.accessToken
        }

        guard let refreshToken = token.refreshToken else {
            throw AuthError.tokenExpired
        }

        let newToken = try await refreshAccessToken(refreshToken: refreshToken, accountID: accountID)
        return newToken
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

    // MARK: - Private Helpers

    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> OAuthTokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.tokenExchangeFailed
        }

        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }

    private func refreshAccessToken(refreshToken: String, accountID: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "refresh_token": refreshToken,
            "client_id": clientID,
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
              let list = try? JSONDecoder().decode([DriveAccount].self, from: data) else {
            return
        }
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
            .trimmingCharacters(in: .whitespaces)
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

struct StoredToken: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
}

enum AuthError: LocalizedError {
    case codeVerifierGenerationFailed
    case invalidAuthURL
    case invalidCallback
    case noCodeVerifier
    case noToken
    case tokenDecodingFailed
    case tokenExpired
    case tokenExchangeFailed
    case tokenRefreshFailed
    case userInfoFailed

    var errorDescription: String? {
        switch self {
        case .codeVerifierGenerationFailed: return "Failed to generate authentication code"
        case .invalidAuthURL: return "Invalid authentication URL"
        case .invalidCallback: return "Invalid authentication callback"
        case .noCodeVerifier: return "Authentication state lost"
        case .noToken: return "No saved token found"
        case .tokenDecodingFailed: return "Failed to decode saved token"
        case .tokenExpired: return "Authentication expired. Please reconnect."
        case .tokenExchangeFailed: return "Failed to complete authentication"
        case .tokenRefreshFailed: return "Failed to refresh authentication"
        case .userInfoFailed: return "Failed to fetch account information"
        }
    }
}
