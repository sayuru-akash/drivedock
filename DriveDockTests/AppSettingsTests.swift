import XCTest
@testable import DriveDock

final class AppSettingsTests: XCTestCase {

    private let defaults = UserDefaults.standard
    private let suiteName = "AppSettingsTests"

    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)!
        testDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - UploadMode

    func testUploadModeMaxConcurrentUploads() {
        XCTAssertEqual(UploadMode.balanced.maxConcurrentUploads, 3)
        XCTAssertEqual(UploadMode.fast.maxConcurrentUploads, 6)
        XCTAssertEqual(UploadMode.light.maxConcurrentUploads, 2)
    }

    func testUploadModeDisplayNames() {
        XCTAssertEqual(UploadMode.balanced.displayName, "Balanced")
        XCTAssertEqual(UploadMode.fast.displayName, "Fast")
        XCTAssertEqual(UploadMode.light.displayName, "Light")
    }

    func testUploadModeAllCases() {
        XCTAssertEqual(UploadMode.allCases.count, 3)
    }

    // MARK: - DestinationDefault

    func testDestinationDefaultDisplayNames() {
        XCTAssertEqual(DestinationDefault.askEveryTime.displayName, "Ask Every Time")
        XCTAssertEqual(DestinationDefault.lastUsedFolder.displayName, "Last Used Folder")
        XCTAssertEqual(DestinationDefault.selectedFolder.displayName, "Selected Folder")
    }

    // MARK: - AfterUploadAction

    func testAfterUploadActionDisplayNames() {
        XCTAssertEqual(AfterUploadAction.showSummary.displayName, "Show Summary")
        XCTAssertEqual(AfterUploadAction.openUploadedFolder.displayName, "Open Uploaded Folder")
        XCTAssertEqual(AfterUploadAction.doNothing.displayName, "Do Nothing")
    }

    // MARK: - NotificationPreference

    func testNotificationPreferenceDisplayNames() {
        XCTAssertEqual(NotificationPreference.allComplete.displayName, "When All Uploads Finish")
        XCTAssertEqual(NotificationPreference.errorsOnly.displayName, "Only on Errors")
        XCTAssertEqual(NotificationPreference.perLargeFile.displayName, "Per Large File")
        XCTAssertEqual(NotificationPreference.disabled.displayName, "Disabled")
    }

    // MARK: - AppTheme

    func testAppThemeDisplayNames() {
        XCTAssertEqual(AppTheme.system.displayName, "System")
        XCTAssertEqual(AppTheme.light.displayName, "Light")
        XCTAssertEqual(AppTheme.dark.displayName, "Dark")
    }

    func testAppThemeAllCases() {
        XCTAssertEqual(AppTheme.allCases.count, 3)
    }

    // MARK: - Save/Load Roundtrip

    func testSaveAndLoadRoundtrip() {
        let settings = AppSettings.shared

        settings.launchAtLogin = true
        settings.showMenuBarIcon = false
        settings.showDockIcon = false
        settings.theme = .dark
        settings.defaultUploadMode = .fast
        settings.defaultDuplicateMode = .replaceExisting
        settings.ignoreHiddenFiles = false
        settings.maxParallelUploads = 6
        settings.maxRetryCount = 10
        settings.notificationPreference = .errorsOnly

        settings.save()
        settings.load()

        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertFalse(settings.showMenuBarIcon)
        XCTAssertFalse(settings.showDockIcon)
        XCTAssertEqual(settings.theme, .dark)
        XCTAssertEqual(settings.defaultUploadMode, .fast)
        XCTAssertEqual(settings.defaultDuplicateMode, .replaceExisting)
        XCTAssertFalse(settings.ignoreHiddenFiles)
        XCTAssertEqual(settings.maxParallelUploads, 6)
        XCTAssertEqual(settings.maxRetryCount, 10)
        XCTAssertEqual(settings.notificationPreference, .errorsOnly)
    }

    // MARK: - Default Values

    func testDefaultValues() {
        // Reset UserDefaults to test defaults
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("settings.") {
                defaults.removeObject(forKey: key)
            }
        }

        let settings = AppSettings.shared
        settings.load()

        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertTrue(settings.showMenuBarIcon)
        XCTAssertTrue(settings.showDockIcon)
        XCTAssertEqual(settings.theme, .system)
        XCTAssertTrue(settings.confirmQuitWithActiveUploads)
        XCTAssertEqual(settings.defaultUploadMode, .balanced)
        XCTAssertEqual(settings.defaultDuplicateMode, .keepBoth)
        XCTAssertTrue(settings.ignoreHiddenFiles)
        XCTAssertTrue(settings.ignoreDSStore)
        XCTAssertTrue(settings.preserveFolderStructure)
        XCTAssertTrue(settings.autoRetryFailed)
        XCTAssertEqual(settings.maxParallelUploads, 3)
        XCTAssertEqual(settings.bandwidthLimitKBps, 0)
        XCTAssertEqual(settings.notificationPreference, .allComplete)
        XCTAssertEqual(settings.maxRetryCount, 5)
        XCTAssertFalse(settings.debugLogsEnabled)
    }
}
