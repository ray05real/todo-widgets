import Foundation

struct TodoItem: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var done: Bool

    init(id: String = UUID().uuidString, title: String, done: Bool = false) {
        self.id = id
        self.title = title
        self.done = done
    }

    /// The test list's starting items. Fixed ids, so the app and the widgets agree on them even when they can't
    /// share the list.
    static let samples: [TodoItem] = [
        TodoItem(id: "s1", title: "Tick me on the Home Screen widget"),
        TodoItem(id: "s2", title: "Tick me on the Lock Screen card"),
        TodoItem(id: "s3", title: "Tick me in the Dynamic Island"),
        TodoItem(id: "s4", title: "Tick me in the app"),
    ]
}

extension Array where Element == TodoItem {
    /// Unticked first, then ticked, each kept in the order they were added.
    var openFirst: [TodoItem] { filter { !$0.done } + filter { $0.done } }

    var leftCount: Int { filter { !$0.done }.count }
}
