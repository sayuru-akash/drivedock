import Foundation

final class PersistenceService {
    static let shared = PersistenceService()

    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default
    let fileLock = NSLock()

    var appSupportURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DriveDock")
    }

    private var backupURL: URL {
        appSupportURL.appendingPathComponent("backups")
    }

    private let schemaVersionKey = "persistence.schemaVersion"
    private let currentSchemaVersion = 1

    private init() {
        createAppSupportDirectoryIfNeeded()
        migrateIfNeeded()
    }

    // MARK: - Queue

    func saveQueue(_ items: [UploadItem]) {
        fileLock.lock()
        defer { fileLock.unlock() }

        guard let data = try? JSONEncoder().encode(items) else { return }
        let url = appSupportURL.appendingPathComponent("queue.json")

        guard hasSufficientDiskSpace(for: data.count) else { return }
        createBackup(for: url)
        try? data.write(to: url)
    }

    func loadQueue() -> [UploadItem] {
        fileLock.lock()
        defer { fileLock.unlock() }

        let url = appSupportURL.appendingPathComponent("queue.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([UploadItem].self, from: data)) ?? []
    }

    // MARK: - Batches

    func saveBatches(_ batches: [UploadBatch]) {
        fileLock.lock()
        defer { fileLock.unlock() }

        guard let data = try? JSONEncoder().encode(batches) else { return }
        let url = appSupportURL.appendingPathComponent("batches.json")

        guard hasSufficientDiskSpace(for: data.count) else { return }
        createBackup(for: url)
        try? data.write(to: url)
    }

    func loadBatches() -> [UploadBatch] {
        fileLock.lock()
        defer { fileLock.unlock() }

        let url = appSupportURL.appendingPathComponent("batches.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([UploadBatch].self, from: data)) ?? []
    }

    // MARK: - History

    func addHistoryEntry(_ entry: UploadHistoryEntry) {
        fileLock.lock()
        defer { fileLock.unlock() }

        var history = loadHistoryInternal()
        history.insert(entry, at: 0)

        if history.count > 1000 {
            history = Array(history.prefix(1000))
        }

        saveHistoryInternal(history)
    }

    func loadHistory() -> [UploadHistoryEntry] {
        fileLock.lock()
        defer { fileLock.unlock() }
        return loadHistoryInternal()
    }

    private func loadHistoryInternal() -> [UploadHistoryEntry] {
        let url = appSupportURL.appendingPathComponent("history.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([UploadHistoryEntry].self, from: data)) ?? []
    }

    func saveHistory(_ entries: [UploadHistoryEntry]) {
        fileLock.lock()
        defer { fileLock.unlock() }
        saveHistoryInternal(entries)
    }

    private func saveHistoryInternal(_ entries: [UploadHistoryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        let url = appSupportURL.appendingPathComponent("history.json")

        guard hasSufficientDiskSpace(for: data.count) else { return }
        createBackup(for: url)
        try? data.write(to: url)
    }

    func clearHistory() {
        let url = appSupportURL.appendingPathComponent("history.json")
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Recent Destinations

    func addRecentDestination(_ destination: RecentDestination) {
        fileLock.lock()
        defer { fileLock.unlock() }

        var recents = loadRecentDestinationsInternal()
        recents.removeAll { $0.folderID == destination.folderID && $0.accountID == destination.accountID }
        recents.insert(destination, at: 0)

        if recents.count > 20 {
            recents = Array(recents.prefix(20))
        }

        guard let data = try? JSONEncoder().encode(recents) else { return }
        let url = appSupportURL.appendingPathComponent("recent_destinations.json")
        guard hasSufficientDiskSpace(for: data.count) else { return }
        try? data.write(to: url)
    }

    func loadRecentDestinations() -> [RecentDestination] {
        fileLock.lock()
        defer { fileLock.unlock() }
        return loadRecentDestinationsInternal()
    }

    private func loadRecentDestinationsInternal() -> [RecentDestination] {
        let url = appSupportURL.appendingPathComponent("recent_destinations.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([RecentDestination].self, from: data)) ?? []
    }

    // MARK: - Starred Destinations

    func toggleStarred(_ destination: StarredDestination) {
        fileLock.lock()
        defer { fileLock.unlock() }

        var starred = loadStarredDestinationsInternal()
        if starred.contains(where: { $0.folderID == destination.folderID }) {
            starred.removeAll { $0.folderID == destination.folderID }
        } else {
            starred.append(destination)
        }

        guard let data = try? JSONEncoder().encode(starred) else { return }
        let url = appSupportURL.appendingPathComponent("starred_destinations.json")
        guard hasSufficientDiskSpace(for: data.count) else { return }
        try? data.write(to: url)
    }

    func loadStarredDestinations() -> [StarredDestination] {
        fileLock.lock()
        defer { fileLock.unlock() }
        return loadStarredDestinationsInternal()
    }

    private func loadStarredDestinationsInternal() -> [StarredDestination] {
        let url = appSupportURL.appendingPathComponent("starred_destinations.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([StarredDestination].self, from: data)) ?? []
    }

    // MARK: - Export

    func exportHistory(as format: ExportFormat) -> Data? {
        let history = loadHistory()
        let summary = HistoryExport.ExportSummary(
            totalFiles: history.count,
            totalSize: history.reduce(0) { $0 + $1.fileSize },
            successCount: history.filter { $0.status == .completed }.count,
            failureCount: history.filter { $0.status == .failed }.count,
            skippedCount: history.filter { $0.status == .skipped }.count,
            totalDuration: history.compactMap(\.duration).reduce(0, +)
        )

        let export = HistoryExport(exportDate: Date(), entries: history, summary: summary)

        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return try? encoder.encode(export)

        case .csv:
            return generateCSV(history: history)

        case .text:
            return generateTextReport(export: export)
        }
    }

    private func generateCSV(history: [UploadHistoryEntry]) -> Data? {
        var csv = "Date,File Name,Size,Account,Destination,Status,Duration,Average Speed,Drive Link,Error\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        for entry in history {
            let date = dateFormatter.string(from: entry.completedDate ?? entry.startedDate)
            let name = "\"\(entry.fileName)\""
            let size = entry.formattedSize
            let account = "\"\(entry.accountEmail)\""
            let dest = "\"\(entry.destinationFolderName)\""
            let status = entry.status.displayName
            let duration = entry.formattedDuration
            let speed = entry.formattedSpeed
            let link = entry.driveFileLink ?? ""
            let error = entry.errorMessage.map { "\"\($0)\"" } ?? ""

            csv += "\(date),\(name),\(size),\(account),\(dest),\(status),\(duration),\(speed),\(link),\(error)\n"
        }

        return csv.data(using: .utf8)
    }

    private func generateTextReport(export: HistoryExport) -> Data? {
        var text = "DriveDock Upload Report\n"
        text += "Generated: \(export.exportDate.formatted(date: .long, time: .standard))\n\n"
        text += "Summary\n"
        text += "-------\n"
        text += "Total files: \(export.summary.totalFiles)\n"
        text += "Total size: \(export.summary.formattedTotalSize)\n"
        text += "Succeeded: \(export.summary.successCount)\n"
        text += "Failed: \(export.summary.failureCount)\n"
        text += "Skipped: \(export.summary.skippedCount)\n\n"
        text += "Details\n"
        text += "-------\n"

        for entry in export.entries {
            text += "\(entry.fileName) - \(entry.status.displayName) - \(entry.formattedSize)\n"
            text += "  Account: \(entry.accountEmail)\n"
            text += "  Destination: \(entry.destinationFolderName)\n"
            if let error = entry.errorMessage {
                text += "  Error: \(error)\n"
            }
            text += "\n"
        }

        return text.data(using: .utf8)
    }

    // MARK: - Cleanup

    func clearAllLocalData() {
        fileLock.lock()
        defer { fileLock.unlock() }

        try? fileManager.removeItem(at: appSupportURL)
        createAppSupportDirectoryIfNeeded()
    }

    private func createAppSupportDirectoryIfNeeded() {
        try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)
    }

    // MARK: - Disk Space

    func hasSufficientDiskSpace(for bytes: Int) -> Bool {
        guard let attrs = try? fileManager.attributesOfFileSystem(forPath: appSupportURL.path),
              let freeSpace = attrs[.systemFreeSize] as? Int64 else {
            return true
        }
        return freeSpace > Int64(bytes) + 10 * 1024 * 1024
    }

    // MARK: - Backup

    func createBackup(for fileURL: URL) {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        let fileName = fileURL.lastPathComponent
        let backupFileURL = backupURL.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: backupFileURL)
        try? fileManager.copyItem(at: fileURL, to: backupFileURL)
    }

    func restoreBackup(for fileName: String) -> Bool {
        let backupFileURL = backupURL.appendingPathComponent(fileName)
        let targetURL = appSupportURL.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: backupFileURL.path) else { return false }
        try? fileManager.removeItem(at: targetURL)
        do {
            try fileManager.copyItem(at: backupFileURL, to: targetURL)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Migration

    private func migrateIfNeeded() {
        let savedVersion = defaults.integer(forKey: schemaVersionKey)
        guard savedVersion < currentSchemaVersion else { return }

        if savedVersion == 0 {
            defaults.set(currentSchemaVersion, forKey: schemaVersionKey)
        }
    }

    func validateDataIntegrity() -> (queueValid: Bool, batchesValid: Bool, historyValid: Bool) {
        let queueURL = appSupportURL.appendingPathComponent("queue.json")
        let batchesURL = appSupportURL.appendingPathComponent("batches.json")
        let historyURL = appSupportURL.appendingPathComponent("history.json")

        let queueValid = validateJSONFile(at: queueURL, type: [UploadItem].self)
        let batchesValid = validateJSONFile(at: batchesURL, type: [UploadBatch].self)
        let historyValid = validateJSONFile(at: historyURL, type: [UploadHistoryEntry].self)

        return (queueValid, batchesValid, historyValid)
    }

    private func validateJSONFile<T: Decodable>(at url: URL, type: T.Type) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return true }
        guard let data = try? Data(contentsOf: url) else { return false }
        return (try? JSONDecoder().decode(type, from: data)) != nil
    }

    // MARK: - Download Persistence

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

    enum ExportFormat {
        case json, csv, text
    }
}
