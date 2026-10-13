import Foundation
import UserNotifications

enum NotificationService {
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    static func scheduleShotDay(weekday: Int, hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests().map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: ids.filter { $0.hasPrefix("shotday") })

        let content = UNMutableNotificationContent()
        content.title = "It's Shot Day 🎯"
        content.body = "Your pen is pre-filled in ShotJoy. One tap and today is a win."
        content.sound = .default
        content.userInfo = ["openTab": "today"]

        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "shotday-weekly", content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func scheduleRestockReminder(name: String, fireDate: Date) async {
        guard fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Running low on \(name)"
        content.body = "Estimated to run out around this date. Time to reorder."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour], from: fireDate), repeats: false)
        let request = UNNotificationRequest(identifier: "restock-\(name)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests().map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
