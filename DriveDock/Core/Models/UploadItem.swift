import Foundation

enum UploadItemStatus: String, Codable, CaseIterable {
    case preparing
    case waiting
    case uploading
    case paused
    case completed
    case failed
    case cancelled
    case needsAccountReconnect
    case needsDestinationPermission
    case skipped

    var displayName: String {
        switch self {
        case .preparing: return "Preparing"
        case .waiting: return "Waiting"
        case .uploading: return "Uploading"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .needsAccountReconnect: return "Needs Reconnect"
        case .needsDestinationPermission: return "Permission Needed"
        case .skipped: return "Skipped"
        }
    }

    var systemImage: String {
        switch self {
        case .preparing: return "gearshape"
        case .waiting: return "clock"
        case .uploading: return "arrow.up.circle"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle"
        case .needsAccountReconnect: return "person.crop.circle.badge.exclamationmark"
        case .needsDestinationPermission: return "lock.shield"
        case .skipped: return "forward.circle"
        }
    }

    var isActive: Bool {
        self == .uploading || self == .preparing
    }

    var isTerminal: Bool {
        self == .completed || self == .cancelled || self == .skipped
    }
}

struct UploadItem: Identifiable, Codable {
    let id: String
    var localFileName: String
    var localFilePath: String
    var fileSize: Int64
    var mimeType: String
    var destinationFolderID: String
    var destinationFolderName: String
    var accountID: String
    var status: UploadItemStatus
    var progress: Double
    var uploadedBytes: Int64
    var speed: Double
    var eta: TimeInterval?
    var retryCount: Int
    var errorMessage: String?
    var errorCategory: ErrorCategory?
    var driveFileID: String?
    var driveFileLink: String?
    var resumableSessionURL: String?
    var createdDate: Date
    var lastActivityDate: Date
    var completedDate: Date?
    var batchID: String?
    var isFolder: Bool
    var folderPath: String?
    var duplicateHandling: DuplicateMode
    var securityScopedBookmark: Data?

    var progressPercent: Int {
        Int(progress * 100)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedUploaded: String {
        ByteCountFormatter.string(fromByteCount: uploadedBytes, countStyle: .file)
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

enum DuplicateMode: String, Codable, CaseIterable {
    case keepBoth
    case renameNew
    case skipExisting
    case replaceExisting

    var displayName: String {
        switch self {
        case .keepBoth: return "Keep Both"
        case .renameNew: return "Rename New File"
        case .skipExisting: return "Skip Existing"
        case .replaceExisting: return "Replace Existing"
        }
    }
}

enum ErrorCategory: String, Codable, CaseIterable {
    case network
    case quotaRateLimit
    case authentication
    case permission
    case destinationMissing
    case localFileMissing
    case fileChanged
    case fileTooLarge
    case storageQuotaExceeded
    case sharedDriveRestriction
    case unknown

    var displayName: String {
        switch self {
        case .network: return "Network Error"
        case .quotaRateLimit: return "Rate Limited"
        case .authentication: return "Authentication Error"
        case .permission: return "Permission Denied"
        case .destinationMissing: return "Destination Not Found"
        case .localFileMissing: return "Local File Missing"
        case .fileChanged: return "File Changed"
        case .fileTooLarge: return "File Too Large"
        case .storageQuotaExceeded: return "Storage Full"
        case .sharedDriveRestriction: return "Shared Drive Restriction"
        case .unknown: return "Unknown Error"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .network, .quotaRateLimit: return true
        case .unknown: return true
        default: return false
        }
    }

    var userAction: String {
        switch self {
        case .network:
            return "Your internet connection was interrupted. DriveDock will retry automatically when connectivity returns."
        case .quotaRateLimit:
            return "Google is slowing requests right now. DriveDock is pausing briefly and will resume automatically."
        case .authentication:
            return "This account needs to be reconnected. Go to Settings \u{203A} Accounts to reconnect it."
        case .permission:
            return "You don\u{2019}t have permission to upload to this location. Try a different folder or ask the owner for access."
        case .destinationMissing:
            return "The destination folder no longer exists. Choose a different folder and try again."
        case .localFileMissing:
            return "The original file can\u{2019}t be found. It may have been moved, renamed, or deleted since it was added."
        case .fileChanged:
            return "The file was modified while uploading. Re-add it to the queue to upload the latest version."
        case .fileTooLarge:
            return "This file is too large for Google Drive. The limit is 5 TB per file. Try compressing or splitting it."
        case .storageQuotaExceeded:
            return "Your Google Drive is full. Free up space or upgrade your storage plan, then retry."
        case .sharedDriveRestriction:
            return "This Shared Drive doesn\u{2019}t allow uploads from your account. Contact the Shared Drive manager for access."
        case .unknown:
            return "Something unexpected happened. Try again \u{2014} it usually resolves on its own."
        }
    }
}
