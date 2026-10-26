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

    /// Adds a list at the bottom of the order (so it doesn't take over the card), or right after `anchorID`.
    @discardableResult
    func newList(name: String?, start: Date, end: Date?, after anchorID: String? = nil) -> String {
        let list = TodoList(name: name, start: start, end: end)
        if let anchorID, let i = data.lists.firstIndex(where: { $0.id == anchorID }) {
            data.lists.insert(list, at: i + 1)
        } else {
            data.lists.append(list)
        }
        commit()
        return list.id
    }

    func deleteList(_ id: String) {
        data.lists.removeAll { $0.id == id }
        commit()
    }

    /// Reorders the running lists (the top one shows on the card), leaving the others where they are.
    func moveRunning(from source: IndexSet, to destination: Int, at now: Date) {
        var ids = data.running(at: now).map { $0.id }
        ids.move(fromOffsets: source, toOffset: destination)
        let slots = data.lists.indices.filter { ids.contains(data.lists[$0].id) }
        let byID = Dictionary(uniqueKeysWithValues: data.lists.map { ($0.id, $0) })
        for (slot, id) in zip(slots, ids) {
            if let list = byID[id] { data.lists[slot] = list }
        }
        commit()
    }

    /// The next daily list, written ahead: it starts when the current one ends (or at the next reset), and sits
    /// right after it in the order, so it takes the current one's place on the card.
    func planNext() -> String {
        let settings = data.settings
        let current = data.current(at: .now)
        let start = current?.end ?? settings.nextReset(after: .now)
        if let existing = data.lists.first(where: { $0.name == nil && abs($0.start.timeIntervalSince(start)) < 60 }) {
            return existing.id
        }
        return newList(name: nil, start: start, end: settings.nextReset(after: start.addingTimeInterval(60)), after: current?.id)
    }

    func newListForToday() -> String {
        newList(name: nil, start: .now, end: data.settings.nextReset(after: .now))
    }
}
