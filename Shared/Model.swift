import Foundation

/// One to-do.
struct TodoItem: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var done: Bool
    /// Its colour, an index into `Palette.colors` (0 = the normal text colour).
    var color: Int
    /// Its own font and size, if it doesn't use the list's (Settings).
    var font: FontChoice?
    var size: Double?

    init(id: String = UUID().uuidString, title: String, done: Bool = false, color: Int = 0,
         font: FontChoice? = nil, size: Double? = nil) {
        self.id = id
        self.title = title
        self.done = done
        self.color = color
        self.font = font
        self.size = size
    }

    init(from decoder: Decoder) throws {
        // The first test version had no colours, fonts or sizes.
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        color = try c.decodeIfPresent(Int.self, forKey: .color) ?? 0
        font = try? c.decodeIfPresent(FontChoice.self, forKey: .font)
        size = try c.decodeIfPresent(Double.self, forKey: .size)
    }

    /// For the widget gallery's preview.
    static let samples: [TodoItem] = [
        TodoItem(id: "s1", title: "Go for a run", color: 4),
        TodoItem(id: "s2", title: "Answer emails", done: true),
        TodoItem(id: "s3", title: "Buy groceries", color: 2),
        TodoItem(id: "s4", title: "Read 20 pages", color: 7),
    ]
}

/// A font and a size.
struct TextLook: Codable, Hashable {
    var font: FontChoice = .system
    var size: Double = 17

    /// This look with a to-do's own font and size, where it has them.
    func applied(to item: TodoItem) -> TextLook {
        TextLook(font: item.font ?? font, size: item.size ?? size)
    }
}

/// A list that runs from `start` to `end` (no end for lists like Shopping).
struct TodoList: Codable, Hashable, Identifiable {
    var id = UUID().uuidString
    /// Empty for the daily lists, which are called Today / Tomorrow / a weekday.
    var name: String?
    var start: Date
    var end: Date?
    var items: [TodoItem] = []
    /// Unfinished to-dos from the previous list that were waved away ("×") instead of brought over.
    var dismissed: [String] = []

    func isRunning(at date: Date) -> Bool {
        start <= date && (end.map { date < $0 } ?? true)
    }

    var leftCount: Int { items.filter { !$0.done }.count }

    func displayName(at now: Date) -> String {
        if let name, !name.isEmpty { return name }
        let calendar = Calendar.current
        if isRunning(at: now) || calendar.isDate(start, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(start, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return start.formatted(.dateTime.weekday(.wide).day().month())
    }

    /// The block of to-dos a widget or the card shows when they don't all fit in `height`: ticked ones stay where
    /// they are, and the next block appears once everything in this one is ticked.
    func window(height: Double, rowHeight: (TodoItem) -> Double) -> (start: Int, items: ArraySlice<TodoItem>) {
        guard !items.isEmpty else { return (0, []) }
        let firstOpen = items.firstIndex(where: { !$0.done }) ?? (items.count - 1)
        var pageStart = 0
        var used = 0.0
        for (i, item) in items.enumerated() {
            let row = rowHeight(item)
            if used + row > height, i > pageStart {
                if firstOpen < i { return (pageStart, items[pageStart..<i]) }
                pageStart = i
                used = 0
            }
            used += row
        }
        return (pageStart, items[pageStart..<items.count])
    }
}

/// How the Lock Screen card looks.
struct CardSettings: Codable, Hashable {
    /// Lighter (above 0) or darker (below 0) than Apple's standard frosted glass, which is darker than notifications.
    var shade = 0.15
    /// No frosted glass at all: the wallpaper shows straight through.
    var seeThrough = false
    /// The card's own text size (nil = the same as the lists). Smaller fits more to-dos on the card.
    var size: Double?
}

struct TodoSettings: Codable, Hashable {
    /// The font and size of every to-do that doesn't have its own.
    var text = TextLook()
    var card = CardSettings()
    /// The daily reset, in minutes after midnight (0 = midnight): new lists end then unless told otherwise.
    var resetMinutes = 0
    var planReminder = false
    var planMinutes = 21 * 60
    var keepCard = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = TodoSettings()
        text = (try? c.decodeIfPresent(TextLook.self, forKey: .text)) ?? d.text
        card = (try? c.decodeIfPresent(CardSettings.self, forKey: .card)) ?? d.card
        resetMinutes = try c.decodeIfPresent(Int.self, forKey: .resetMinutes) ?? d.resetMinutes
        planReminder = try c.decodeIfPresent(Bool.self, forKey: .planReminder) ?? d.planReminder
        planMinutes = try c.decodeIfPresent(Int.self, forKey: .planMinutes) ?? d.planMinutes
        keepCard = try c.decodeIfPresent(Bool.self, forKey: .keepCard) ?? d.keepCard
    }

    /// The next daily reset after `date`.
    func nextReset(after date: Date) -> Date {
        let time = DateComponents(hour: resetMinutes / 60, minute: resetMinutes % 60)
        return Calendar.current.nextDate(after: date, matching: time, matchingPolicy: .nextTime)
            ?? date.addingTimeInterval(86_400)
    }
}

/// Everything the app keeps: all the lists and the settings.
struct TodoData: Codable, Hashable {
    var lists: [TodoList] = []
    var settings = TodoSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lists = try c.decodeIfPresent([TodoList].self, forKey: .lists) ?? []
        settings = try c.decodeIfPresent(TodoSettings.self, forKey: .settings) ?? TodoSettings()
    }

