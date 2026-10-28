import Foundation
import UserNotifications

/// The notifications: one when a list ends (make the next one, or the planned one has started), and an optional
/// daily nudge to plan ahead. They're made on the phone, so no server or push permission is needed.
enum Reminders {
    static func ask() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted { reschedule(TodoStore.loadData()) }
        }
    }

    static func reschedule(_ data: TodoData) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let now = Date.now
        for list in data.lists {
            guard let end = list.end, end > now else { continue }
            let content = UNMutableNotificationContent()
            // With "Carry over unfinished to-dos" on, the next list may be made (or filled) only when this one ends.
            var then = data
            then.carryOver(at: end)
            if let next = then.next(after: list) {
                content.title = "Your next list has started"
                content.body = next.items.isEmpty
                    ? "It's empty so far. Tap to fill it in."
                    : "\(next.items.count) to-dos are ready."
            } else {
                content.title = "Time for a new list"
                content.body = "\(list.displayName(at: end.addingTimeInterval(-60))) has ended. Tap to make the next one."
            }
            content.sound = .default
            let time = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: end)
            add(center, id: "end-\(list.id)", content: content, at: time, repeats: false)
        }
        if data.settings.planReminder {
            let content = UNMutableNotificationContent()
            content.title = "Plan your next list"
            content.body = "Write it now and it'll be ready when the new day starts."
            content.sound = .default
            let minutes = data.settings.planMinutes
            add(center, id: "plan", content: content, at: DateComponents(hour: minutes / 60, minute: minutes % 60), repeats: true)
        }
    }

    private static func add(_ center: UNUserNotificationCenter, id: String, content: UNNotificationContent,
                            at time: DateComponents, repeats: Bool) {
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: repeats)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
