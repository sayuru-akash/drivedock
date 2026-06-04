import Foundation
import UserNotifications

enum DownloadEngineError: LocalizedError {
    case itemNotFound
    case invalidState
    case fileNotFound(String)
    case downloadFailed(String)
    case cannotCreateDirectory(String)
    case cannotWriteFile(String)
    case fileAlreadyExists(String)

    var errorDescription: String? {
        switch self {
        case .itemNotFound: return "Download item not found"
        case .invalidState: return "Download is in an invalid state"
        case .fileNotFound(let name): return "File not found on Drive: \(name)"
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        case .cannotCreateDirectory(let path): return "Cannot create directory: \(path)"
        case .cannotWriteFile(let path): return "Cannot write to: \(path)"
        case .fileAlreadyExists(let path): return "File already exists: \(path)"
        }
    }
}

@Observable
@MainActor
final class DownloadEngine {
    static let shared = DownloadEngine()

    private let driveAPI = DriveAPIService.shared
    private let auth = GoogleAuthService.shared
    private let persistence = PersistenceService.shared
    private let notifications = NotificationService.shared

    private(set) var items: [DownloadItem] = []
    private(set) var batches: [DownloadBatch] = []
    private(set) var isProcessing = false
    private(set) var totalSpeed: Double = 0
    private(set) var activeDownloadCount: Int = 0

    private var activeTasks: [String: Task<Void, Never>] = [:]
    private var speedTrackers: [String: SpeedTracker] = [:]
    private var urlSessionDelegates: [String: DownloadSessionDelegate] = [:]
    private var urlSessions: [String: URLSession] = [:]

    private init() {
        loadPersistedState()
    }

    // MARK: - Single File Download

    func addFile(
        driveFileID: String,
        fileName: String,
        fileSize: Int64,
        localDirectory: URL,
        accountID: String,
        batchID: String? = nil
    ) -> DownloadItem {
        let localPath = localDirectory.appendingPathComponent(fileName).path
        let item = DownloadItem(
            id: UUID().uuidString,
            fileName: fileName,
            driveFileID: driveFileID,
            localPath: localPath,
            fileSize: fileSize,
            downloadedBytes: 0,
            progress: 0,
            speed: 0,
            status: .waiting,
            accountID: accountID,
            createdDate: Date(),
            lastActivityDate: Date(),
            batchID: batchID,
            isFolder: false
        )
        items.append(item)
        persistence.saveDownloadQueue(items)
        return item
    }

    // MARK: - Folder Download

    func addFolder(
        driveFolderID: String,
        folderName: String,
        localDirectory: URL,
        accountID: String
    ) async -> DownloadBatch {
        let batchID = UUID().uuidString
        let batch = DownloadBatch(
            id: batchID,
            name: folderName,
            accountID: accountID,
            sourceFolderID: driveFolderID,
            sourceFolderName: folderName,
            status: .waiting,
            itemIDs: [],
            createdDate: Date(),
            totalSize: 0,
            downloadedSize: 0
        )

        do {
            let folderURL = localDirectory.appendingPathComponent(folderName)
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            let allFiles = try await listAllFilesRecursively(
                folderID: driveFolderID,
                accountID: accountID,
                relativePath: ""
            )

            var itemIDs: [String] = []
            var totalSize: Int64 = 0

            for file in allFiles {
                let subdirectory = folderURL.appendingPathComponent(file.relativePath)
                try? FileManager.default.createDirectory(at: subdirectory, withIntermediateDirectories: true)

                let localPath = subdirectory.appendingPathComponent(file.name).path
                let item = DownloadItem(
                    id: UUID().uuidString,
                    fileName: file.name,
                    driveFileID: file.id,
                    localPath: localPath,
                    fileSize: file.size,
                    downloadedBytes: 0,
                    progress: 0,
                    speed: 0,
                    status: .waiting,
                    accountID: accountID,
                    createdDate: Date(),
                    lastActivityDate: Date(),
                    batchID: batchID,
                    isFolder: true,
                    folderPath: file.relativePath.isEmpty ? nil : file.relativePath
                )
                items.append(item)
                itemIDs.append(item.id)
                totalSize += file.size
            }

            var updatedBatch = batch
            updatedBatch.itemIDs = itemIDs
            updatedBatch.totalSize = totalSize
            updatedBatch.status = .waiting
            batches.append(updatedBatch)

            persistence.saveDownloadQueue(items)
            persistence.saveDownloadBatches(batches)

            return updatedBatch
        } catch {
            var failedBatch = batch
            failedBatch.status = .failed
            batches.append(failedBatch)
            persistence.saveDownloadBatches(batches)
            return failedBatch
        }
    }

