import ActivityKit
import Foundation

/// The Lock Screen card (a Live Activity). Apple ends one 8 hours after it starts, so the app replaces it with a
/// new one whenever you tick something or open the app (see LiveCard).
struct TodoActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Nil when no list is running.
        var listID: String?
        var title: String
        var end: Date?
        /// The block of to-dos on show (see TodoList.window).
        var items: [TodoItem]
        var first: Int
        var total: Int
        var left: Int
        /// The font and size of to-dos without their own.
        var look: TextLook
        var card: CardSettings
        /// Whether a planned list takes over when this one ends.
        var nextReady: Bool
    }

    var startedAt: Date
}
