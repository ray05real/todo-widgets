import AppIntents
import WidgetKit

/// The names of your named lists, offered when you edit a widget.
struct ListChoices: DynamicOptionsProvider {
    func results() async throws -> [String] {
        TodoStore.loadData().customNames
    }
}

/// A widget's setting (press and hold it, Edit Widget): which list it shows. Empty = the current daily list.
struct SelectListIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose a list"
    static var description = IntentDescription("Leave it empty to show the current list.")

    @Parameter(title: "List", optionsProvider: ListChoices())
    var listName: String?

    init() {}
}
