import Foundation

enum DownloadItemStatus: String, Codable, CaseIterable {
    case waiting
    case downloading
    case paused
    case completed
    case failed
    case cancelled

    var displayName: String {
        switch self {
        case .waiting: return "Waiting"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    var systemImage: String {
        switch self {
        case .waiting: return "clock"
        case .downloading: return "arrow.down.circle"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    var isActive: Bool {
        self == .downloading
    }

    var isTerminal: Bool {
        self == .completed || self == .cancelled
    }
}

struct DownloadItem: Identifiable, Codable {
    let id: String
    var fileName: String
    var driveFileID: String
    var localPath: String
    var fileSize: Int64
    var downloadedBytes: Int64
    var progress: Double
    var speed: Double
    var eta: TimeInterval?
    var status: DownloadItemStatus
    var error: String?
    var accountID: String
    var createdDate: Date
    var lastActivityDate: Date
    var completedDate: Date?
    var batchID: String?
    var isFolder: Bool
    var folderPath: String?

    var progressPercent: Int {
        Int(progress * 100)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDownloaded: String {
        ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file)
    }

    var formattedSpeed: String {
        guard speed > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s"
    }

    var formattedETA: String {
        guard let eta, eta > 0 else { return "—" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: eta) ?? "—"
    }
}

struct DownloadBatch: Identifiable, Codable {
    let id: String
    var name: String
    var accountID: String
    var sourceFolderID: String?
    var sourceFolderName: String?
    var status: DownloadItemStatus
    var itemIDs: [String]
    var createdDate: Date
    var totalSize: Int64
    var downloadedSize: Int64
}
