import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    static func requestAndSchedule(at components: DateComponents) async {
        let center = UNUserNotificationCenter.current()
        guard let granted = try? await center.requestAuthorization(options: [.alert, .sound]),
              granted else { return }

        center.removePendingNotificationRequests(withIdentifiers: ["daily-practice"])

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.title")
        content.body = String(localized: "notification.body")
        content.sound = .default
        content.interruptionLevel = .passive   // pas d'urgence artificielle

        let request = UNNotificationRequest(
            identifier: "daily-practice",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
        try? await center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["daily-practice"])
    }
}