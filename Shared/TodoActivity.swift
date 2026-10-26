import ActivityKit
import Foundation

/// The Lock Screen card (a Live Activity). Apple ends one after 8 hours, so it can be renewed: a new card replaces
/// the old one and the 8 hours start again.
struct TodoActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// The first few items, unticked first (the card has room for about 4).
        var items: [TodoItem]
        var left: Int
    }

    var listName: String
    var startedAt: Date
}
