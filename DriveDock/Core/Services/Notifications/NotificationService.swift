import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private let lock = NSLock()
    private var _permissionGranted = false
    private var _permissionChecked = false

    var permissionGranted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _permissionGranted
    }

    var permissionChecked: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _permissionChecked
    }

    private init() {
        registerNotificationCategories()
        requestPermission()
    }

    func requestPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                self.updatePermission(granted: granted)
            } catch {
                self.updatePermission(granted: false)
            }
        }
    }

    func checkPermissionStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
        updatePermission(granted: authorized)
        return authorized
    }

    private func updatePermission(granted: Bool) {
        lock.lock()
        _permissionGranted = granted
        _permissionChecked = true
        lock.unlock()
    }

    func isDoNotDisturbActive() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if #available(macOS 14.0, *) {
            return settings.notificationCenterSetting == .disabled
        }
        return false
    }

    private func registerNotificationCategories() {
        let retryAction = UNNotificationAction(
            identifier: "RETRY_ACTION",
            title: "Retry",
            options: .foreground
        )
        let openInDriveAction = UNNotificationAction(
            identifier: "OPEN_IN_DRIVE_ACTION",
            title: "Open in Drive",
            options: .foreground
        )

        let uploadFailedCategory = UNNotificationCategory(
            identifier: "UPLOAD_FAILED",
            actions: [retryAction, openInDriveAction],
            intentIdentifiers: [],
            options: []
        )

        let batchCompleteCategory = UNNotificationCategory(
            identifier: "BATCH_COMPLETE",
            actions: [openInDriveAction],
            intentIdentifiers: [],
            options: []
        )

        let accountReconnectCategory = UNNotificationCategory(
            identifier: "ACCOUNT_RECONNECT",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([uploadFailedCategory, batchCompleteCategory, accountReconnectCategory])
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) -> (action: String, userInfo: [String: Any])? {
        let actionID = response.actionIdentifier
        guard actionID != UNNotificationDefaultActionIdentifier else { return nil }
        return (action: actionID, userInfo: response.notification.request.content.userInfo as? [String: Any] ?? [:])
    }

    func sendBatchCompleteNotification(completedCount: Int, failedCount: Int, batchID: String? = nil) {
        let settings = AppSettings.shared
        guard settings.notificationPreference != .disabled else { return }
        guard permissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = "BATCH_COMPLETE"

        if let batchID {
            content.threadIdentifier = "batch-\(batchID)"
        }

        if failedCount == 0 {
            content.title = "Upload Complete"
            content.body = completedCount == 1
                ? "Your file has been uploaded successfully."
                : "All \(completedCount) files have been uploaded successfully."
        } else if completedCount > 0 {
            content.title = "Upload Partially Complete"
            content.body = "\(completedCount) files uploaded. \(failedCount) files need attention."
        } else {
            content.title = "Upload Failed"
            content.body = "\(failedCount) files failed to upload."
        }

        let identifier = batchID.map { "batch-complete-\($0)" } ?? "batch-complete-\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.handleNotificationError(error)
            }
        }
    }

    func sendUploadFailedNotification(fileName: String, reason: String, batchID: String? = nil, driveFileLink: String? = nil) {
        let settings = AppSettings.shared
        guard settings.notifyOnErrors else { return }
        guard permissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upload Failed"
        content.body = "\(fileName): \(reason)"
        content.sound = .default
        content.categoryIdentifier = "UPLOAD_FAILED"

        if let batchID {
            content.threadIdentifier = "batch-\(batchID)"
        }

        var userInfo: [String: Any] = [:]
        if let driveFileLink {
            userInfo["driveFileLink"] = driveFileLink
        }
        userInfo["fileName"] = fileName
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: "upload-failed-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.handleNotificationError(error)
            }
        }
    }

    func sendAccountReconnectNotification(accountEmail: String) {
        guard permissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Account Needs Reconnection"
        content.body = "Please reconnect \(accountEmail) to continue uploading."
        content.sound = .default
        content.categoryIdentifier = "ACCOUNT_RECONNECT"

        let request = UNNotificationRequest(
            identifier: "account-reconnect-\(accountEmail)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.handleNotificationError(error)
            }
        }
    }

    func sendNetworkLostNotification() {
        guard permissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Connection Lost"
        content.body = "Uploads are paused. DriveDock will resume when your connection returns."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "network-lost-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.handleNotificationError(error)
            }
        }
    }

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func clearNotificationsForBatch(_ batchID: String) {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let identifiers = notifications
                .filter { $0.request.content.threadIdentifier == "batch-\(batchID)" }
                .map { $0.request.identifier }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    func handleNotificationError(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == UNErrorDomain {
            switch nsError.code {
            case UNError.notificationsNotAllowed.rawValue:
                lock.lock()
                _permissionGranted = false
                lock.unlock()
            default:
                break
            }
        }
    }

    // MARK: - Download Notifications

    func sendDownloadBatchCompleteNotification(completedCount: Int, failedCount: Int) {
        let settings = AppSettings.shared
        guard settings.notificationPreference != .disabled else { return }
        guard permissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default

        if failedCount == 0 {
            content.title = "Download Complete"
            content.body = completedCount == 1
                ? "Your file has been downloaded."
                : "All \(completedCount) files have been downloaded."
        } else if completedCount > 0 {
            content.title = "Download Partially Complete"
            content.body = "\(completedCount) files downloaded. \(failedCount) files need attention."
        } else {
            content.title = "Download Failed"
            content.body = "\(failedCount) files failed to download."
        }

        let request = UNNotificationRequest(
            identifier: "download-batch-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.handleNotificationError(error)
            }
        }
    }

    func sendDownloadFailedNotification(fileName: String, reason: String) {
        let settings = AppSettings.shared
        guard settings.notifyOnErrors else { return }
        guard permissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Download Failed"
        content.body = "\(fileName): \(reason)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "download-failed-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.handleNotificationError(error)
            }
        }
    }
}
