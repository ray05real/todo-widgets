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
        var showCountdown: Bool
        /// Whether a planned list takes over when this one ends.
        var nextReady: Bool
        /// Settings → Clear button: shown once something on show is ticked.
        var showClear = false
        /// Every to-do on the list is ticked: the card asks "All done?" (yes takes the card away).
        var allDone = false
    }

    var startedAt: Date
    /// The list this card belongs to when every list has its own card; nil for the one card that follows the top
    /// list (and for cards started before lists had their own).
    var listID: String?
}

extension TodoActivityAttributes.ContentState {
    /// Cards already up from an older version (without the newer fields) still show (in an extension, so the
    /// memberwise init stays).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        listID = try c.decodeIfPresent(String.self, forKey: .listID)
        title = try c.decode(String.self, forKey: .title)
        end = try c.decodeIfPresent(Date.self, forKey: .end)
        items = try c.decode([TodoItem].self, forKey: .items)
        first = try c.decode(Int.self, forKey: .first)
        total = try c.decode(Int.self, forKey: .total)
        left = try c.decode(Int.self, forKey: .left)
        look = try c.decode(TextLook.self, forKey: .look)
        card = try c.decode(CardSettings.self, forKey: .card)
        showCountdown = try c.decode(Bool.self, forKey: .showCountdown)
        nextReady = try c.decode(Bool.self, forKey: .nextReady)
        showClear = try c.decodeIfPresent(Bool.self, forKey: .showClear) ?? false
        allDone = try c.decodeIfPresent(Bool.self, forKey: .allDone) ?? false
    }
}
