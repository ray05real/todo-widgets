import SwiftUI
import WidgetKit

struct TodoEntry: TimelineEntry {
    let date: Date
    let data: TodoData
    /// Which running list, in your order: 0 = the top one, 1 = the 2nd, 2 = the 3rd.
    let rank: Int

    var list: TodoList? {
        let running = data.running(at: date)
        return running.indices.contains(rank) ? running[rank] : nil
    }

    var noListText: String {
        ["No list right now", "No 2nd list right now", "No 3rd list right now"][min(rank, 2)]
    }
}

struct TodoProvider: TimelineProvider {
    let rank: Int

    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: .now, data: .sample, rank: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        completion(context.isPreview
            ? TodoEntry(date: .now, data: .sample, rank: 0)
            : TodoEntry(date: .now, data: TodoStore.loadData(), rank: rank))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        // One entry now and one for the next moment a list starts or ends (then iOS asks again), so the widget
        // switches lists on time. Only two: iOS draws every entry after each tap and ignores taps until it's done,
        // and drawing up to 21 at extra-large size held taps up for about 5 seconds.
        let data = TodoStore.loadData()
        let now = Date.now
        let next = data.changes(after: now).first
        var entries = [TodoEntry(date: now, data: data, rank: rank)]
        if let next { entries.append(TodoEntry(date: next, data: data, rank: rank)) }
        completion(Timeline(entries: entries, policy: next == nil ? .never : .atEnd))
    }
}

/// The Home Screen widgets (small, medium, large) and the small Lock Screen widget under the clock: one for the
/// top list and one each for the 2nd and 3rd, in your order. Plain widgets with no settings: the "choose a list"
/// kind (AppIntentConfiguration) stayed a grey skeleton on the sideloaded app, even in the Add Widget preview.
enum TodoWidgetKind {
    static func configuration(kind: String, rank: Int, name: String, description: String) -> some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoProvider(rank: rank)) { entry in
            TodoWidgetView(entry: entry)
        }
        .configurationDisplayName(name)
        .description(description)
        .supportedFamilies(families)
        .contentMarginsDisabled()
    }

    /// The sizes on offer. The tall extra-large one is iPhone's biggest from iOS 27, and only exists when the app is
    /// built with Apple's iOS 27 tools (the workflow sets IOS27_SDK then).
    private static var families: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryRectangular]
        #if IOS27_SDK
        if #available(iOS 27.0, *) {
            families.append(.systemExtraLargePortrait)
        }
        #endif
        return families
    }
}

struct TodoWidget: Widget {
    var body: some WidgetConfiguration {
        TodoWidgetKind.configuration(kind: "TodoListWidget", rank: 0, name: "To-do",
                                     description: "Your top list. Tick things off without opening the app.")
    }
}

struct SecondListWidget: Widget {
    var body: some WidgetConfiguration {
        TodoWidgetKind.configuration(kind: "TodoListWidget2", rank: 1, name: "To-do · 2nd list",
                                     description: "The 2nd list in your order.")
    }
}

struct ThirdListWidget: Widget {
    var body: some WidgetConfiguration {
        TodoWidgetKind.configuration(kind: "TodoListWidget3", rank: 2, name: "To-do · 3rd list",
                                     description: "The 3rd list in your order.")
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
                    // A countdown at the bottom gets its own line under the first or last column.
                    let reserve = timerAtBottom ? CardLayout.timerHeight : 0
                    let first = place == .bottomLeft
                    let window = list.window(height: height, columns: columns, reserve: reserve, reserveFirst: first,
                                             rowHeight: rowHeight)
                    let split = window.items.inColumns(columns, height: height, reserve: reserve, reserveFirst: first,
                                                       rowHeight: rowHeight)
                    header(list, window: window, narrow: narrow)
                    if list.items.isEmpty {
                        Text("Nothing on this list yet")
                            .font(look.swiftUIFont)
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(Array(split.enumerated()), id: \.offset) { _, column in
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(column) { item in
                                    let itemLook = look.applied(to: item)
                                    Toggle(isOn: item.done, intent: WidgetToggleIntent(listID: list.id, itemID: item.id)) {
                                        Text(itemLook.display(item.title))
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
                    Text(entry.noListText)
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
        .overlay(alignment: place == .bottomLeft ? .bottomLeading : .bottomTrailing) {
            // At the bottom: inside the same margins as the to-dos, on the line kept free for it.
            if let end = entry.list?.end, timerAtBottom {
                TimerText(end: end)
                    .frame(height: CardLayout.timerHeight)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
    }

    private var place: TimerPlace { entry.data.settings.card.timerPlace }

    private var timerShown: Bool {
        entry.list?.end != nil && entry.data.settings.showCountdown
    }

    private var timerAtBottom: Bool { timerShown && place != .topRight }

    /// "TO DO" in its box, and which to-dos are showing when they don't all fit.
    private func header(_ list: TodoList, window: (start: Int, items: ArraySlice<TodoItem>), narrow: Bool) -> some View {
        HStack(spacing: 6) {
            TitleBadge(title: list.headerTitle)
            if list.items.count > window.start + window.items.count, !narrow {
                // How many to-dos come after the ones on show (the ones before are all ticked).
                Text("+\(list.items.count - window.start - window.items.count) more")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let end = list.end, timerShown, place == .topRight {
                TimerText(end: end)
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
            let look = TextLook(font: entry.data.settings.text.font, size: 13, letterCase: entry.data.settings.text.letterCase)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(list.window(height: 3) { _ in 1 }.items) { item in
                    Toggle(isOn: item.done, intent: WidgetToggleIntent(listID: list.id, itemID: item.id)) {
                        Text(look.display(item.title))
                    }
                    .toggleStyle(CheckToggleStyle(look: look))
                }
            }
        } else {
            Text(entry.list == nil ? entry.noListText : "Nothing on the list yet")
                .font(.system(size: 13))
        }
    }
}
