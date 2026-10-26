import ActivityKit
import Foundation
import WidgetKit

extension Notification.Name {
    /// Posted when a tick from outside the app's screen changed the saved lists.
    static let todoDataChanged = Notification.Name("todoDataChanged")
}

/// Ticks from outside the app's screen (widgets, Lock Screen card, Dynamic Island) land here, inside the app.
enum TodoActions {
    @MainActor static func toggle(listID: String, itemID: String, from source: String) async {
        let data = TodoStore.toggle(listID: listID, itemID: itemID)
        Log.add("Ticked from the \(source)")
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .todoDataChanged, object: nil)
        await LiveCard.sync(data, from: source)
    }

    @MainActor static func renewCard(from source: String) async {
        await LiveCard.sync(TodoStore.loadData(), from: source, forceRenew: true)
    }
}

/// The Lock Screen card (Live Activity).
enum LiveCard {
    /// Apple ends a card 8 hours after it starts, so one older than this is swapped for a new one whenever you tick
    /// something or open the app. That keeps it up as long as you use it at least every 8 hours or so.
    static let renewAfter: TimeInterval = 60 * 60

    static var cards: [Activity<TodoActivityAttributes>] { Activity<TodoActivityAttributes>.activities }

    static var liveCards: [Activity<TodoActivityAttributes>] {
        cards.filter { $0.activityState == .active || $0.activityState == .stale }
    }

    static var isRunning: Bool { !liveCards.isEmpty }

    /// What a card shows: `list`, or "No list right now" when there's none.
    static func state(for list: TodoList?, in data: TodoData, at now: Date = .now) -> TodoActivityAttributes.ContentState {
        let card = data.settings.card
        var look = data.settings.text
        if let size = card.size { look.size = size }
        let countdown = data.settings.showCountdown
        guard let list else {
            return TodoActivityAttributes.ContentState(
                listID: nil, title: "TO DO", end: nil, items: [], first: 0, total: 0, left: 0,
                look: look, card: card, showCountdown: countdown, nextReady: !data.planned(after: now).isEmpty
            )
        }
        let window = list.window(height: CardLayout.rowsHeight, columns: card.columns) { look.applied(to: $0).cardRow }
        let items = window.items.map { (item: TodoItem) -> TodoItem in
            var short = item
            short.title = String(item.title.prefix(60))
            return short
        }
        return TodoActivityAttributes.ContentState(
            listID: list.id, title: list.headerTitle, end: list.end, items: items, first: window.start,
            total: list.items.count, left: list.leftCount, look: look, card: card, showCountdown: countdown,
            nextReady: data.next(after: list) != nil
        )
    }

    /// Brings the cards up to date: one following the top list, or one per list (Settings → Every list). Cards
    /// that are missing or over an hour old are replaced by new ones; cards no longer wanted are taken away.
    static func sync(_ data: TodoData, from source: String, forceRenew: Bool = false) async {
        guard data.settings.keepCard else {
            await stop()
            return
        }
        let now = Date.now
        // nil = the one card that follows the top list (it shows "No list right now" when there's none).
        let wanted: [(id: String?, list: TodoList?)] = data.settings.cardPerList
            ? data.listsOnCards(at: now).map { (id: $0.id, list: $0) }
            : [(id: nil, list: data.current(at: now))]

        for card in cards where !wanted.contains(where: { $0.id == card.attributes.listID }) {
            await card.end(nil, dismissalPolicy: .immediate)
        }
        for (id, list) in wanted {
            let content = ActivityContent(state: state(for: list, in: data, at: now), staleDate: list?.end)
            let mine = liveCards.filter { $0.attributes.listID == id }
            if let card = mine.first, !forceRenew, now.timeIntervalSince(card.attributes.startedAt) < renewAfter {
                await card.update(content)
                continue
            }
            for card in cards where card.attributes.listID == id {
                await card.end(nil, dismissalPolicy: .immediate)
            }
            do {
                _ = try Activity<TodoActivityAttributes>.request(
                    attributes: TodoActivityAttributes(startedAt: now, listID: id), content: content, pushType: nil
                )
                Log.add("Card \(mine.isEmpty ? "started" : "renewed") (from the \(source))")
            } catch {
                Log.add("Card didn't start (from the \(source)): \(error)")
            }
        }
    }

    static func stop() async {
        for card in cards {
            await card.end(nil, dismissalPolicy: .immediate)
        }
    }
}

/// A short log of what happened, shown in Settings, so ticks from the Lock Screen can be checked.
enum Log {
    static func add(_ text: String) {
        let time = Date.now.formatted(date: .omitted, time: .standard)
        var lines = UserDefaults.standard.stringArray(forKey: "log") ?? []
        lines.insert("\(time)  \(text)", at: 0)
        UserDefaults.standard.set(Array(lines.prefix(30)), forKey: "log")
    }

    static var lines: [String] { UserDefaults.standard.stringArray(forKey: "log") ?? [] }
}
