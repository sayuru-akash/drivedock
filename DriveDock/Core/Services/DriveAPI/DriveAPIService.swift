import Foundation

enum DriveAPIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case quotaExceeded
    case rateLimited(retryAfter: TimeInterval?)
    case permissionDenied
    case notFound
    case authenticationRequired
    case networkUnavailable
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from Google Drive"
        case .httpError(let code, let msg): return "Google Drive error (\(code)): \(msg ?? "Unknown")"
        case .quotaExceeded: return "Google Drive storage quota exceeded"
        case .rateLimited: return "Too many requests. Please wait."
        case .permissionDenied: return "Permission denied"
        case .notFound: return "File or folder not found"
        case .authenticationRequired: return "Authentication required"
        case .networkUnavailable: return "Network unavailable"
        case .timeout: return "Request timed out"
        }
    }
}

struct DriveAPIListResponse: Codable {
    let files: [DriveAPIFile]
    let nextPageToken: String?
    let incompleteSearch: Bool?

    struct DriveAPIFile: Codable {
        let id: String
        let name: String
        let mimeType: String
        let size: String?
        let parents: [String]?
        let webViewLink: String?
        let createdTime: String?
        let modifiedTime: String?
        let ownedByMe: Bool?
        let capabilities: Capabilities?

        struct Capabilities: Codable {
            let canEdit: Bool?
            let canAddChildren: Bool?
        }

        var parsedSize: Int64 {
            Int64(size ?? "0") ?? 0
        }

        var isFolder: Bool {
            mimeType == "application/vnd.google-apps.folder"
        }
    }
}

struct DriveAPICreateFolderRequest: Codable {
    let name: String
    let mimeType: String
    let parents: [String]?

    init(name: String, parentID: String?) {
        self.name = name
        self.mimeType = "application/vnd.google-apps.folder"
        self.parents = parentID.map { [$0] }
    }
}

struct ResumableUploadSession: Codable {
    let uploadURL: String
    let fileID: String?
    let createdDate: Date
}

@Observable
final class DriveAPIService {
    static let shared = DriveAPIService()