    private struct DriveFileEntry {
        let id: String
        let name: String
        let size: Int64
        let mimeType: String
        let relativePath: String
    }

    private func listAllFilesRecursively(
        folderID: String,
        accountID: String,
        relativePath: String
    ) async throws -> [DriveFileEntry] {
        var allFiles: [DriveFileEntry] = []
        var pageToken: String? = nil

        repeat {
            let result = try await driveAPI.listFiles(
                folderID: folderID,
                accountID: accountID,
                pageToken: pageToken,
                pageSize: 100
            )

            for apiFile in result.files {
                if apiFile.isFolder {
                    let subPath = relativePath.isEmpty
                        ? apiFile.name
                        : (relativePath as NSString).appendingPathComponent(apiFile.name)
                    let subFiles = try await listAllFilesRecursively(
                        folderID: apiFile.id,
                        accountID: accountID,
                        relativePath: subPath
                    )
                    allFiles.append(contentsOf: subFiles)
                } else {
                    allFiles.append(DriveFileEntry(
                        id: apiFile.id,
                        name: apiFile.name,
                        size: apiFile.parsedSize,
                        mimeType: apiFile.mimeType,
                        relativePath: relativePath
                    ))
                }
            }

            pageToken = result.nextPageToken
        } while pageToken != nil

        return allFiles
    }

    // MARK: - Queue Control

    func startProcessing() {
        guard !isProcessing else { return }
        isProcessing = true
        processQueue()
    }

