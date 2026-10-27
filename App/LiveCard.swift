import ActivityKit
import Foundation
import WidgetKit

extension Notification.Name {
    /// Posted when a tick from outside the app's screen changed the saved lists.
    static let todoDataChanged = Notification.Name("todoDataChanged")
}

/// Ticks from outside the app's screen (widgets, Lock Screen card, Dynamic Island) land here, inside the app.
enum TodoActions {
    /// Kept as quick as possible: iOS ignores further taps on a widget until this returns (the owner's taps after the
    /// first kept getting lost). So it only saves the tick and returns:
    /// - a tap on a widget doesn't reload the widgets itself, because iOS reloads the tapped one when this returns
    ///   (reloading them all as well made it reload twice); a tap on the card or the Dynamic Island does, so the
    ///   widgets catch up;
    /// - the cards are updated just after, without making the tap wait (and a card is only swapped for a fresh one,
    ///   which is slow, when it's nearly at Apple's 8 hours).
    @MainActor static func toggle(listID: String, itemID: String, from source: String) async {
        let data = TodoStore.toggle(listID: listID, itemID: itemID)
        if !source.hasSuffix("widget") {
            WidgetCenter.shared.reloadAllTimelines()
        }
        NotificationCenter.default.post(name: .todoDataChanged, object: nil)
        Task { await LiveCard.sync(data, from: source, renewAfter: LiveCard.renewAfterTick) }
    }

    @MainActor static func renewCard(from source: String) async {
        await LiveCard.sync(TodoStore.loadData(), from: source, forceRenew: true)
    }
}

/// The Lock Screen card (Live Activity).
enum LiveCard {
    /// Apple ends a card 8 hours after it starts, so one older than this is swapped for a new one when you open the
    /// app, and one older than `renewAfterTick` when you tick something. That keeps it up as long as you use it at
    /// least every 8 hours or so.
    static let renewAfter: TimeInterval = 60 * 60
    static let renewAfterTick: TimeInterval = 6 * 60 * 60

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
        // A countdown at the bottom gets its own line under a column (one to-do fewer there); at the top it shares
        // the title line.
        let atBottom = countdown && list.end != nil && card.timerPlace != .topRight
        let window = list.window(height: CardLayout.rowsHeight, columns: card.columns,
                                 reserve: atBottom ? CardLayout.timerHeight : 0,
                                 reserveFirst: card.timerPlace == .bottomLeft) {
            look.applied(to: $0).cardRow
        }
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
    static func sync(_ data: TodoData, from source: String, forceRenew: Bool = false,
                     renewAfter: TimeInterval = LiveCard.renewAfter) async {
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
