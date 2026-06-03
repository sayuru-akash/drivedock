import Foundation

struct DriveFolder: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var parentID: String?
    var isSharedDrive: Bool
    var sharedDriveID: String?
    var ownerEmail: String?
    var modifiedDate: Date?
    var childCount: Int?

    var isRoot: Bool {
        parentID == nil || parentID == "root"
    }

    static func == (lhs: DriveFolder, rhs: DriveFolder) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct RecentDestination: Identifiable, Codable, Hashable {
    let id: String
    var folderID: String
    var folderName: String
    var accountID: String
    var isSharedDrive: Bool
    var lastUsedDate: Date

    static func == (lhs: RecentDestination, rhs: RecentDestination) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct StarredDestination: Identifiable, Codable, Hashable {
    let id: String
    var folderID: String
    var folderName: String
    var accountID: String
    var isSharedDrive: Bool
    var starredDate: Date

    static func == (lhs: StarredDestination, rhs: StarredDestination) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct SharedDrive: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var createdDate: Date?

    static func == (lhs: SharedDrive, rhs: SharedDrive) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct DriveFile: Identifiable, Codable {
    let id: String
    var name: String
    var mimeType: String
    var size: Int64?
    var parentID: String?
    var webViewLink: String?
    var createdDate: Date?
    var modifiedDate: Date?

    var isFolder: Bool {
        mimeType == "application/vnd.google-apps.folder"
    }

    var formattedSize: String {
        guard let size else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
