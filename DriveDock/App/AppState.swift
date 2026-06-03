import Foundation

@Observable
final class AppState {
    static let shared = AppState()

    let auth = GoogleAuthService.shared
    let engine = UploadEngine.shared
    let settings = AppSettings.shared
    let persistence = PersistenceService.shared
    let notifications = NotificationService.shared

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "app.hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "app.hasCompletedOnboarding") }
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
    case queue
    case active
    case completed
    case failed
    case paused
    case recentDestinations
    case starredDestinations
    case sharedDrives
    case history
    case settings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .uploads: return "Uploads"
        case .queue: return "Queue"
        case .active: return "Active"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .paused: return "Paused"
        case .recentDestinations: return "Recent"
        case .starredDestinations: return "Starred"
        case .sharedDrives: return "Shared Drives"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .uploads: return "arrow.up.circle"
        case .queue: return "list.bullet"
        case .active: return "arrow.up.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .paused: return "pause.circle.fill"
        case .recentDestinations: return "clock"
        case .starredDestinations: return "star.fill"
        case .sharedDrives: return "person.2.fill"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }

    var section: SidebarSection {
        switch self {
        case .uploads, .queue, .active, .completed, .failed, .paused: return .uploads
        case .recentDestinations, .starredDestinations, .sharedDrives: return .destinations
        case .history: return .other
        case .settings: return .other
        }
    }
}

enum SidebarSection: String, CaseIterable {
    case uploads
    case destinations
    case other
}
