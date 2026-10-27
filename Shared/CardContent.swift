import ActivityKit
import Foundation

/// What the Lock Screen cards show, worked out from the lists. Shared, so both the app and the widgets (when a
/// widget tick is handled by the widget itself) can bring the cards up to date.
enum CardContent {
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

    /// Updates the cards that are up with `data` (no starting or swapping cards: only the app does that). From the
    /// widget this may find no cards, if iOS only lets the app itself see them; the app then catches the card up the
    /// next time it runs.
    static func updateCards(with data: TodoData) async {
        let now = Date.now
        for card in Activity<TodoActivityAttributes>.activities
        where card.activityState == .active || card.activityState == .stale {
            let list: TodoList?
            if let id = card.attributes.listID {
                list = data.lists.first { $0.id == id }
            } else {
                list = data.current(at: now)
            }
            await card.update(ActivityContent(state: state(for: list, in: data, at: now), staleDate: list?.end))
        }
    }
}
