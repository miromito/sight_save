import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private(set) var authorizationGranted = false

    func configure() async {
        center.delegate = self
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorizationGranted = true
        case .notDetermined:
            do {
                authorizationGranted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                authorizationGranted = false
            }
        default:
            authorizationGranted = false
        }
    }

    func post(title: String, body: String, sound: Bool) {
        guard authorizationGranted else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if sound {
            content.sound = .default
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request, withCompletionHandler: { _ in })
    }

    // Called by UserNotifications off the main actor.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
