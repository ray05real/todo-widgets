import ActivityKit
import Foundation
import WidgetKit

/// Ticks from outside the app's screen (widgets, Lock Screen card, Dynamic Island) land here, inside the app.
enum TodoActions {
    @MainActor static func toggle(_ id: String, from source: String) async {
        let items = TodoStore.toggle(id)
        Log.add("Ticked from the \(source)")
        await LiveCard.update(items)
        WidgetCenter.shared.reloadAllTimelines()
    }

    @MainActor static func renewCard(from source: String) async {
        await LiveCard.restart(TodoStore.load(), from: source)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// The Lock Screen card (Live Activity).
enum LiveCard {
    static let maxItems = 4

    static var isRunning: Bool { !Activity<TodoActivityAttributes>.activities.isEmpty }

    static func state(for items: [TodoItem]) -> TodoActivityAttributes.ContentState {
        let shown = items.openFirst.prefix(maxItems).map { item -> TodoItem in
            var short = item
            short.title = String(item.title.prefix(60))
            return short
        }
        return TodoActivityAttributes.ContentState(items: shown, left: items.leftCount)
    }

    static func start(_ items: [TodoItem], from source: String) {
        do {
            _ = try Activity<TodoActivityAttributes>.request(
                attributes: TodoActivityAttributes(listName: "Today", startedAt: .now),
                content: ActivityContent(state: state(for: items), staleDate: nil),
                pushType: nil
            )
            Log.add("Card started (from the \(source))")
        } catch {
            Log.add("Card didn't start (from the \(source)): \(error)")
        }
    }

    static func update(_ items: [TodoItem]) async {
        for activity in Activity<TodoActivityAttributes>.activities {
            await activity.update(ActivityContent(state: state(for: items), staleDate: nil))
        }
    }

    /// Replaces the card with a new one, so Apple's 8 hours start again.
    static func restart(_ items: [TodoItem], from source: String) async {
        await stop()
        start(items, from: source)
    }

    static func stop() async {
        for activity in Activity<TodoActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

/// A short log of what happened, shown in the app, so ticks from the Lock Screen can be checked.
enum Log {
    static func add(_ text: String) {
        let time = Date.now.formatted(date: .omitted, time: .standard)
        var lines = UserDefaults.standard.stringArray(forKey: "log") ?? []
        lines.insert("\(time)  \(text)", at: 0)
        UserDefaults.standard.set(Array(lines.prefix(30)), forKey: "log")
    }

    static var lines: [String] { UserDefaults.standard.stringArray(forKey: "log") ?? [] }
}
