import Foundation
import AppKit
import Network

enum UploadEngineError: LocalizedError {
    case itemNotFound
    case invalidState
    case sessionExpired
    case fileReadError
    case uploadFailed(String)
    case fileSizeChanged(expected: Int64, actual: Int64)
    case bandwidthLimitExceeded

    var errorDescription: String? {
        switch self {
        case .itemNotFound: return "Upload item not found"
        case .invalidState: return "Upload is in an invalid state"
        case .sessionExpired: return "Upload session expired"
        case .fileReadError: return "Could not read the file"
        case .uploadFailed(let msg): return "Upload failed: \(msg)"
        case .fileSizeChanged(let expected, let actual):
            return "File changed during upload (expected \(ByteCountFormatter.string(fromByteCount: expected, countStyle: .file)), now \(ByteCountFormatter.string(fromByteCount: actual, countStyle: .file)))"
        case .bandwidthLimitExceeded: return "Bandwidth limit exceeded"
        }
    }
}

@Observable
final class UploadEngine {
    static let shared = UploadEngine()

    private let driveAPI = DriveAPIService.shared
    private let auth = GoogleAuthService.shared
    private let persistence = PersistenceService.shared
    private let notifications = NotificationService.shared

    private(set) var items: [UploadItem] = []
    private(set) var batches: [UploadBatch] = []
    private(set) var isProcessing = false
    private(set) var totalSpeed: Double = 0
    private(set) var activeUploadCount: Int = 0

    private var activeTasks: [String: Task<Void, Never>] = [:]
    private var speedTrackers: [String: SpeedTracker] = [:]

    private let chunkSize = 8 * 1024 * 1024 // 8MB chunks

    // MARK: - Adaptive Concurrency

    private var errorTimestamps: [Date] = []
    private var rateLimitHitDate: Date?
    private var currentConcurrencyOverride: Int?
    private let errorWindowSeconds: TimeInterval = 60
    private let lowErrorWindowSeconds: TimeInterval = 30
    private let highErrorThreshold: Double = 0.30
    private let lowErrorThreshold: Double = 0.10
    private var lowErrorSince: Date?

    // MARK: - Sleep/Wake

    private var isSleeping = false

    private var effectiveMaxConcurrency: Int {
        let modeMax = AppSettings.shared.defaultUploadMode.maxConcurrentUploads
        if let override = currentConcurrencyOverride {
            return min(override, modeMax)
        }
        return modeMax
    }

    private init() {
        loadPersistedState()
        setupSleepWakeNotifications()
        setupNetworkMonitoring()
    }

    // MARK: - Sleep/Wake Detection

    private func setupSleepWakeNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func handleWillSleep() {
        isSleeping = true
        if isProcessing {
            pauseAll()
            for index in items.indices {
                if items[index].status == .paused {
                    items[index].errorMessage = "Paused (Mac sleeping)"
                }
            }
            persistence.saveQueue(items)
        }
    }

