import Foundation
import UserNotifications

enum ReminderSchedulerError: Error {
    case notAuthorized
}

struct ReminderScheduler {
    static let reminderId = "idlefolder.biweekly.reminder"

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleBiweeklyReminder() async throws {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            throw ReminderSchedulerError.notAuthorized
        }

        let content = UNMutableNotificationContent()
        content.title = "IdleFolder 정리 리마인더"
        content.body = "2주가 지났습니다. Idle 앱 폴더를 다시 정리해보세요."
        content.sound = .default

        let twoWeeks: TimeInterval = 14 * 24 * 60 * 60
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: twoWeeks, repeats: true)
        let request = UNNotificationRequest(identifier: Self.reminderId, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderId])
        try await center.add(request)
    }

    func cancelReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderId])
    }
}
