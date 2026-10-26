import SwiftUI
import WidgetKit

/// The app's copy of the lists. Every change is saved straight away and passed on to the widgets, the Lock Screen
/// card and the notifications.
@MainActor
final class AppModel: ObservableObject {
    @Published var data = TodoStore.loadData()

    /// Picks up ticks made outside the app.
    func reload() {
        data = TodoStore.loadData()
    }

    func commit() {
        data.prune()
        TodoStore.saveData(data)
        WidgetCenter.shared.reloadAllTimelines()
        Reminders.reschedule(data)
        let snapshot = data
        Task { await LiveCard.sync(snapshot, from: "app") }
    }

    func list(_ id: String) -> TodoList? {
        data.lists.first { $0.id == id }
    }

    func edit(_ id: String, _ change: (inout TodoList) -> Void) {
        guard let i = data.lists.firstIndex(where: { $0.id == id }) else { return }
        change(&data.lists[i])
        commit()
    }

    @discardableResult
    func newList(name: String?, start: Date, end: Date?) -> String {
        let list = TodoList(name: name, start: start, end: end)
        data.lists.append(list)
        commit()
        return list.id
    }

    func deleteList(_ id: String) {
        data.lists.removeAll { $0.id == id }
        commit()
    }

    /// The next daily list, written ahead: it starts when the current one ends (or at the next reset).
    func planNext() -> String {
        let settings = data.settings
        let start = data.current(at: .now)?.end ?? settings.nextReset(after: .now)
        if let existing = data.lists.first(where: { $0.name == nil && abs($0.start.timeIntervalSince(start)) < 60 }) {
            return existing.id
        }
        return newList(name: nil, start: start, end: settings.nextReset(after: start.addingTimeInterval(60)))
    }

    func newListForToday() -> String {
        newList(name: nil, start: .now, end: data.settings.nextReset(after: .now))
    }
}
