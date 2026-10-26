import AppIntents
import Foundation

// The tick boxes on the widgets, the Lock Screen card and the Dynamic Island. Both are Live Activity intents, so
// iOS runs them inside the app (in the background, without opening it), where the lists, the card and the widgets
// can all be updated together. The widget extension only needs them to draw the buttons.

struct ToggleItemIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Tick a to-do"

    @Parameter(title: "List") var listID: String
    @Parameter(title: "Item") var itemID: String
    @Parameter(title: "From") var source: String

    init() {}

    init(listID: String, itemID: String, source: String) {
        self.listID = listID
        self.itemID = itemID
        self.source = source
    }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await TodoActions.toggle(listID: listID, itemID: itemID, from: source)
        #endif
        return .result()
    }
}

struct RenewCardIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Renew the Lock Screen card"

    init() {}

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await TodoActions.renewCard(from: "Lock Screen card")
        #endif
        return .result()
    }
}
