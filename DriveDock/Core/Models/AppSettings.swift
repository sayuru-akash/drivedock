import Foundation
import SwiftUI

enum UploadMode: String, Codable, CaseIterable {
    case balanced
    case fast
    case light

    var displayName: String {
        switch self {
        case .balanced: return "Balanced"
        case .fast: return "Fast"
        case .light: return "Light"
        }
    }

    var description: String {
        switch self {
        case .balanced: return "Good speed without overwhelming your network"
        case .fast: return "Maximum throughput, higher network usage"
        case .light: return "Minimal impact on other apps and bandwidth"
        }
    }

    var maxConcurrentUploads: Int {
        switch self {
        case .balanced: return 3
        case .fast: return 6
        case .light: return 2
        }
    }

    var systemImage: String {
        switch self {
        case .balanced: return "scale.3d"
        case .fast: return "bolt.fill"
        case .light: return "leaf"
        }
    }
}

enum DestinationDefault: String, Codable, CaseIterable {
    case askEveryTime
    case lastUsedFolder
    case selectedFolder

    var displayName: String {
        switch self {
        case .askEveryTime: return "Ask Every Time"
        case .lastUsedFolder: return "Last Used Folder"
        case .selectedFolder: return "Selected Folder"
        }
    }
}

enum AfterUploadAction: String, Codable, CaseIterable {
    case showSummary
    case openUploadedFolder
    case doNothing

    var displayName: String {
        switch self {
        case .showSummary: return "Show Summary"
        case .openUploadedFolder: return "Open Uploaded Folder"
        case .doNothing: return "Do Nothing"
        }
    }
}

enum NotificationPreference: String, Codable, CaseIterable {
    case allComplete
    case errorsOnly
    case perLargeFile
    case disabled

    var displayName: String {
        switch self {
        case .allComplete: return "When All Uploads Finish"
        case .errorsOnly: return "Only on Errors"
        case .perLargeFile: return "Per Large File"
        case .disabled: return "Disabled"
        }
    }
}

enum AppTheme: String, Codable, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum AccentStyle: String, Codable, CaseIterable {
    case system
    case blue
    case purple
    case green
    case orange
    case red

    var displayName: String {
        switch self {
        case .system: return "System"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .green: return "Green"
        case .orange: return "Orange"
        case .red: return "Red"
        }
    }

    var tintColor: Color {
        switch self {
        case .system: return .accentColor
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        }
    }
}

enum ChunkSizeOption: String, Codable, CaseIterable {
    case auto
    case mb4
    case mb8
    case mb16

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .mb4: return "4 MB"
        case .mb8: return "8 MB"
        case .mb16: return "16 MB"
        }
    }

    var bytes: Int {
        switch self {
        case .auto: return 0
        case .mb4: return 4 * 1024 * 1024
        case .mb8: return 8 * 1024 * 1024
        case .mb16: return 16 * 1024 * 1024
        }
    }
}

@Observable
final class AppSettings {
    var launchAtLogin: Bool = false
    var showMenuBarIcon: Bool = true
    var showDockIcon: Bool = true
    var theme: AppTheme = .system
    var accentColor: AccentStyle = .system
    var confirmQuitWithActiveUploads: Bool = true
    var defaultStartScreen: SidebarItem = .uploads
    var defaultAccountID: String? = nil

    var defaultUploadMode: UploadMode = .balanced
    var defaultDestination: DestinationDefault = .askEveryTime
    var defaultDuplicateMode: DuplicateMode = .keepBoth
    var ignoreHiddenFiles: Bool = true
    var ignoreDSStore: Bool = true
    var preserveFolderStructure: Bool = true
    var autoRetryFailed: Bool = true
    var resumeOnLaunch: Bool = true
    var maxParallelUploads: Int = 3
    var maxActiveUploads: Int = 3
    var bandwidthLimitKBps: Int = 0

    var notificationPreference: NotificationPreference = .allComplete
    var notifyOnErrors: Bool = true

    var pauseOnMeteredNetwork: Bool = false
    var pauseOnVPNChange: Bool = false

    var chunkSize: ChunkSizeOption = .auto

    var maxRetryCount: Int = 5
    var debugLogsEnabled: Bool = false

    static let shared = AppSettings()

    private init() {
        load()
    }

