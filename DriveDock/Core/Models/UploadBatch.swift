import Foundation

enum UploadBatchStatus: String, Codable {
    case preparing
    case ready
    case uploading
    case partiallyCompleted
    case completed
    case paused
    case failed
    case cancelled

    var displayName: String {
        switch self {
        case .preparing: return "Preparing"
        case .ready: return "Ready"
        case .uploading: return "Uploading"
        case .partiallyCompleted: return "Partially Completed"
        case .completed: return "Completed"
        case .paused: return "Paused"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
}

struct UploadBatch: Identifiable, Codable {
    let id: String
    var name: String
    var accountID: String
    var destinationFolderID: String
    var destinationFolderName: String
    var status: UploadBatchStatus
    var itemIDs: [String]
    var createdDate: Date
    var startedDate: Date?
    var completedDate: Date?
    var totalSize: Int64
    var uploadedSize: Int64
    var duplicateHandling: DuplicateMode
    var preserveStructure: Bool

    var progress: Double {
        guard totalSize > 0 else { return 0 }
        return Double(uploadedSize) / Double(totalSize)
    }

    var progressPercent: Int {
        Int(progress * 100)
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var duration: TimeInterval? {
        guard let started = startedDate else { return nil }
        let end = completedDate ?? Date()
        return end.timeIntervalSince(started)
    }

    var formattedDuration: String {
        guard let duration else { return "—" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "—"
    }
}