    func pauseAll() {
        isProcessing = false
        for (id, task) in activeTasks {
            task.cancel()
            activeTasks.removeValue(forKey: id)
            urlSessions[id]?.invalidateAndCancel()
            urlSessions.removeValue(forKey: id)
            urlSessionDelegates.removeValue(forKey: id)
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index].status = .paused
                items[index].speed = 0
            }
        }
        activeDownloadCount = 0
        updateTotalSpeed()
        persistence.saveDownloadQueue(items)
    }

    func resumeAll() {
        for index in items.indices {
            if items[index].status == .paused {
                items[index].status = .waiting
            }
        }
        persistence.saveDownloadQueue(items)
        startProcessing()
    }

    func pauseItem(_ itemID: String) {
        activeTasks[itemID]?.cancel()
        activeTasks.removeValue(forKey: itemID)
        urlSessions[itemID]?.invalidateAndCancel()
        urlSessions.removeValue(forKey: itemID)
        urlSessionDelegates.removeValue(forKey: itemID)

        if let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index].status = .paused
            items[index].speed = 0
        }

        activeDownloadCount = max(0, activeDownloadCount - 1)
        updateTotalSpeed()
        persistence.saveDownloadQueue(items)
    }

    func resumeItem(_ itemID: String) {
        if let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index].status = .waiting
        }
        persistence.saveDownloadQueue(items)
        if !isProcessing { startProcessing() }
    }

    func cancelItem(_ itemID: String) {
        activeTasks[itemID]?.cancel()
        activeTasks.removeValue(forKey: itemID)
        urlSessions[itemID]?.invalidateAndCancel()
        urlSessions.removeValue(forKey: itemID)
        urlSessionDelegates.removeValue(forKey: itemID)

        if let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index].status = .cancelled
            items[index].speed = 0
        }

        activeDownloadCount = max(0, activeDownloadCount - 1)
        updateTotalSpeed()
        persistence.saveDownloadQueue(items)
    }

    func retryItem(_ itemID: String) {
        if let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index].status = .waiting
            items[index].progress = 0
            items[index].downloadedBytes = 0
            items[index].error = nil
        }
        persistence.saveDownloadQueue(items)
        if !isProcessing { startProcessing() }
    }

    func removeItem(_ itemID: String) {
        activeTasks[itemID]?.cancel()
        activeTasks.removeValue(forKey: itemID)
        urlSessions[itemID]?.invalidateAndCancel()
        urlSessions.removeValue(forKey: itemID)
        urlSessionDelegates.removeValue(forKey: itemID)
        items.removeAll { $0.id == itemID }
        for index in batches.indices {
            batches[index].itemIDs.removeAll { $0 == itemID }
        }
        persistence.saveDownloadQueue(items)
        persistence.saveDownloadBatches(batches)
    }

    func clearCompleted() {
        items.removeAll { $0.status == .completed || $0.status == .cancelled }
        persistence.saveDownloadQueue(items)
    }

    func clearFailed() {
        items.removeAll { $0.status == .failed }
        persistence.saveDownloadQueue(items)
    }

    // MARK: - Queue Processing

    private func processQueue() {
        Task {
            while isProcessing {
                let settings = AppSettings.shared
                let maxConcurrent = settings.defaultUploadMode.maxConcurrentUploads
                let activeCount = activeTasks.count

                guard activeCount < maxConcurrent else {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    continue
                }

                let availableSlots = maxConcurrent - activeCount
                let waitingItems = items.filter { $0.status == .waiting }.prefix(availableSlots)

                guard !waitingItems.isEmpty else {
                    let hasWaiting = items.contains { $0.status == .waiting }
                    let hasActive = !activeTasks.isEmpty

                    if !hasWaiting && !hasActive {
                        isProcessing = false
                        notifications.sendDownloadBatchCompleteNotification(
                            completedCount: items.filter { $0.status == .completed }.count,
                            failedCount: items.filter { $0.status == .failed }.count
                        )
                    } else if !hasWaiting && hasActive {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    } else {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                    continue
                }

                for item in waitingItems {
                    startDownload(item)
                }

                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func startDownload(_ item: DownloadItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].status = .downloading
        items[index].lastActivityDate = Date()
        activeDownloadCount += 1

        speedTrackers[item.id] = SpeedTracker()

        let task = Task {
            await performDownload(itemID: item.id)
        }

        activeTasks[item.id] = task
    }

    private func performDownload(itemID: String) async {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }

        let item = items[index]
        let localURL = URL(fileURLWithPath: item.localPath)
        let parentDir = localURL.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        } catch {
            await MainActor.run {
                self.items[index].status = .failed
                self.items[index].error = DownloadEngineError.cannotCreateDirectory(parentDir.path).localizedDescription
                self.activeTasks.removeValue(forKey: itemID)
                self.activeDownloadCount = max(0, self.activeDownloadCount - 1)
                self.speedTrackers.removeValue(forKey: itemID)
                self.persistence.saveDownloadQueue(self.items)
            }
            return
        }

        if FileManager.default.fileExists(atPath: item.localPath) {
            let existingSize = (try? FileManager.default.attributesOfItem(atPath: item.localPath)[FileAttributeKey.size] as? Int64) ?? 0
            if existingSize == item.fileSize && item.fileSize > 0 {
                await MainActor.run {
                    self.items[index].status = .completed
                    self.items[index].progress = 1.0
                    self.items[index].downloadedBytes = item.fileSize
                    self.items[index].completedDate = Date()
                    self.items[index].speed = 0
                    self.activeTasks.removeValue(forKey: itemID)
                    self.activeDownloadCount = max(0, self.activeDownloadCount - 1)
                    self.speedTrackers.removeValue(forKey: itemID)
                    self.updateTotalSpeed()
                    self.persistence.saveDownloadQueue(self.items)
                }
                return
            }
        }

        do {
            let downloadURL = try await driveAPI.getDownloadURL(
                fileID: item.driveFileID,
                accountID: item.accountID
            )

            let downloadedPath = try await performHTTPDownload(
                itemID: itemID,
                from: downloadURL,
                to: localURL,
                expectedSize: item.fileSize,
                accountID: item.accountID
            )

            let finalAttributes = try FileManager.default.attributesOfItem(atPath: downloadedPath)
            let finalSize = finalAttributes[FileAttributeKey.size] as? Int64 ?? 0

            await MainActor.run {
                self.items[index].status = .completed
                self.items[index].progress = 1.0
                self.items[index].downloadedBytes = finalSize
                self.items[index].fileSize = finalSize
                self.items[index].completedDate = Date()
                self.items[index].speed = 0
                self.activeTasks.removeValue(forKey: itemID)
                self.activeDownloadCount = max(0, self.activeDownloadCount - 1)
                self.speedTrackers.removeValue(forKey: itemID)
                self.updateTotalSpeed()
                self.persistence.saveDownloadQueue(self.items)
                self.persistence.saveDownloadBatches(self.batches)
            }
        } catch is CancellationError {
            await MainActor.run {
                self.items[index].status = .paused
                self.items[index].speed = 0
                self.activeTasks.removeValue(forKey: itemID)
                self.activeDownloadCount = max(0, self.activeDownloadCount - 1)
                self.speedTrackers.removeValue(forKey: itemID)
                self.updateTotalSpeed()
                self.persistence.saveDownloadQueue(self.items)
            }
        } catch {
            await MainActor.run {
                self.items[index].status = .failed
                self.items[index].error = error.localizedDescription
                self.items[index].speed = 0
                self.activeTasks.removeValue(forKey: itemID)
                self.activeDownloadCount = max(0, self.activeDownloadCount - 1)
                self.speedTrackers.removeValue(forKey: itemID)
                self.updateTotalSpeed()
                self.persistence.saveDownloadQueue(self.items)
                self.notifications.sendDownloadFailedNotification(
                    fileName: self.items[index].fileName,
                    reason: error.localizedDescription
                )
            }
        }
    }

    private func performHTTPDownload(
        itemID: String,
        from url: URL,
        to localURL: URL,
        expectedSize: Int64,
        accountID: String
    ) async throws -> String {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            throw DownloadEngineError.itemNotFound
        }

        let accessToken = try await auth.getAccessToken(for: accountID)

        var resumeOffset: Int64 = 0
        let tempURL = localURL.appendingPathExtension("download")
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: tempURL.path) {
            let attrs = try? fileManager.attributesOfItem(atPath: tempURL.path)
            resumeOffset = attrs?[FileAttributeKey.size] as? Int64 ?? 0
            if resumeOffset > 0 {
                await MainActor.run {
                    self.items[index].downloadedBytes = resumeOffset
                    if expectedSize > 0 {
                        self.items[index].progress = Double(resumeOffset) / Double(expectedSize)
                    }
                }
            }
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if resumeOffset > 0 {
            request.setValue("bytes=\(resumeOffset)-", forHTTPHeaderField: "Range")
        }

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadEngineError.downloadFailed("Invalid response")
        }

        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 400 else {
            throw DriveAPIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }

        let handle: FileHandle
        if resumeOffset > 0 && (httpResponse.statusCode == 206 || httpResponse.statusCode == 200) {
            handle = try FileHandle(forWritingTo: tempURL)
            handle.seekToEndOfFile()
        } else {
            resumeOffset = 0
            fileManager.createFile(atPath: tempURL.path, contents: nil)
            handle = try FileHandle(forWritingTo: tempURL)
        }
        defer { try? handle.close() }

        var bytesWritten: Int64 = resumeOffset
        var chunkBuffer = Data()
        let flushThreshold = 64 * 1024

        for try await byte in asyncBytes {
            if Task.isCancelled {
                try? handle.close()
                throw CancellationError()
            }

            chunkBuffer.append(byte)

            if chunkBuffer.count >= flushThreshold {
                handle.write(chunkBuffer)
                bytesWritten += Int64(chunkBuffer.count)
                chunkBuffer.removeAll(keepingCapacity: true)

                let speed = speedTrackers[itemID]?.addBytes(Int64(flushThreshold)) ?? 0
                let remaining = expectedSize > 0 ? expectedSize - bytesWritten : 0
                let eta = speed > 0 && remaining > 0 ? Double(remaining) / speed : nil
                let currentBytes = bytesWritten
                let progress = expectedSize > 0 ? Double(currentBytes) / Double(expectedSize) : 0

                await MainActor.run {
                    self.items[index].downloadedBytes = currentBytes
                    self.items[index].progress = min(progress, 1.0)
                    self.items[index].speed = speed
                    self.items[index].eta = eta
                    self.items[index].lastActivityDate = Date()
                    self.updateTotalSpeed()
                }
            }
        }

        if !chunkBuffer.isEmpty {
            handle.write(chunkBuffer)
            bytesWritten += Int64(chunkBuffer.count)
        }

        try? handle.close()

        if fileManager.fileExists(atPath: localURL.path) {
            try fileManager.removeItem(at: localURL)
        }
        try fileManager.moveItem(at: tempURL, to: localURL)

        return localURL.path
    }

    // MARK: - Speed & Stats

    private func updateTotalSpeed() {
        totalSpeed = items.filter { $0.status == .downloading }.reduce(0) { $0 + $1.speed }
    }

    var overallProgress: Double {
        let totalSize = items.reduce(Int64(0)) { $0 + $1.fileSize }
        let downloadedSize = items.reduce(Int64(0)) { $0 + $1.downloadedBytes }
        guard totalSize > 0 else { return 0 }
        return Double(downloadedSize) / Double(totalSize)
    }

    var waitingCount: Int { items.filter { $0.status == .waiting }.count }
    var completedCount: Int { items.filter { $0.status == .completed }.count }
    var failedCount: Int { items.filter { $0.status == .failed }.count }
    var pausedCount: Int { items.filter { $0.status == .paused }.count }

    // MARK: - Persistence

    private func loadPersistedState() {
        items = persistence.loadDownloadQueue()
        batches = persistence.loadDownloadBatches()
    }

    func saveState() {
        persistence.saveDownloadQueue(items)
        persistence.saveDownloadBatches(batches)
    }
}

