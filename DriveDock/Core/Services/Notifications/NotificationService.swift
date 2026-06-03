import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {
        requestPermission()
    }

    func requestPermission() {
        Task {
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        }
    }

    func sendBatchCompleteNotification(completedCount: Int, failedCount: Int) {
        let settings = AppSettings.shared
        guard settings.notificationPreference != .disabled else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default

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

        let request = UNNotificationRequest(
            identifier: "batch-complete-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendUploadFailedNotification(fileName: String, reason: String) {
        let settings = AppSettings.shared
        guard settings.notifyOnErrors else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upload Failed"
        content.body = "\(fileName): \(reason)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "upload-failed-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendAccountReconnectNotification(accountEmail: String) {
        let content = UNMutableNotificationContent()
        content.title = "Account Needs Reconnection"
        content.body = "Please reconnect \(accountEmail) to continue uploading."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "account-reconnect-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendNetworkLostNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Connection Lost"
        content.body = "Uploads are paused. DriveDock will resume when your connection returns."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "network-lost-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