    private let auth = GoogleAuthService.shared
    private let baseURL = "https://www.googleapis.com/drive/v3"
    private let uploadBaseURL = "https://www.googleapis.com/upload/drive/v3"

    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    var requestTimeout: TimeInterval = 30
    var resourceTimeout: TimeInterval = 600
    private let maxRetries = 3

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)

        jsonDecoder = JSONDecoder()
        jsonEncoder = JSONEncoder()
    }

    func updateTimeouts(request: TimeInterval, resource: TimeInterval) {
        requestTimeout = request
        resourceTimeout = resource
    }

    private func executeWithRetry<T>(_ operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxRetries {
            if Task.isCancelled { throw lastError ?? DriveAPIError.networkUnavailable }
            do {
                return try await operation()
            } catch let error as DriveAPIError {
                switch error {
                case .httpError(let code, _) where code >= 500:
                    lastError = error
                    if attempt < maxRetries - 1 {
                        let delay = UInt64(pow(2.0, Double(attempt))) * 500_000_000
                        try? await Task.sleep(nanoseconds: delay)
                        continue
                    }
                case .rateLimited(let retryAfter):
                    lastError = error
                    if attempt < maxRetries - 1 {
                        let delay = UInt64((retryAfter ?? Double(attempt + 1)) * 1_000_000_000)
                        try? await Task.sleep(nanoseconds: delay)
                        continue
                    }
                case .networkUnavailable:
                    lastError = error
                    if attempt < maxRetries - 1 {
                        let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                        try? await Task.sleep(nanoseconds: delay)
                        continue
                    }
                default:
                    throw error
                }
            } catch is CancellationError {
                throw lastError ?? DriveAPIError.networkUnavailable
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                    lastError = DriveAPIError.timeout
                    if attempt < maxRetries - 1 {
                        let delay = UInt64(pow(2.0, Double(attempt))) * 500_000_000
                        try? await Task.sleep(nanoseconds: delay)
                        continue
                    }
                }
                if nsError.domain == NSURLErrorDomain && attempt < maxRetries - 1 {
                    lastError = error
                    let delay = UInt64(pow(2.0, Double(attempt))) * 500_000_000
                    try? await Task.sleep(nanoseconds: delay)
                    continue
                }
                throw error
            }
        }
        throw lastError ?? DriveAPIError.networkUnavailable
    }

    // MARK: - Folder Operations

    func listFolder(
        folderID: String = "root",
        accountID: String,
        pageToken: String? = nil,
        pageSize: Int = 100
    ) async throws -> (folders: [DriveFolder], nextPageToken: String?) {
        return try await executeWithRetry {
            let accessToken = try await self.auth.getAccessToken(for: accountID)

            var components = URLComponents(string: "\(self.baseURL)/files")!
            var queryItems = [
                URLQueryItem(name: "q", value: "'\(folderID)' in parents and trashed = false"),
                URLQueryItem(name: "fields", value: "files(id,name,mimeType,parents,webViewLink,modifiedTime,capabilities),nextPageToken,incompleteSearch"),
                URLQueryItem(name: "pageSize", value: "\(pageSize)"),
                URLQueryItem(name: "supportsAllDrives", value: "true"),
                URLQueryItem(name: "includeItemsFromAllDrives", value: "true")
            ]
            if let pageToken {
                queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            components.queryItems = queryItems

            guard let url = components.url else { throw DriveAPIError.invalidResponse }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = self.requestTimeout

            let (data, response) = try await self.session.data(for: request)
            try self.validateResponse(response, data: data)

            let listResponse = try self.jsonDecoder.decode(DriveAPIListResponse.self, from: data)

            let folders = listResponse.files
                .filter { $0.isFolder }
                .map { apiFile in
                    DriveFolder(
                        id: apiFile.id,
                        name: apiFile.name,
                        parentID: apiFile.parents?.first,
                        isSharedDrive: false,
                        sharedDriveID: nil,
                        ownerEmail: nil,
                        modifiedDate: nil,
                        childCount: nil
                    )
                }

            return (folders, listResponse.nextPageToken)
        }
    }

    func listAllFolderPages(
        folderID: String = "root",
        accountID: String,
        pageSize: Int = 100
    ) async throws -> [DriveFolder] {
        var allFolders: [DriveFolder] = []
        var pageToken: String? = nil

        repeat {
            let result = try await listFolder(
                folderID: folderID,
                accountID: accountID,
                pageToken: pageToken,
                pageSize: pageSize
            )
            allFolders.append(contentsOf: result.folders)
            pageToken = result.nextPageToken
        } while pageToken != nil

        return allFolders
    }

    func searchFolders(
        query: String,
        accountID: String,
        pageToken: String? = nil
    ) async throws -> (folders: [DriveFolder], nextPageToken: String?) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ([], nil)
        }

        return try await executeWithRetry {
            let accessToken = try await self.auth.getAccessToken(for: accountID)

            let sanitizedQuery = query.replacingOccurrences(of: "'", with: "\\'")
            let searchQuery = "mimeType = 'application/vnd.google-apps.folder' and name contains '\(sanitizedQuery)' and trashed = false"

            var components = URLComponents(string: "\(self.baseURL)/files")!
            var queryItems = [
                URLQueryItem(name: "q", value: searchQuery),
                URLQueryItem(name: "fields", value: "files(id,name,mimeType,parents,webViewLink,modifiedTime),nextPageToken"),
                URLQueryItem(name: "pageSize", value: "50"),
                URLQueryItem(name: "supportsAllDrives", value: "true"),
                URLQueryItem(name: "includeItemsFromAllDrives", value: "true")
            ]
            if let pageToken {
                queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            components.queryItems = queryItems

            guard let url = components.url else { throw DriveAPIError.invalidResponse }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = self.requestTimeout

            let (data, response) = try await self.session.data(for: request)
            try self.validateResponse(response, data: data)

            let listResponse = try self.jsonDecoder.decode(DriveAPIListResponse.self, from: data)

            let folders = listResponse.files.map { apiFile in
                DriveFolder(
                    id: apiFile.id,
                    name: apiFile.name,
                    parentID: apiFile.parents?.first,
                    isSharedDrive: false,
                    sharedDriveID: nil,
                    ownerEmail: nil,
                    modifiedDate: nil,
                    childCount: nil
                )
            }

            return (folders, listResponse.nextPageToken)
        }
    }

    func createFolder(
        name: String,
        parentID: String,
        accountID: String
    ) async throws -> DriveFolder {
        return try await executeWithRetry {
            let accessToken = try await self.auth.getAccessToken(for: accountID)

            guard let url = URL(string: "\(self.baseURL)/files?supportsAllDrives=true") else {
                throw DriveAPIError.invalidResponse
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = self.requestTimeout

            let body = DriveAPICreateFolderRequest(name: name, parentID: parentID)
            request.httpBody = try self.jsonEncoder.encode(body)

            let (data, response) = try await self.session.data(for: request)
            try self.validateResponse(response, data: data)

            let file = try self.jsonDecoder.decode(DriveAPIListResponse.DriveAPIFile.self, from: data)
            return DriveFolder(
                id: file.id,
                name: file.name,
                parentID: file.parents?.first,
                isSharedDrive: false,
                sharedDriveID: nil,
                ownerEmail: nil,
                modifiedDate: nil,
                childCount: nil
            )
        }
    }

    // MARK: - Shared Drives

    func listSharedDrives(accountID: String) async throws -> [SharedDrive] {
        return try await executeWithRetry {
            let accessToken = try await self.auth.getAccessToken(for: accountID)

            var allDrives: [SharedDrive] = []
            var pageToken: String? = nil

            repeat {
                var components = URLComponents(string: "\(self.baseURL)/drives")!
                var queryItems = [
                    URLQueryItem(name: "fields", value: "drives(id,name,createdTime),nextPageToken"),
                    URLQueryItem(name: "pageSize", value: "100")
                ]
                if let pageToken {
                    queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
                }
                components.queryItems = queryItems

                guard let url = components.url else { throw DriveAPIError.invalidResponse }

                var request = URLRequest(url: url)
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                request.timeoutInterval = self.requestTimeout

                let (data, response) = try await self.session.data(for: request)
                try self.validateResponse(response, data: data)

                struct DrivesResponse: Codable {
                    let drives: [DriveItem]
                    let nextPageToken: String?
                    struct DriveItem: Codable {
                        let id: String
                        let name: String
                        let createdTime: String?
                    }
                }

                let drivesResponse = try self.jsonDecoder.decode(DrivesResponse.self, from: data)
                allDrives.append(contentsOf: drivesResponse.drives.map { drive in
                    SharedDrive(
                        id: drive.id,
                        name: drive.name,
                        createdDate: nil
                    )
                })
                pageToken = drivesResponse.nextPageToken
            } while pageToken != nil

            return allDrives
        }
    }

    func listSharedDriveFolder(
        driveID: String,
        folderID: String? = nil,
        accountID: String
    ) async throws -> [DriveFolder] {
        return try await executeWithRetry {
            let parentID = folderID ?? driveID
            let accessToken = try await self.auth.getAccessToken(for: accountID)

            var components = URLComponents(string: "\(self.baseURL)/files")!
            components.queryItems = [
                URLQueryItem(name: "q", value: "'\(parentID)' in parents and trashed = false"),
                URLQueryItem(name: "fields", value: "files(id,name,mimeType,parents,webViewLink,modifiedTime,capabilities),nextPageToken"),
                URLQueryItem(name: "pageSize", value: "100"),
                URLQueryItem(name: "supportsAllDrives", value: "true"),
                URLQueryItem(name: "includeItemsFromAllDrives", value: "true"),
                URLQueryItem(name: "driveId", value: driveID),
                URLQueryItem(name: "corpora", value: "drive")
            ]

            guard let url = components.url else { throw DriveAPIError.invalidResponse }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = self.requestTimeout

            let (data, response) = try await self.session.data(for: request)
            try self.validateResponse(response, data: data)

            let listResponse = try self.jsonDecoder.decode(DriveAPIListResponse.self, from: data)

            return listResponse.files
                .filter { $0.isFolder }
                .map { apiFile in
                    DriveFolder(
                        id: apiFile.id,
                        name: apiFile.name,
                        parentID: apiFile.parents?.first,
                        isSharedDrive: true,
                        sharedDriveID: driveID,
                        ownerEmail: nil,
                        modifiedDate: nil,
                        childCount: nil
                    )
                }
        }
    }

    // MARK: - File Upload

    func initiateResumableUpload(
        fileName: String,
        fileSize: Int64,
        mimeType: String,
        parentFolderID: String,
        accountID: String
    ) async throws -> ResumableUploadSession {
        return try await executeWithRetry {
            let accessToken = try await self.auth.getAccessToken(for: accountID)

            guard let url = URL(string: "\(self.uploadBaseURL)/files?uploadType=resumable&supportsAllDrives=true") else {
                throw DriveAPIError.invalidResponse
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            request.setValue("\(fileSize)", forHTTPHeaderField: "X-Upload-Content-Length")
            request.setValue(mimeType, forHTTPHeaderField: "X-Upload-Content-Type")
            request.timeoutInterval = self.requestTimeout

            let metadata: [String: Any] = [
                "name": fileName,
                "parents": [parentFolderID]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: metadata)

            let (_, response) = try await self.session.data(for: request)
            try self.validateResponse(response)

            guard let httpResponse = response as? HTTPURLResponse,
                  let uploadURL = httpResponse.value(forHTTPHeaderField: "Location") else {
                throw DriveAPIError.invalidResponse
            }

            return ResumableUploadSession(
                uploadURL: uploadURL,
                fileID: nil,
                createdDate: Date()
            )
        }
    }

    func uploadChunk(
        sessionURL: String,
        data: Data,
        rangeStart: Int64,
        totalSize: Int64
    ) async throws -> (statusCode: Int, uploadedBytes: Int64) {
        guard let url = URL(string: sessionURL) else {
            throw DriveAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("bytes \(rangeStart)-\(rangeStart + Int64(data.count) - 1)/\(totalSize)", forHTTPHeaderField: "Content-Range")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DriveAPIError.invalidResponse
        }

        if httpResponse.statusCode == 308 {
            return (308, rangeStart + Int64(data.count))
        } else if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            return (httpResponse.statusCode, totalSize)
        } else {
            throw DriveAPIError.httpError(statusCode: httpResponse.statusCode, message: String(data: responseData, encoding: .utf8))
        }
    }

    func cancelResumableUpload(sessionURL: String) async throws {
        guard let url = URL(string: sessionURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("0", forHTTPHeaderField: "Content-Length")
        _ = try? await session.data(for: request)
    }

    func simpleUpload(
        fileData: Data,
        fileName: String,
        mimeType: String,
        parentFolderID: String,
        accountID: String
    ) async throws -> DriveFile {
        return try await executeWithRetry {
            let accessToken = try await self.auth.getAccessToken(for: accountID)

            guard let url = URL(string: "\(self.uploadBaseURL)/files?uploadType=multipart&supportsAllDrives=true") else {
                throw DriveAPIError.invalidResponse
            }

            let boundary = UUID().uuidString
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = self.requestTimeout

            let metadata: [String: Any] = [
                "name": fileName,
                "parents": [parentFolderID]
            ]
            let metadataData = try JSONSerialization.data(withJSONObject: metadata)

            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
            body.append(metadataData)
            body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

            let (data, response) = try await self.session.data(for: request)
            try self.validateResponse(response, data: data)

            let file = try self.jsonDecoder.decode(DriveAPIListResponse.DriveAPIFile.self, from: data)
            return DriveFile(
                id: file.id,
                name: file.name,
                mimeType: file.mimeType,
                size: file.parsedSize,
                parentID: file.parents?.first,
                webViewLink: file.webViewLink,
                createdDate: nil,
                modifiedDate: nil
            )
        }
    }

    // MARK: - File Info

    func checkDuplicate(
        fileName: String,
        parentFolderID: String,
        accountID: String
    ) async throws -> [DriveFile] {
        return try await executeWithRetry {
            let accessToken = try await self.auth.getAccessToken(for: accountID)

            let query = "name = '\(fileName.replacingOccurrences(of: "'", with: "\\'"))' and '\(parentFolderID)' in parents and trashed = false"

            var components = URLComponents(string: "\(self.baseURL)/files")!
            components.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "fields", value: "files(id,name,mimeType,size,parents,webViewLink,createdTime,modifiedTime)"),
                URLQueryItem(name: "supportsAllDrives", value: "true"),
                URLQueryItem(name: "includeItemsFromAllDrives", value: "true")
            ]

            guard let url = components.url else { throw DriveAPIError.invalidResponse }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = self.requestTimeout

            let (data, response) = try await self.session.data(for: request)
            try self.validateResponse(response, data: data)

            let listResponse = try self.jsonDecoder.decode(DriveAPIListResponse.self, from: data)
            return listResponse.files.map { file in
                DriveFile(
                    id: file.id,
                    name: file.name,
                    mimeType: file.mimeType,
                    size: file.parsedSize,
                    parentID: file.parents?.first,
                    webViewLink: file.webViewLink,
                    createdDate: nil,
                    modifiedDate: nil
                )
            }
        }
    }

    func getFileLink(fileID: String, accountID: String) async throws -> String? {
        return try await executeWithRetry {
            let accessToken = try await self.auth.getAccessToken(for: accountID)

            var components = URLComponents(string: "\(self.baseURL)/files/\(fileID)")!
            components.queryItems = [
                URLQueryItem(name: "fields", value: "webViewLink"),
                URLQueryItem(name: "supportsAllDrives", value: "true")
            ]

            guard let url = components.url else { throw DriveAPIError.invalidResponse }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = self.requestTimeout

            let (data, response) = try await self.session.data(for: request)
            try self.validateResponse(response, data: data)

            struct FileLink: Codable { let webViewLink: String? }
            let file = try self.jsonDecoder.decode(FileLink.self, from: data)
            return file.webViewLink
        }
    }

    // MARK: - Download

    func getDownloadURL(fileID: String, accountID: String) async throws -> URL {
        let accessToken = try await auth.getAccessToken(for: accountID)

        // First, check if the file exists and get its metadata
        var metaComponents = URLComponents(string: "\(baseURL)/files/\(fileID)")!
        metaComponents.queryItems = [
            URLQueryItem(name: "fields", value: "id,name,mimeType,size"),
            URLQueryItem(name: "supportsAllDrives", value: "true")
        ]

        guard let metaURL = metaComponents.url else { throw DriveAPIError.invalidResponse }

        var metaRequest = URLRequest(url: metaURL)
        metaRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        metaRequest.timeoutInterval = requestTimeout

        let (metaData, metaResponse) = try await session.data(for: metaRequest)
        try validateResponse(metaResponse)

        // Build the download URL directly
        var components = URLComponents(string: "\(baseURL)/files/\(fileID)")!
        components.queryItems = [
            URLQueryItem(name: "alt", value: "media"),
            URLQueryItem(name: "supportsAllDrives", value: "true")
        ]

        guard let url = components.url else { throw DriveAPIError.invalidResponse }

        return url
    }

    func getFileMetadata(fileID: String, accountID: String) async throws -> DriveAPIListResponse.DriveAPIFile {
        return try await executeWithRetry {
            let accessToken = try await self.auth.getAccessToken(for: accountID)

            var components = URLComponents(string: "\(self.baseURL)/files/\(fileID)")!
            components.queryItems = [
                URLQueryItem(name: "fields", value: "id,name,mimeType,size,parents,webViewLink,createdTime,modifiedTime"),
                URLQueryItem(name: "supportsAllDrives", value: "true")
            ]

            guard let url = components.url else { throw DriveAPIError.invalidResponse }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = self.requestTimeout

            let (data, response) = try await self.session.data(for: request)
            try self.validateResponse(response, data: data)

            return try self.jsonDecoder.decode(DriveAPIListResponse.DriveAPIFile.self, from: data)
        }
    }

    func listFiles(
        folderID: String,
        accountID: String,
        pageToken: String? = nil,
        pageSize: Int = 100
    ) async throws -> (files: [DriveAPIListResponse.DriveAPIFile], nextPageToken: String?) {
        return try await executeWithRetry {
            let accessToken = try await self.auth.getAccessToken(for: accountID)

            var components = URLComponents(string: "\(self.baseURL)/files")!
            var queryItems = [
                URLQueryItem(name: "q", value: "'\(folderID)' in parents and trashed = false"),
                URLQueryItem(name: "fields", value: "files(id,name,mimeType,size,parents,webViewLink,createdTime,modifiedTime),nextPageToken,incompleteSearch"),
                URLQueryItem(name: "pageSize", value: "\(pageSize)"),
                URLQueryItem(name: "supportsAllDrives", value: "true"),
                URLQueryItem(name: "includeItemsFromAllDrives", value: "true")
            ]
            if let pageToken {
                queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            components.queryItems = queryItems

            guard let url = components.url else { throw DriveAPIError.invalidResponse }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = self.requestTimeout

            let (data, response) = try await self.session.data(for: request)
            try self.validateResponse(response, data: data)

            let listResponse = try self.jsonDecoder.decode(DriveAPIListResponse.self, from: data)
            return (listResponse.files, listResponse.nextPageToken)
        }
    }

    // MARK: - Validation

    private func validateResponse(_ response: URLResponse, data: Data?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DriveAPIError.invalidResponse
        }

        var errorMessage: String? = nil
        if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any] {
            errorMessage = error["message"] as? String
            if let errors = error["errors"] as? [[String: Any]], let first = errors.first {
                errorMessage = first["message"] as? String ?? errorMessage
            }
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw DriveAPIError.authenticationRequired
        case 403:
            if errorMessage?.contains("quota") == true || errorMessage?.contains("storage") == true {
                throw DriveAPIError.quotaExceeded
            }
            throw DriveAPIError.permissionDenied
        case 404:
            throw DriveAPIError.notFound
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
            throw DriveAPIError.rateLimited(retryAfter: retryAfter)
        case 500...599:
            throw DriveAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage ?? "Server error")
        default:
            throw DriveAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        try validateResponse(response, data: nil)
    }
}