// MARK: - URLSession Delegate for Download Progress

private final class DownloadSessionDelegate: NSObject, URLSessionDownloadDelegate {
    let itemID: String
    let progressHandler: (Int64, Double) -> Void
    let completionHandler: (Result<String, Error>) -> Void
    private var resumeData: Data?

    init(
        itemID: String,
        progressHandler: @escaping (Int64, Double) -> Void,
        completionHandler: @escaping (Result<String, Error>) -> Void
    ) {
        self.itemID = itemID
        self.progressHandler = progressHandler
        self.completionHandler = completionHandler
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let destination = downloadTask.originalRequest?.url?.path ?? location.path
        let destinationURL = URL(fileURLWithPath: destination + ".download")

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
            completionHandler(.success(destinationURL.path))
        } catch {
            completionHandler(.failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        progressHandler(totalBytesWritten, progress)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            if (error as NSError).code == NSURLErrorCancelled {
                resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            }
            completionHandler(.failure(error))
        }
    }
}

// MARK: - NotificationService extension for downloads

extension NotificationService {
    func sendDownloadBatchCompleteNotification(completedCount: Int, failedCount: Int) {
        let settings = AppSettings.shared
        guard settings.notificationPreference != .disabled else { return }
        guard permissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default

        if failedCount == 0 {
            content.title = "Download Complete"
            content.body = completedCount == 1
                ? "Your file has been downloaded successfully."
                : "All \(completedCount) files have been downloaded successfully."
        } else if completedCount > 0 {
            content.title = "Download Partially Complete"
            content.body = "\(completedCount) files downloaded. \(failedCount) files need attention."
        } else {
            content.title = "Download Failed"
            content.body = "\(failedCount) files failed to download."
        }

        let request = UNNotificationRequest(
            identifier: "download-batch-complete-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.handleNotificationError(error)
            }
        }
    }

    func sendDownloadFailedNotification(fileName: String, reason: String) {
        let settings = AppSettings.shared
        guard settings.notifyOnErrors else { return }
        guard permissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Download Failed"
        content.body = "\(fileName): \(reason)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "download-failed-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.handleNotificationError(error)
            }
        }
    }
}

