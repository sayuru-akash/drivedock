import Foundation

struct UploadHistoryEntry: Identifiable, Codable {
    let id: String
    var fileName: String
    var fileSize: Int64
    var accountEmail: String
    var destinationFolderName: String
    var destinationFolderID: String
    var status: UploadItemStatus
    var startedDate: Date
    var completedDate: Date?
    var duration: TimeInterval?
    var averageSpeed: Double?
    var driveFileLink: String?
    var errorMessage: String?
    var batchID: String?
    var isFolder: Bool

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDuration: String {
        guard let duration else { return "—" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "—"
    }

    var formattedSpeed: String {
        guard let averageSpeed, averageSpeed > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(averageSpeed), countStyle: .file) + "/s"
    }
}

struct HistoryExport: Codable {
    var exportDate: Date
    var entries: [UploadHistoryEntry]
    var summary: ExportSummary

    struct ExportSummary: Codable {
        var totalFiles: Int
        var totalSize: Int64
        var successCount: Int
        var failureCount: Int
        var skippedCount: Int
        var totalDuration: TimeInterval?

        var formattedTotalSize: String {
            ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        }
    }
}
