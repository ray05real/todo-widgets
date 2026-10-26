import SwiftUI
import WidgetKit

struct TodoEntry: TimelineEntry {
    let date: Date
    let data: TodoData

    /// The top list in your order (drag to reorder in the app), like the Lock Screen card.
    var list: TodoList? { data.current(at: date) }
}

struct TodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: .now, data: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        completion(TodoEntry(date: .now, data: context.isPreview ? .sample : TodoStore.loadData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        // One entry now and one for each moment a list starts or ends, so the widget switches lists on time.
        // Otherwise the app reloads the widgets whenever something changes.
        let data = TodoStore.loadData()
        let now = Date.now
        let dates = [now] + data.changes(after: now).prefix(20)
        let entries = dates.map { TodoEntry(date: $0, data: data) }
        completion(Timeline(entries: entries, policy: .never))
    }
}

/// The Home Screen widget (small, medium, large) and the small Lock Screen widget under the clock. A plain widget
/// with no settings: the "choose a list" kind (AppIntentConfiguration) stayed a grey skeleton on the sideloaded app,
/// even in the Add Widget preview. A new kind name, so iOS forgets the old one.
struct TodoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodoListWidget", provider: TodoProvider()) { entry in
            TodoWidgetView(entry: entry)
        }
        .configurationDisplayName("To-do")
        .description("Tick things off without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct TodoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodoEntry

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                LockScreenWidget(entry: entry)
            } else {
                HomeScreenWidget(entry: entry)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct HomeScreenWidget: View {
    let entry: TodoEntry
    private let headerHeight = 26.0

    var body: some View {
        let look = entry.data.settings.text
        let rowHeight = { (item: TodoItem) in look.applied(to: item).row }
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                if let list = entry.list {
                    let narrow = geo.size.width < 200
                    let columns = narrow ? 1 : entry.data.settings.widgetColumns
                    let height = Double(geo.size.height) - headerHeight
                    let window = list.window(height: height, columns: columns, rowHeight: rowHeight)
                    header(list, window: window, narrow: narrow)
                    if list.items.isEmpty {
                        Text("Nothing on this list yet")
                            .font(look.swiftUIFont)
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(Array(window.items.inColumns(columns, height: height, rowHeight: rowHeight).enumerated()), id: \.offset) { _, column in
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(column) { item in
                                    let itemLook = look.applied(to: item)
                                    Toggle(isOn: item.done, intent: ToggleItemIntent(listID: list.id, itemID: item.id, source: "Home Screen widget")) {
                                        Text(item.title)
                                    }
                                    .toggleStyle(CheckToggleStyle(look: itemLook, color: item.color))
                                    .frame(height: itemLook.row)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else if TodoStore.method == .local {
                    // The widget can't reach the app's list: the signing certificate didn't allow the two to share
                    // a place to keep it (no App Group or shared keychain).
                    Text("Can't see your list")
                        .font(.system(size: 16, weight: .semibold))
                    Text("The signing certificate doesn't let widgets share the app's list.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("No list right now")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Tap to make one")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottomTrailing) {
            // Centred on a row's line at the bottom, inside the same margins as the to-dos.
            if let end = entry.list?.end, entry.data.settings.showCountdown {
                Countdown(end: end)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .frame(maxWidth: 140, alignment: .trailing)
                    .frame(height: entry.data.settings.text.row)
                    .padding(.trailing, 14)
                    .padding(.bottom, 12)
            }
        }
    }

    /// "TO DO" in its box, and which to-dos are showing when they don't all fit.
    private func header(_ list: TodoList, window: (start: Int, items: ArraySlice<TodoItem>), narrow: Bool) -> some View {
        HStack(spacing: 6) {
            TitleBadge(title: list.headerTitle)
            if list.items.count > window.items.count, !narrow {
                Text("\(window.start + 1)–\(window.start + window.items.count) of \(list.items.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .frame(height: headerHeight, alignment: .top)
    }
}

/// Under the clock: Apple keeps these small and one colour, so they show the next three to-dos in plain text.
struct LockScreenWidget: View {
    let entry: TodoEntry

    var body: some View {
        if let list = entry.list, !list.items.isEmpty {
            let look = TextLook(font: entry.data.settings.text.font, size: 13)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(list.window(height: 3) { _ in 1 }.items) { item in
                    Toggle(isOn: item.done, intent: ToggleItemIntent(listID: list.id, itemID: item.id, source: "Lock Screen widget")) {
                        Text(item.title)
                    }
                    .toggleStyle(CheckToggleStyle(look: look))
                }
            }
        } else {
            Text(entry.list == nil ? "No list right now" : "Nothing on the list yet")
                .font(.system(size: 13))
        }
    }
}