    @objc private func handleDidWake() {
        isSleeping = false
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                for index in self.items.indices {
                    if self.items[index].status == .paused && self.items[index].errorMessage == "Paused (Mac sleeping)" {
                        self.items[index].status = .waiting
                        self.items[index].errorMessage = nil
                    }
                }
                self.persistence.saveQueue(self.items)
                self.startProcessing()
            }
        }
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        let monitor = NetworkMonitor.shared
        monitor.onConnectionLost = { [weak self] in
            guard let self, self.isProcessing else { return }
            self.pauseAll()
        }
        monitor.onConnectionRestored = { [weak self] in
            guard let self else { return }
            let hasWaiting = self.items.contains { $0.status == .paused }
            if hasWaiting {
                self.resumeAll()
            }
        }
    }

    // MARK: - Adaptive Concurrency Helpers

    private func recordError() {
        let now = Date()
        errorTimestamps.append(now)
        errorTimestamps = errorTimestamps.filter { now.timeIntervalSince($0) <= errorWindowSeconds }
        adjustConcurrency()
    }

    private func record429() {
        rateLimitHitDate = Date()
        currentConcurrencyOverride = 1
    }

    private func adjustConcurrency() {
        let now = Date()
        let recentErrors = errorTimestamps.filter { now.timeIntervalSince($0) <= errorWindowSeconds }
        let totalRecent = Double(recentErrors.count)

        guard totalRecent > 0 else {
            if lowErrorSince == nil {
                lowErrorSince = now
            } else if now.timeIntervalSince(lowErrorSince!) >= lowErrorWindowSeconds {
                if let override = currentConcurrencyOverride, override < AppSettings.shared.defaultUploadMode.maxConcurrentUploads {
                    currentConcurrencyOverride = override + 1
                    lowErrorSince = now
                }
            }
            return
        }

        let errorRate = totalRecent / max(totalRecent, 1)
        if errorRate > highErrorThreshold {
            let current = currentConcurrencyOverride ?? effectiveMaxConcurrency
            currentConcurrencyOverride = max(1, current - 1)
            lowErrorSince = nil
        } else if errorRate < lowErrorThreshold {
            if lowErrorSince == nil {
                lowErrorSince = now
            }
        } else {
            lowErrorSince = nil
        }
    }

    private func check429Recovery() {
        guard let hitDate = rateLimitHitDate else { return }
        if Date().timeIntervalSince(hitDate) >= 60 {
            rateLimitHitDate = nil
            currentConcurrencyOverride = nil
        }
    }

    // MARK: - Queue Actions

    func addFiles(
        files: [LocalFileInfo],
        destinationFolderID: String,
        destinationFolderName: String,
        accountID: String,
        duplicateHandling: DuplicateMode = .keepBoth,
        batchName: String? = nil
    ) -> UploadBatch {
        let batchID = UUID().uuidString
        let batch = UploadBatch(
            id: batchID,
            name: batchName ?? "Upload \(Date().formatted(date: .abbreviated, time: .shortened))",
            accountID: accountID,
            destinationFolderID: destinationFolderID,
            destinationFolderName: destinationFolderName,
            status: .preparing,
            itemIDs: [],
            createdDate: Date(),
            totalSize: files.reduce(0) { $0 + $1.fileSize },
            uploadedSize: 0,
            duplicateHandling: duplicateHandling,
            preserveStructure: true
        )

        var itemIDs: [String] = []
        for file in files {
            let item = UploadItem(
                id: UUID().uuidString,
                localFileName: file.fileName,
                localFilePath: file.filePath,
                fileSize: file.fileSize,
                mimeType: file.mimeType,
                destinationFolderID: destinationFolderID,
                destinationFolderName: destinationFolderName,
                accountID: accountID,
                status: .waiting,
                progress: 0,
                uploadedBytes: 0,
                speed: 0,
                retryCount: 0,
                createdDate: Date(),
                lastActivityDate: Date(),
                isFolder: false,
                duplicateHandling: duplicateHandling,
                securityScopedBookmark: file.securityScopedBookmark
            )
            items.append(item)
            itemIDs.append(item.id)
        }

        var updatedBatch = batch
        updatedBatch.itemIDs = itemIDs
        updatedBatch.status = .ready
        batches.append(updatedBatch)

        persistence.saveQueue(items)
        persistence.saveBatches(batches)

        return updatedBatch
    }

    func addFolder(
        folderPath: String,
        folderName: String,
        destinationFolderID: String,
        destinationFolderName: String,
        accountID: String,
        duplicateHandling: DuplicateMode = .keepBoth
    ) async -> UploadBatch {
        let batchID = UUID().uuidString
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(atPath: folderPath) else {
            let batch = UploadBatch(
                id: batchID,
                name: folderName,
                accountID: accountID,
                destinationFolderID: destinationFolderID,
                destinationFolderName: destinationFolderName,
                status: .failed,
                itemIDs: [],
                createdDate: Date(),
                totalSize: 0,
                uploadedSize: 0,
                duplicateHandling: duplicateHandling,
                preserveStructure: true
            )
            batches.append(batch)
            return batch
        }

        var files: [LocalFileInfo] = []
        var totalSize: Int64 = 0

        while let relativePath = enumerator.nextObject() as? String {
            let fullPath = (folderPath as NSString).appendingPathComponent(relativePath)
            guard let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                  let fileType = attrs[.type] as? FileAttributeType,
                  fileType == .typeRegular else { continue }

            let fileName = (fullPath as NSString).lastPathComponent
            if AppSettings.shared.ignoreDSStore && fileName == ".DS_Store" { continue }
            if AppSettings.shared.ignoreHiddenFiles && fileName.hasPrefix(".") { continue }

            let fileSize = attrs[.size] as? Int64 ?? 0
            let mimeType = MIMETypeDetector.mimeType(for: fileName)

            files.append(LocalFileInfo(
                fileName: fileName,
                filePath: fullPath,
                fileSize: fileSize,
                mimeType: mimeType,
                relativePath: relativePath,
                securityScopedBookmark: nil
            ))
            totalSize += fileSize
        }

        let batch = UploadBatch(
            id: batchID,
            name: folderName,
            accountID: accountID,
            destinationFolderID: destinationFolderID,
            destinationFolderName: destinationFolderName,
            status: .preparing,
            itemIDs: [],
            createdDate: Date(),
            totalSize: totalSize,
            uploadedSize: 0,
            duplicateHandling: duplicateHandling,
            preserveStructure: true
        )

        var itemIDs: [String] = []
        for file in files {
            let item = UploadItem(
                id: UUID().uuidString,
                localFileName: file.fileName,
                localFilePath: file.filePath,
                fileSize: file.fileSize,
                mimeType: file.mimeType,
                destinationFolderID: destinationFolderID,
                destinationFolderName: destinationFolderName,
                accountID: accountID,
                status: .waiting,
                progress: 0,
                uploadedBytes: 0,
                speed: 0,
                retryCount: 0,
                createdDate: Date(),
                lastActivityDate: Date(),
                isFolder: false,
                folderPath: file.relativePath,
                duplicateHandling: duplicateHandling,
                securityScopedBookmark: file.securityScopedBookmark
            )
            items.append(item)
            itemIDs.append(item.id)
        }

        var updatedBatch = batch
        updatedBatch.itemIDs = itemIDs
        updatedBatch.status = .ready
        batches.append(updatedBatch)

        persistence.saveQueue(items)
        persistence.saveBatches(batches)

        return updatedBatch
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
        activeUploadCount = 0
        updateTotalSpeed()
        persistence.saveQueue(items)
    }

    func resumeAll() {
        for index in items.indices {
            if items[index].status == .paused {
                items[index].status = .waiting
            }
        }
        persistence.saveQueue(items)
        startProcessing()
    }

    func pauseItem(_ itemID: String) {
        activeTasks[itemID]?.cancel()
        activeTasks.removeValue(forKey: itemID)

        if let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index].status = .paused
            items[index].speed = 0
        }

        activeUploadCount = max(0, activeUploadCount - 1)
        updateTotalSpeed()
        persistence.saveQueue(items)
    }

    func resumeItem(_ itemID: String) {
        if let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index].status = .waiting
        }
        persistence.saveQueue(items)
        if !isProcessing { startProcessing() }
    }

    func cancelItem(_ itemID: String) {
        let sessionURL = items.first(where: { $0.id == itemID })?.resumableSessionURL
        activeTasks[itemID]?.cancel()
        activeTasks.removeValue(forKey: itemID)

        if let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index].status = .cancelled
            items[index].speed = 0
        }

        if let sessionURL {
            Task {
                try? await driveAPI.cancelResumableUpload(sessionURL: sessionURL)
            }
        }

        activeUploadCount = max(0, activeUploadCount - 1)
        updateTotalSpeed()
        persistence.saveQueue(items)
    }

    func retryItem(_ itemID: String) {
        if let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index].status = .waiting
            items[index].progress = 0
            items[index].uploadedBytes = 0
            items[index].errorMessage = nil
            items[index].errorCategory = nil
            items[index].retryCount += 1
        }
        persistence.saveQueue(items)
        if !isProcessing { startProcessing() }
    }

    func removeItem(_ itemID: String) {
        activeTasks[itemID]?.cancel()
        activeTasks.removeValue(forKey: itemID)
        items.removeAll { $0.id == itemID }
        for index in batches.indices {
            batches[index].itemIDs.removeAll { $0 == itemID }
        }
        persistence.saveQueue(items)
        persistence.saveBatches(batches)
    }

    func clearCompleted() {
        items.removeAll { $0.status == .completed || $0.status == .cancelled || $0.status == .skipped }
        persistence.saveQueue(items)
    }

    func clearFailed() {
        items.removeAll { $0.status == .failed }
        persistence.saveQueue(items)
    }

    func moveItemToFront(_ itemID: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let item = items.remove(at: index)
        items.insert(item, at: 0)
        persistence.saveQueue(items)
    }

    func moveItemToBack(_ itemID: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let item = items.remove(at: index)
        items.append(item)
        persistence.saveQueue(items)
    }

    func moveItemUp(_ itemID: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }), index > 0 else { return }
        items.swapAt(index, index - 1)
        persistence.saveQueue(items)
    }

    func moveItemDown(_ itemID: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }), index < items.count - 1 else { return }
        items.swapAt(index, index + 1)
        persistence.saveQueue(items)
    }

    // MARK: - Queue Processing

    private func processQueue() {
        Task {
            while isProcessing {
                check429Recovery()
                let maxConcurrent = effectiveMaxConcurrency
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
                        let batchIDs = Set(self.items.compactMap { $0.batchID })
                        for batchID in batchIDs {
                            self.notifications.clearNotificationsForBatch(batchID)
                        }
                        self.notifications.sendBatchCompleteNotification(
                            completedCount: items.filter { $0.status == .completed }.count,
                            failedCount: items.filter { $0.status == .failed }.count,
                            batchID: nil
                        )
                    } else if !hasWaiting && hasActive {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    } else {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                    continue
                }

                for item in waitingItems {
                    startUpload(item)
                }

                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func startUpload(_ item: UploadItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].status = .uploading
        items[index].lastActivityDate = Date()
        activeUploadCount += 1

        speedTrackers[item.id] = SpeedTracker()

        let task = Task {
            await performUpload(itemID: item.id)
        }

        activeTasks[item.id] = task
    }

    private func performUpload(itemID: String) async {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }

        let item = items[index]
        var fileURL = URL(fileURLWithPath: item.localFilePath)
        var didAccessSecurityScope = false

        if let bookmark = item.securityScopedBookmark,
           let resolvedURL = FileDropHandler.resolveSecurityScopedBookmark(bookmark) {
            if resolvedURL.startAccessingSecurityScopedResource() {
                didAccessSecurityScope = true
                fileURL = resolvedURL
            }
        }

        defer {
            if didAccessSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            await MainActor.run {
                self.items[index].status = .failed
                self.items[index].errorMessage = "Local file not found"
                self.items[index].errorCategory = .localFileMissing
                self.activeTasks.removeValue(forKey: itemID)
                self.activeUploadCount = max(0, self.activeUploadCount - 1)
                self.speedTrackers.removeValue(forKey: itemID)
                self.persistence.saveQueue(self.items)
            }
            return
        }

        do {
            if item.fileSize < 5 * 1024 * 1024 {
                try await performSimpleUpload(itemID: itemID, fileURL: fileURL)
            } else {
                try await performResumableUpload(itemID: itemID, fileURL: fileURL)
            }

            let link = try? await driveAPI.getFileLink(
                fileID: items[index].driveFileID ?? "",
                accountID: item.accountID
            )

            await MainActor.run {
                self.items[index].status = .completed
                self.items[index].progress = 1.0
                self.items[index].uploadedBytes = item.fileSize
                self.items[index].completedDate = Date()
                self.items[index].driveFileLink = link
                self.items[index].speed = 0

                self.addToHistory(self.items[index])

                if let batchIndex = self.batches.firstIndex(where: { $0.id == item.batchID }) {
                    self.batches[batchIndex].uploadedSize += item.fileSize
                }

                self.activeTasks.removeValue(forKey: itemID)
                self.activeUploadCount = max(0, self.activeUploadCount - 1)
                self.speedTrackers.removeValue(forKey: itemID)
                self.updateTotalSpeed()
                self.persistence.saveQueue(self.items)
                self.persistence.saveBatches(self.batches)
            }
        } catch {
            await MainActor.run {
                let errorCategory = self.classifyError(error)
                self.items[index].status = errorCategory.isRetryable ? .waiting : .failed
                self.items[index].errorMessage = error.localizedDescription
                self.items[index].errorCategory = errorCategory
                self.items[index].speed = 0
                self.items[index].retryCount += 1

                self.activeTasks.removeValue(forKey: itemID)
                self.activeUploadCount = max(0, self.activeUploadCount - 1)
                self.speedTrackers.removeValue(forKey: itemID)
                self.updateTotalSpeed()
                self.persistence.saveQueue(self.items)

                self.recordError()
                if errorCategory == .quotaRateLimit {
                    self.record429()
                }

                if !errorCategory.isRetryable {
                    self.notifications.sendUploadFailedNotification(
                        fileName: self.items[index].localFileName,
                        reason: errorCategory.displayName,
                        batchID: self.items[index].batchID,
                        driveFileLink: self.items[index].driveFileLink
                    )
                }
            }
        }
    }

    private func performSimpleUpload(itemID: String, fileURL: URL) async throws {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let item = items[index]

        let resolvedName = try await resolveDuplicateHandling(
            fileName: item.localFileName,
            destinationFolderID: item.destinationFolderID,
            accountID: item.accountID,
            duplicateHandling: item.duplicateHandling
        )

        let fileData = try Data(contentsOf: fileURL)
        let file = try await driveAPI.simpleUpload(
            fileData: fileData,
            fileName: resolvedName,
            mimeType: item.mimeType,
            parentFolderID: item.destinationFolderID,
            accountID: item.accountID
        )

        await MainActor.run {
            self.items[index].driveFileID = file.id
            self.items[index].driveFileLink = file.webViewLink
        }
    }

    private func performResumableUpload(itemID: String, fileURL: URL) async throws {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let item = items[index]

        let resolvedName = try await resolveDuplicateHandling(
            fileName: item.localFileName,
            destinationFolderID: item.destinationFolderID,
            accountID: item.accountID,
            duplicateHandling: item.duplicateHandling
        )

        let session = try await driveAPI.initiateResumableUpload(
            fileName: resolvedName,
            fileSize: item.fileSize,
            mimeType: item.mimeType,
            parentFolderID: item.destinationFolderID,
            accountID: item.accountID
        )

        await MainActor.run {
            self.items[index].resumableSessionURL = session.uploadURL
        }

        var uploadedBytes: Int64 = 0
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: fileURL)
        } catch {
            throw UploadEngineError.fileReadError
        }
        defer { try? handle.close() }

        while uploadedBytes < item.fileSize {
            if Task.isCancelled {
                try? await driveAPI.cancelResumableUpload(sessionURL: session.uploadURL)
                throw CancellationError()
            }

            let fileAttrs = try? FileManager.default.attributesOfItem(atPath: item.localFilePath)
            let currentFileSize = fileAttrs?[.size] as? Int64 ?? item.fileSize
            if currentFileSize != item.fileSize {
                throw UploadEngineError.fileSizeChanged(expected: item.fileSize, actual: currentFileSize)
            }

            let remaining = item.fileSize - uploadedBytes
            let currentChunkSize = min(Int64(chunkSize), remaining)

            handle.seek(toFileOffset: UInt64(uploadedBytes))
            let chunkData: Data
            do {
                guard let data = try handle.read(upToCount: Int(currentChunkSize)) else {
                    throw UploadEngineError.fileReadError
                }
                chunkData = data
            } catch let error as UploadEngineError {
                throw error
            } catch {
                throw UploadEngineError.fileReadError
            }

            let bandwidthLimit = AppSettings.shared.bandwidthLimitKBps
            if bandwidthLimit > 0 {
                let limitBytesPerSecond = Double(bandwidthLimit) * 1024.0
                let chunkBytes = Double(chunkData.count)
                let minDuration = chunkBytes / limitBytesPerSecond
                let elapsed = speedTrackers[itemID]?.currentWindowElapsed ?? 0
                if elapsed < minDuration {
                    let sleepNanoseconds = UInt64((minDuration - elapsed) * 1_000_000_000)
                    if sleepNanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: sleepNanoseconds)
                    }
                }
            }

            let result: (statusCode: Int, uploadedBytes: Int64)
            do {
                result = try await driveAPI.uploadChunk(
                    sessionURL: session.uploadURL,
                    data: chunkData,
                    rangeStart: uploadedBytes,
                    totalSize: item.fileSize
                )
            } catch {
                if Task.isCancelled {
                    try? await driveAPI.cancelResumableUpload(sessionURL: session.uploadURL)
                    throw CancellationError()
                }
                throw error
            }

            uploadedBytes = result.uploadedBytes

            let speed = speedTrackers[itemID]?.addBytes(Int64(chunkData.count)) ?? 0
            let remainingBytes = item.fileSize - uploadedBytes
            let eta = speed > 0 ? Double(remainingBytes) / speed : nil
            let currentUploaded = uploadedBytes
            let fileSize = item.fileSize

            await MainActor.run {
                self.items[index].uploadedBytes = currentUploaded
                self.items[index].progress = Double(currentUploaded) / Double(fileSize)
                self.items[index].speed = speed
                self.items[index].eta = eta
                self.items[index].lastActivityDate = Date()
                self.updateTotalSpeed()
            }

            if result.statusCode == 200 || result.statusCode == 201 {
                if let data = try? JSONSerialization.jsonObject(with: chunkData) as? [String: Any],
                   let fileId = data["id"] as? String {
                    await MainActor.run {
                        self.items[index].driveFileID = fileId
                    }
                }
                break
            }
        }
    }

    // MARK: - Duplicate Handling

    private func resolveDuplicateHandling(
        fileName: String,
        destinationFolderID: String,
        accountID: String,
        duplicateHandling: DuplicateMode
    ) async throws -> String {
        switch duplicateHandling {
        case .keepBoth:
            return fileName

        case .skipExisting:
            let existing = try await driveAPI.checkDuplicate(
                fileName: fileName,
                parentFolderID: destinationFolderID,
                accountID: accountID
            )
            if !existing.isEmpty {
                throw UploadEngineError.uploadFailed("Skipped: file already exists")
            }
            return fileName

        case .replaceExisting:
            let existing = try await driveAPI.checkDuplicate(
                fileName: fileName,
                parentFolderID: destinationFolderID,
                accountID: accountID
            )
            if let match = existing.first {
                await MainActor.run {
                    if let idx = self.items.firstIndex(where: { $0.localFileName == fileName && $0.destinationFolderID == destinationFolderID }) {
                        self.items[idx].driveFileID = match.id
                    }
                }
                throw UploadEngineError.uploadFailed("Replace not yet supported via re-upload")
            }
            return fileName

        case .renameNew:
            let existing = try await driveAPI.checkDuplicate(
                fileName: fileName,
                parentFolderID: destinationFolderID,
                accountID: accountID
            )
            guard !existing.isEmpty else { return fileName }

            let nameWithoutExt = (fileName as NSString).deletingPathExtension
            let ext = (fileName as NSString).pathExtension
            var candidate: String
            var counter = 2
            repeat {
                candidate = ext.isEmpty ? "\(nameWithoutExt) \(counter)" : "\(nameWithoutExt) \(counter).\(ext)"
                let collisions = try await driveAPI.checkDuplicate(
                    fileName: candidate,
                    parentFolderID: destinationFolderID,
                    accountID: accountID
                )
                if collisions.isEmpty { return candidate }
                counter += 1
            } while counter < 1000

            return candidate
        }
    }

    // MARK: - Error Classification

    private func classifyError(_ error: Error) -> ErrorCategory {
        if let apiError = error as? DriveAPIError {
            switch apiError {
            case .networkUnavailable: return .network
            case .rateLimited: return .quotaRateLimit
            case .authenticationRequired: return .authentication
            case .permissionDenied: return .permission
            case .notFound: return .destinationMissing
            case .quotaExceeded: return .storageQuotaExceeded
            case .httpError(let code, _):
                if code == 429 { return .quotaRateLimit }
                if code >= 500 { return .network }
                return .unknown
            default: return .unknown
            }
        }

        if let uploadError = error as? UploadEngineError {
            switch uploadError {
            case .fileSizeChanged: return .fileChanged
            case .fileReadError: return .localFileMissing
            default: break
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .network
        }

        if error is CancellationError {
            return .network
        }

        return .unknown
    }

    // MARK: - Speed & Stats

    private func updateTotalSpeed() {
        totalSpeed = items.filter { $0.status == .uploading }.reduce(0) { $0 + $1.speed }
    }

    var overallProgress: Double {
        let totalSize = items.reduce(Int64(0)) { $0 + $1.fileSize }
        let uploadedSize = items.reduce(Int64(0)) { $0 + $1.uploadedBytes }
        guard totalSize > 0 else { return 0 }
        return Double(uploadedSize) / Double(totalSize)
    }

    var waitingCount: Int { items.filter { $0.status == .waiting }.count }
    var completedCount: Int { items.filter { $0.status == .completed }.count }
    var failedCount: Int { items.filter { $0.status == .failed }.count }
    var pausedCount: Int { items.filter { $0.status == .paused }.count }

    #if DEBUG
    func replaceWithScreenshotData(items screenshotItems: [UploadItem], batches screenshotBatches: [UploadBatch]) {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
        speedTrackers.removeAll()
        items = screenshotItems
        batches = screenshotBatches
        isProcessing = screenshotItems.contains { $0.status == .uploading }
        activeUploadCount = screenshotItems.filter { $0.status == .uploading }.count
        updateTotalSpeed()
    }
    #endif

    // MARK: - History

    private func addToHistory(_ item: UploadItem) {
        let entry = UploadHistoryEntry(
            id: UUID().uuidString,
            fileName: item.localFileName,
            fileSize: item.fileSize,
            accountEmail: auth.accounts.first { $0.id == item.accountID }?.email ?? "",
            destinationFolderName: item.destinationFolderName,
            destinationFolderID: item.destinationFolderID,
            status: item.status,
            startedDate: item.createdDate,
            completedDate: item.completedDate,
            duration: item.completedDate?.timeIntervalSince(item.createdDate),
            averageSpeed: item.speed,
            driveFileLink: item.driveFileLink,
            batchID: item.batchID,
            isFolder: item.isFolder
        )
        persistence.addHistoryEntry(entry)
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        items = persistence.loadQueue()
        batches = persistence.loadBatches()

        for index in items.indices {
            if items[index].status == .uploading && items[index].resumableSessionURL != nil {
                items[index].status = .waiting
                items[index].progress = 0
                items[index].uploadedBytes = 0
                items[index].speed = 0
            }
        }

        persistence.saveQueue(items)
    }

    func saveState() {
        persistence.saveQueue(items)
        persistence.saveBatches(batches)
    }
}

// MARK: - Speed Tracker

final class SpeedTracker {
    private var bytesPerSecond: [Date: Int64] = [:]
    private let windowDuration: TimeInterval = 5

    var currentWindowElapsed: TimeInterval {
        guard let earliest = bytesPerSecond.keys.min() else { return 0 }
        return Date().timeIntervalSince(earliest)
    }

    func addBytes(_ bytes: Int64) -> Double {
        let now = Date()
        bytesPerSecond[now] = bytes

        let cutoff = now.addingTimeInterval(-windowDuration)
        bytesPerSecond = bytesPerSecond.filter { $0.key > cutoff }

        guard !bytesPerSecond.isEmpty else { return 0 }
        let totalBytes = bytesPerSecond.values.reduce(0, +)
        let timeSpan = now.timeIntervalSince(bytesPerSecond.keys.min() ?? now)
        guard timeSpan > 0 else { return 0 }
        return Double(totalBytes) / timeSpan
    }
}

struct LocalFileInfo {
    let fileName: String
    let filePath: String
    let fileSize: Int64
    let mimeType: String
    let relativePath: String?
    let securityScopedBookmark: Data?
}
