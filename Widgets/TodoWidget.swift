import SwiftUI
import WidgetKit

struct TodoEntry: TimelineEntry {
    let date: Date
    let items: [TodoItem]
    let method: TodoStore.Method
}

struct TodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: .now, items: TodoItem.samples, method: .local)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        // No timer: the app reloads the widgets whenever the list changes.
        completion(Timeline(entries: [entry()], policy: .never))
    }

    private func entry() -> TodoEntry {
        TodoEntry(date: .now, items: TodoStore.load(), method: TodoStore.method)
    }
}

/// The Home Screen widget (small, medium, large) and the small Lock Screen widget under the clock.
struct TodoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodoWidget", provider: TodoProvider()) { entry in
            TodoWidgetView(entry: entry)
        }
        .configurationDisplayName("To-do")
        .description("Tick things off without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct TodoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodoEntry

    private var onLockScreen: Bool { family == .accessoryRectangular }

    private var maxRows: Int {
        switch family {
        case .accessoryRectangular: return 3
        case .systemSmall, .systemMedium: return 4
        default: return 10
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: onLockScreen ? 1 : 6) {
            if !onLockScreen {
                HStack {
                    Text("Today").font(.headline)
                    Spacer()
                    Text("\(entry.items.leftCount) left").font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(entry.items.openFirst.prefix(maxRows)) { item in
                Toggle(isOn: item.done, intent: ToggleItemIntent(itemID: item.id, source: onLockScreen ? "Lock Screen widget" : "Home Screen widget")) {
                    Text(item.title).lineLimit(1)
                }
                .toggleStyle(CheckToggleStyle(compact: onLockScreen || family == .systemSmall))
            }
            Spacer(minLength: 0)
            if !onLockScreen {
                Text("Kept in: \(entry.method.rawValue)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
