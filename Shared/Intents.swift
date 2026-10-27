import AppIntents
import Foundation

// The tick boxes on the Lock Screen card and the Dynamic Island are Live Activity intents, so iOS runs them inside
// the app (in the background, without opening it), where the lists, the card and the widgets can all be updated
// together. The widget extension only needs them to draw the buttons.
//
// The Home Screen and Lock Screen widgets' tick boxes are a plain intent that iOS runs in the widget itself, which is
// already running: going through the app as well made the widget ignore taps for seconds after each one.

struct WidgetToggleIntent: AppIntent {
    static var title: LocalizedStringResource = "Tick a to-do on a widget"
    static var isDiscoverable = false

    @Parameter(title: "List") var listID: String
    @Parameter(title: "Item") var itemID: String

    init() {}

    init(listID: String, itemID: String) {
        self.listID = listID
        self.itemID = itemID
    }

    func perform() async throws -> some IntentResult {
        // iOS redraws the widget when this returns; the card is updated too if iOS lets the widget see it.
        let data = TodoStore.toggle(listID: listID, itemID: itemID)
        await CardContent.updateCards(with: data)
        return .result()
    }
}

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
