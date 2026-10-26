import SwiftUI
import WidgetKit

struct TodoEntry: TimelineEntry {
    let date: Date
    let data: TodoData
    let listName: String?

    var list: TodoList? { data.list(named: listName, at: date) }
}

struct TodoProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: .now, data: .sample, listName: nil)
    }

    func snapshot(for configuration: SelectListIntent, in context: Context) async -> TodoEntry {
        TodoEntry(date: .now, data: context.isPreview ? .sample : TodoStore.loadData(), listName: configuration.listName)
    }

    func timeline(for configuration: SelectListIntent, in context: Context) async -> Timeline<TodoEntry> {
        // One entry now and one for each moment a list starts or ends, so the widget switches lists on time.
        // Otherwise the app reloads the widgets whenever something changes.
        let data = TodoStore.loadData()
        let now = Date.now
        let dates = [now] + data.changes(after: now).prefix(20)
        let entries = dates.map { TodoEntry(date: $0, data: data, listName: configuration.listName) }
        return Timeline(entries: entries, policy: .never)
    }
}

/// The Home Screen widget (small, medium, large) and the small Lock Screen widget under the clock.
struct TodoWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TodoWidget", intent: SelectListIntent.self, provider: TodoProvider()) { entry in
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
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                if let list = entry.list {
                    let window = list.window(height: Double(geo.size.height) - headerHeight) { look.applied(to: $0).row }
                    header(list, window: window, narrow: geo.size.width < 200)
                    if list.items.isEmpty {
                        Text("Nothing on this list yet")
                            .font(look.swiftUIFont)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(window.items) { item in
                        let itemLook = look.applied(to: item)
                        Toggle(isOn: item.done, intent: ToggleItemIntent(listID: list.id, itemID: item.id, source: "Home Screen widget")) {
                            Text(item.title)
                        }
                        .toggleStyle(CheckToggleStyle(look: itemLook, color: item.color))
                        .frame(height: itemLook.row)
                    }
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
    }

    /// The list's name on the left; on the right a countdown to when it ends (the hourglass).
    private func header(_ list: TodoList, window: (start: Int, items: ArraySlice<TodoItem>), narrow: Bool) -> some View {
        HStack(spacing: 4) {
            Text(list.displayName(at: entry.date))
                .font(.system(size: 15, weight: .bold))
            if list.items.count > window.items.count, !narrow {
                Text("\(window.start + 1)–\(window.start + window.items.count) of \(list.items.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if let end = list.end {
                Image(systemName: "hourglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                if narrow {
                    Text(end, format: .dateTime.hour().minute())
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text(end, style: .relative)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100, alignment: .trailing)
                }
            }
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
