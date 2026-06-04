import Foundation
import AppKit
import UserNotifications

enum DownloadEngineError: LocalizedError {
    case itemNotFound
    case invalidState
    case fileNotFound(String)
    case downloadFailed(String)
    case cannotCreateDirectory(String)
    case cannotWriteFile(String)
    case fileAlreadyExists(String)
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .itemNotFound: return "Download item not found"
        case .invalidState: return "Download is in an invalid state"
        case .fileNotFound(let name): return "File not found on Drive: \(name)"
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        case .cannotCreateDirectory(let path): return "Cannot create directory: \(path)"
        case .cannotWriteFile(let path): return "Cannot write to: \(path)"
        case .fileAlreadyExists(let path): return "File already exists: \(path)"
        case .permissionDenied(let msg): return "Permission denied: \(msg)"
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

    private init() {
        loadPersistedState()
    }

    // MARK: - Download with Save Panel

    func downloadFileWithSavePanel(
        driveFileID: String,
        fileName: String,
        fileSize: Int64,
        accountID: String
    ) {
        // Get or request download folder permission
        guard let downloadFolder = DownloadFolderManager.shared.requestDownloadFolder() else {
            return
        }
        
        let saveURL = downloadFolder.appendingPathComponent(fileName)
        
        let item = DownloadItem(
            id: UUID().uuidString,
            fileName: fileName,
            driveFileID: driveFileID,
            localPath: saveURL.path,
            fileSize: fileSize,
            downloadedBytes: 0,
            progress: 0,
            speed: 0,
            status: .waiting,
            accountID: accountID,
            createdDate: Date(),
            lastActivityDate: Date(),
            batchID: nil,
            isFolder: false
        )
        items.append(item)
        persistence.saveDownloadQueue(items)
        startProcessing()
    }

    func downloadFolderWithPicker(
        driveFolderID: String,
        folderName: String,
        accountID: String
    ) {
        // Get or request download folder permission
        guard let downloadFolder = DownloadFolderManager.shared.requestDownloadFolder() else {
            return
        }
        
        Task {
            await addFolder(
                driveFolderID: driveFolderID,
                folderName: folderName,
                localDirectory: downloadFolder,
                accountID: accountID
            )
            startProcessing()
        }
    }

    // MARK: - Single File Download (internal)

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
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)

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
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index].status = .paused
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
        items.removeAll { $0.id == itemID }
        persistence.saveDownloadQueue(items)
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
                let maxConcurrent = 3
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

        // Ensure parent directory exists
        do {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            await MainActor.run {
                self.items[index].status = .failed
                self.items[index].error = "Cannot create folder: \(error.localizedDescription)"
                self.activeTasks.removeValue(forKey: itemID)
                self.activeDownloadCount = max(0, self.activeDownloadCount - 1)
                self.speedTrackers.removeValue(forKey: itemID)
                self.persistence.saveDownloadQueue(self.items)
            }
            return
        }

        // Check if file already exists with same size
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
        let fileManager = FileManager.default
        
        // Use temp directory for downloading
        let tempDir = fileManager.temporaryDirectory
        let tempFileName = UUID().uuidString + "_" + localURL.lastPathComponent
        let tempURL = tempDir.appendingPathComponent(tempFileName)

        // Build request
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // For small files (< 1MB), use simple data download
        if expectedSize < 1_000_000 {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode >= 200 && httpResponse.statusCode < 400 else {
                throw DownloadEngineError.downloadFailed("Download failed")
            }
            
            // Write directly to final location
            if fileManager.fileExists(atPath: localURL.path) {
                try? fileManager.removeItem(at: localURL)
            }
            try data.write(to: localURL)
            
            await MainActor.run {
                self.items[index].downloadedBytes = Int64(data.count)
                self.items[index].progress = 1.0
                self.items[index].speed = 0
                self.updateTotalSpeed()
            }
            
            return localURL.path
        }
        
        // For larger files, use streaming download
        var resumeOffset: Int64 = 0

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

        // Write remaining buffer
        if !chunkBuffer.isEmpty {
            handle.write(chunkBuffer)
            bytesWritten += Int64(chunkBuffer.count)
        }
        
        // Ensure data is flushed to disk
        handle.synchronizeFile()
        try? handle.close()

        // Move from temp to final destination
        if fileManager.fileExists(atPath: localURL.path) {
            try? fileManager.removeItem(at: localURL)
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