    /// Lists running at `date`, newest first.
    func running(at date: Date) -> [TodoList] {
        lists.filter { $0.isRunning(at: date) }.sorted { $0.start > $1.start }
    }

    /// Lists that start after `date`, soonest first.
    func planned(after date: Date) -> [TodoList] {
        lists.filter { $0.start > date }.sorted { $0.start < $1.start }
    }

    /// The list the widgets and the card follow: the newest running list with an end (a daily one), else the
    /// newest running one.
    func current(at date: Date) -> TodoList? {
        let active = running(at: date)
        return active.first { $0.end != nil } ?? active.first
    }

    /// The running list a widget was set to (by name), or the current one.
    func list(named name: String?, at date: Date) -> TodoList? {
        guard let name, !name.isEmpty else { return current(at: date) }
        return running(at: date).first { $0.name == name }
    }

    var customNames: [String] {
        Array(Set(lists.compactMap { $0.name }.filter { !$0.isEmpty })).sorted()
    }

    /// Moments when what the widgets show changes (a list starting or ending).
    func changes(after date: Date) -> [Date] {
        var moments = Set<Date>()
        for list in lists {
            moments.insert(list.start)
            if let end = list.end { moments.insert(end) }
        }
        return moments.filter { $0 > date }.sorted()
    }

    /// The list (if any) that starts when `list` ends.
    func next(after list: TodoList) -> TodoList? {
        guard let end = list.end else { return nil }
        return lists.first { $0.id != list.id && abs($0.start.timeIntervalSince(end)) < 60 }
    }

    /// Unfinished to-dos from the previous list of the same kind, offered (not added) when making the next one.
    func suggestions(for list: TodoList, at now: Date) -> [TodoItem] {
        guard list.end.map({ $0 > now }) ?? true else { return [] }
        let previous = lists
            .filter { $0.id != list.id && $0.name == list.name && $0.end != nil && $0.start < list.start }
            .max { $0.start < $1.start }
        guard let previous else { return [] }
        let have = Set(list.items.map { $0.title.lowercased() })
        return previous.items.filter {
            !$0.done && !have.contains($0.title.lowercased()) && !list.dismissed.contains($0.id)
        }
    }

    /// Forgets lists that ended more than two weeks ago.
    mutating func prune(now: Date = .now) {
        lists.removeAll { list in list.end.map { now.timeIntervalSince($0) > 14 * 86_400 } ?? false }
    }

    /// For the widget gallery's preview.
    static var sample: TodoData {
        var data = TodoData()
        data.lists = [TodoList(start: .now, end: data.settings.nextReset(after: .now), items: TodoItem.samples)]
        return data
    }
}
