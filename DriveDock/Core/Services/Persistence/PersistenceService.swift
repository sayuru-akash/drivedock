import Foundation

final class PersistenceService {
    static let shared = PersistenceService()

    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default

    private var appSupportURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DriveDock")
    }

    private init() {
        createAppSupportDirectoryIfNeeded()
    }

    // MARK: - Queue

    func saveQueue(_ items: [UploadItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        let url = appSupportURL.appendingPathComponent("queue.json")
        try? data.write(to: url)
    }

    func loadQueue() -> [UploadItem] {
        let url = appSupportURL.appendingPathComponent("queue.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([UploadItem].self, from: data)) ?? []
    }

    // MARK: - Batches

    func saveBatches(_ batches: [UploadBatch]) {
        guard let data = try? JSONEncoder().encode(batches) else { return }
        let url = appSupportURL.appendingPathComponent("batches.json")
        try? data.write(to: url)
    }

    func loadBatches() -> [UploadBatch] {
        let url = appSupportURL.appendingPathComponent("batches.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([UploadBatch].self, from: data)) ?? []
    }

    // MARK: - History

    func addHistoryEntry(_ entry: UploadHistoryEntry) {
        var history = loadHistory()
        history.insert(entry, at: 0)

        if history.count > 1000 {
            history = Array(history.prefix(1000))
        }

        saveHistory(history)
    }

    func loadHistory() -> [UploadHistoryEntry] {
        let url = appSupportURL.appendingPathComponent("history.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([UploadHistoryEntry].self, from: data)) ?? []
    }

    func saveHistory(_ entries: [UploadHistoryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        let url = appSupportURL.appendingPathComponent("history.json")
        try? data.write(to: url)
    }

    func clearHistory() {
        let url = appSupportURL.appendingPathComponent("history.json")
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Recent Destinations

    func addRecentDestination(_ destination: RecentDestination) {
        var recents = loadRecentDestinations()
        recents.removeAll { $0.folderID == destination.folderID && $0.accountID == destination.accountID }
        recents.insert(destination, at: 0)

        if recents.count > 20 {
            recents = Array(recents.prefix(20))
        }

        guard let data = try? JSONEncoder().encode(recents) else { return }
        let url = appSupportURL.appendingPathComponent("recent_destinations.json")
        try? data.write(to: url)
    }

    func loadRecentDestinations() -> [RecentDestination] {
        let url = appSupportURL.appendingPathComponent("recent_destinations.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([RecentDestination].self, from: data)) ?? []
    }

    // MARK: - Starred Destinations

    func toggleStarred(_ destination: StarredDestination) {
        var starred = loadStarredDestinations()
        if starred.contains(where: { $0.folderID == destination.folderID }) {
            starred.removeAll { $0.folderID == destination.folderID }
        } else {
            starred.append(destination)
        }

        guard let data = try? JSONEncoder().encode(starred) else { return }
        let url = appSupportURL.appendingPathComponent("starred_destinations.json")
        try? data.write(to: url)
    }

    func loadStarredDestinations() -> [StarredDestination] {
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
        try? fileManager.removeItem(at: appSupportURL)
        createAppSupportDirectoryIfNeeded()
    }

    private func createAppSupportDirectoryIfNeeded() {
        try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
    }

    enum ExportFormat {
        case json, csv, text
    }
}
