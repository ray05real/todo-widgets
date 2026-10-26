import SwiftUI
import WidgetKit

// Two small widgets for finding out why the Home Screen widget stays grey (26 Oct 2026): A shows fixed text only,
// B also reads the list. If A works and B doesn't, reading the list is what fails. Remove once it's fixed.

struct TestEntry: TimelineEntry {
    let date: Date
    let text: String
}

struct TestProviderA: TimelineProvider {
    func placeholder(in context: Context) -> TestEntry { TestEntry(date: .now, text: "…") }
    func getSnapshot(in context: Context, completion: @escaping (TestEntry) -> Void) {
        completion(TestEntry(date: .now, text: "Widget works"))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TestEntry>) -> Void) {
        completion(Timeline(entries: [TestEntry(date: .now, text: "Widget works")], policy: .never))
    }
}

struct TestProviderB: TimelineProvider {
    func placeholder(in context: Context) -> TestEntry { TestEntry(date: .now, text: "…") }
    func getSnapshot(in context: Context, completion: @escaping (TestEntry) -> Void) {
        completion(entry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TestEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .never))
    }
    private func entry() -> TestEntry {
        let data = TodoStore.loadData()
        let text = """
        Kept in: \(TodoStore.method.rawValue)
        Lists: \(data.lists.count)
        Groups: \(Signing.appGroups.count)
        Keychain: \(Signing.keychainGroups.first ?? "none")
        """
        return TestEntry(date: .now, text: text)
    }
}

struct TestWidgetView: View {
    let title: String
    let entry: TestEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12, weight: .bold))
            Text(entry.text).font(.system(size: 10))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct TestWidgetA: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TestWidgetA", provider: TestProviderA()) { entry in
            TestWidgetView(title: "Test A", entry: entry)
        }
        .configurationDisplayName("Test A")
        .description("For finding the widget fault.")
        .supportedFamilies([.systemSmall])
    }
}

struct TestWidgetB: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TestWidgetB", provider: TestProviderB()) { entry in
            TestWidgetView(title: "Test B", entry: entry)
        }
        .configurationDisplayName("Test B")
        .description("For finding the widget fault.")
        .supportedFamilies([.systemSmall])
    }
}
