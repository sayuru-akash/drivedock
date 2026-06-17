import Foundation

@Observable
@MainActor
final class AppState {
    static let shared = AppState()

    let auth = GoogleAuthService.shared
    let engine = UploadEngine.shared
    let downloadEngine = DownloadEngine.shared
    let settings = AppSettings.shared
    let persistence = PersistenceService.shared
    let notifications = NotificationService.shared
    let networkMonitor = NetworkMonitor.shared

    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "app.hasCompletedOnboarding") {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "app.hasCompletedOnboarding")
        }
    }

    var selectedSidebarItem: SidebarItem = .uploads
    var selectedUploadItemID: String?
    var showDestinationPicker = false
    var showSettings = false
    var showInspector = false

    var isOnboarding: Bool {
        !hasCompletedOnboarding || auth.accounts.isEmpty
    }

    private init() {}
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case uploads
    case downloads
    case queue
    case active
    case completed
    case failed
    case paused
    case myDrive
    case sharedDrives
    case recentFiles
    case starredFiles
    case recentDestinations
    case starredDestinations
    case history
    case settings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .uploads: return "Uploads"
        case .downloads: return "Downloads"
        case .queue: return "Queue"
        case .active: return "Active"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .paused: return "Paused"
        case .myDrive: return "My Drive"
        case .sharedDrives: return "Shared Drives"
        case .recentFiles: return "Recent Files"
        case .starredFiles: return "Starred"
        case .recentDestinations: return "Recent"
        case .starredDestinations: return "Starred"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .uploads: return "arrow.up.circle"
        case .downloads: return "arrow.down.circle"
        case .queue: return "list.bullet"
        case .active: return "arrow.up.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .paused: return "pause.circle.fill"
        case .myDrive: return "folder.fill"
        case .sharedDrives: return "person.2.fill"
        case .recentFiles: return "clock"
        case .starredFiles: return "star.fill"
        case .recentDestinations: return "clock"
        case .starredDestinations: return "star.fill"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

enum SidebarSection: String, CaseIterable {
    case uploads
    case destinations
    case other
}