    func load() {
        let defaults = UserDefaults.standard
        launchAtLogin = defaults.bool(forKey: "settings.launchAtLogin")
        showMenuBarIcon = defaults.bool(forKey: "settings.showMenuBarIcon")
        showDockIcon = defaults.bool(forKey: "settings.showDockIcon")
        if let themeStr = defaults.string(forKey: "settings.theme"),
           let t = AppTheme(rawValue: themeStr) {
            theme = t
        }
        if let accentStr = defaults.string(forKey: "settings.accentColor"),
           let a = AccentStyle(rawValue: accentStr) {
            accentColor = a
        }
        confirmQuitWithActiveUploads = defaults.object(forKey: "settings.confirmQuit") as? Bool ?? true

        if let startScreenStr = defaults.string(forKey: "settings.defaultStartScreen"),
           let s = SidebarItem(rawValue: startScreenStr) {
            defaultStartScreen = s
        }
        defaultAccountID = defaults.string(forKey: "settings.defaultAccountID")

        if let modeStr = defaults.string(forKey: "settings.uploadMode"),
           let m = UploadMode(rawValue: modeStr) {
            defaultUploadMode = m
        }
        if let destStr = defaults.string(forKey: "settings.destinationDefault"),
           let d = DestinationDefault(rawValue: destStr) {
            defaultDestination = d
        }
        if let dupStr = defaults.string(forKey: "settings.duplicateMode"),
           let d = DuplicateMode(rawValue: dupStr) {
            defaultDuplicateMode = d
        }

        ignoreHiddenFiles = defaults.object(forKey: "settings.ignoreHidden") as? Bool ?? true
        ignoreDSStore = defaults.object(forKey: "settings.ignoreDSStore") as? Bool ?? true
        preserveFolderStructure = defaults.object(forKey: "settings.preserveStructure") as? Bool ?? true
        autoRetryFailed = defaults.object(forKey: "settings.autoRetry") as? Bool ?? true
        resumeOnLaunch = defaults.object(forKey: "settings.resumeOnLaunch") as? Bool ?? true
        maxParallelUploads = defaults.object(forKey: "settings.maxParallel") as? Int ?? 3
        maxActiveUploads = defaults.object(forKey: "settings.maxActiveUploads") as? Int ?? 3
        bandwidthLimitKBps = defaults.object(forKey: "settings.bandwidthLimit") as? Int ?? 0

        if let notifStr = defaults.string(forKey: "settings.notificationPref"),
           let n = NotificationPreference(rawValue: notifStr) {
            notificationPreference = n
        }
        notifyOnErrors = defaults.object(forKey: "settings.notifyErrors") as? Bool ?? true

        pauseOnMeteredNetwork = defaults.object(forKey: "settings.pauseOnMetered") as? Bool ?? false
        pauseOnVPNChange = defaults.object(forKey: "settings.pauseOnVPN") as? Bool ?? false

        if let chunkStr = defaults.string(forKey: "settings.chunkSize"),
           let c = ChunkSizeOption(rawValue: chunkStr) {
            chunkSize = c
        }

        maxRetryCount = defaults.object(forKey: "settings.maxRetry") as? Int ?? 5
        debugLogsEnabled = defaults.bool(forKey: "settings.debugLogs")
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(launchAtLogin, forKey: "settings.launchAtLogin")
        defaults.set(showMenuBarIcon, forKey: "settings.showMenuBarIcon")
        defaults.set(showDockIcon, forKey: "settings.showDockIcon")
        defaults.set(theme.rawValue, forKey: "settings.theme")
        defaults.set(accentColor.rawValue, forKey: "settings.accentColor")
        defaults.set(confirmQuitWithActiveUploads, forKey: "settings.confirmQuit")
        defaults.set(defaultStartScreen.rawValue, forKey: "settings.defaultStartScreen")
        defaults.set(defaultAccountID, forKey: "settings.defaultAccountID")
        defaults.set(defaultUploadMode.rawValue, forKey: "settings.uploadMode")
        defaults.set(defaultDestination.rawValue, forKey: "settings.destinationDefault")
        defaults.set(defaultDuplicateMode.rawValue, forKey: "settings.duplicateMode")
        defaults.set(ignoreHiddenFiles, forKey: "settings.ignoreHidden")
        defaults.set(ignoreDSStore, forKey: "settings.ignoreDSStore")
        defaults.set(preserveFolderStructure, forKey: "settings.preserveStructure")
        defaults.set(autoRetryFailed, forKey: "settings.autoRetry")
        defaults.set(resumeOnLaunch, forKey: "settings.resumeOnLaunch")
        defaults.set(maxParallelUploads, forKey: "settings.maxParallel")
        defaults.set(maxActiveUploads, forKey: "settings.maxActiveUploads")
        defaults.set(bandwidthLimitKBps, forKey: "settings.bandwidthLimit")
        defaults.set(notificationPreference.rawValue, forKey: "settings.notificationPref")
        defaults.set(notifyOnErrors, forKey: "settings.notifyErrors")
        defaults.set(pauseOnMeteredNetwork, forKey: "settings.pauseOnMetered")
        defaults.set(pauseOnVPNChange, forKey: "settings.pauseOnVPN")
        defaults.set(chunkSize.rawValue, forKey: "settings.chunkSize")
        defaults.set(maxRetryCount, forKey: "settings.maxRetry")
        defaults.set(debugLogsEnabled, forKey: "settings.debugLogs")
    }
}