// MARK: - PersistenceService extension for downloads

extension PersistenceService {
    func saveDownloadQueue(_ items: [DownloadItem]) {
        fileLock.lock()
        defer { fileLock.unlock() }

        guard let data = try? JSONEncoder().encode(items) else { return }
        let url = appSupportURL.appendingPathComponent("download_queue.json")

        guard hasSufficientDiskSpace(for: data.count) else { return }
        createBackup(for: url)
        try? data.write(to: url)
    }

    func loadDownloadQueue() -> [DownloadItem] {
        fileLock.lock()
        defer { fileLock.unlock() }

        let url = appSupportURL.appendingPathComponent("download_queue.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([DownloadItem].self, from: data)) ?? []
    }

    func saveDownloadBatches(_ batches: [DownloadBatch]) {
        fileLock.lock()
        defer { fileLock.unlock() }

        guard let data = try? JSONEncoder().encode(batches) else { return }
        let url = appSupportURL.appendingPathComponent("download_batches.json")

        guard hasSufficientDiskSpace(for: data.count) else { return }
        createBackup(for: url)
        try? data.write(to: url)
    }

    func loadDownloadBatches() -> [DownloadBatch] {
        fileLock.lock()
        defer { fileLock.unlock() }

        let url = appSupportURL.appendingPathComponent("download_batches.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([DownloadBatch].self, from: data)) ?? []
    }
}
