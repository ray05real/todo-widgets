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

/// How to-dos' letters are shown (what you typed is kept as it is).
enum LetterCase: String, Codable, CaseIterable, Identifiable {
    case asTyped, capitalFirst, upper, lower

    var id: String { rawValue }

    var label: String {
        switch self {
        case .asTyped: return "As typed"
        case .capitalFirst: return "Abc"
        case .upper: return "ABC"
        case .lower: return "abc"
        }
    }

    func apply(_ text: String) -> String {
        switch self {
        case .asTyped: return text
        case .capitalFirst: return text.prefix(1).uppercased() + text.dropFirst()
        case .upper: return text.uppercased()
        case .lower: return text.lowercased()
        }
    }
}

/// A font, a size and how the letters are shown.
struct TextLook: Codable, Hashable {
    var font: FontChoice = .system
    var size: Double = 17
    var letterCase: LetterCase = .asTyped

    /// This look with a to-do's own font and size, where it has them.
    func applied(to item: TodoItem) -> TextLook {
        TextLook(font: item.font ?? font, size: item.size ?? size, letterCase: letterCase)
    }

    /// A to-do's words as they should appear.
    func display(_ title: String) -> String {
        letterCase.apply(title)
    }
}

extension TextLook {
    /// Looks saved before a field existed still load (in an extension, so the memberwise init stays).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        font = (try? c.decodeIfPresent(FontChoice.self, forKey: .font)) ?? .system
        size = try c.decodeIfPresent(Double.self, forKey: .size) ?? 17
        letterCase = (try? c.decodeIfPresent(LetterCase.self, forKey: .letterCase)) ?? .asTyped
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
    /// Whether it gets its own Lock Screen card when Settings is on "Every list".
    var showOnCard = true

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

    /// "TO DO" for the daily lists, else the list's name the same way ("SHOPPING"), for the card and widgets.
    var headerTitle: String {
        ((name?.isEmpty ?? true) ? "To do" : name!).uppercased()
    }

    /// The block of to-dos a widget or the card shows when they don't all fit in `columns` columns of `height`
    /// (the last column, or with `reserveFirst` the first, `reserve` shorter, leaving room for the countdown):
    /// ticked ones stay where they are, and the next block appears once everything in this one is ticked.
    func window(height: Double, columns: Int = 1, reserve: Double = 0, reserveFirst: Bool = false,
                rowHeight: (TodoItem) -> Double) -> (start: Int, items: ArraySlice<TodoItem>) {
        guard !items.isEmpty else { return (0, []) }
        let firstOpen = items.firstIndex(where: { !$0.done }) ?? (items.count - 1)
        var pageStart = 0
        var column = 0
        var used = 0.0
        for (i, item) in items.enumerated() {
            let row = rowHeight(item)
            let shortened = reserveFirst ? column == 0 : column == columns - 1
            let limit = shortened ? height - reserve : height
            if used + row > limit, used > 0 {
                if column + 1 < columns {
                    column += 1
                } else {
                    if firstOpen < i { return (pageStart, items[pageStart..<i]) }
                    pageStart = i
                    column = 0
                }
                used = 0
            }
            used += row
        }
        return (pageStart, items[pageStart..<items.count])
    }
}

extension TodoList {
    /// Lists saved before a field existed still load (in an extension, so the memberwise init stays).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        start = try c.decode(Date.self, forKey: .start)
        end = try c.decodeIfPresent(Date.self, forKey: .end)
        items = try c.decodeIfPresent([TodoItem].self, forKey: .items) ?? []
        dismissed = try c.decodeIfPresent([String].self, forKey: .dismissed) ?? []
        showOnCard = try c.decodeIfPresent(Bool.self, forKey: .showOnCard) ?? true
    }
}

extension Collection where Element == TodoItem {
    /// Splits to-dos into up to `count` columns of at most `height` (the last one, or with `reserveFirst` the first,
    /// `reserve` shorter), filling each column top to bottom.
    func inColumns(_ count: Int, height: Double, reserve: Double = 0, reserveFirst: Bool = false,
                   rowHeight: (TodoItem) -> Double) -> [[TodoItem]] {
        var columns: [[TodoItem]] = [[]]
        var used = 0.0
        for item in self {
            let row = rowHeight(item)
            let shortened = reserveFirst ? columns.count == 1 : columns.count == count
            let limit = shortened ? height - reserve : height
            if used + row > limit, used > 0, columns.count < count {
                columns.append([])
                used = 0
            }
            columns[columns.count - 1].append(item)
            used += row
        }
        return columns
    }
}

/// The Lock Screen card's background. (Apple's own glass, Liquid Glass and see-through looks were tried and dropped.)
enum CardStyle: String, Codable, CaseIterable, Identifiable {
    /// See-through dark, about like iOS 26's notifications.
    case standard
    /// White like a sheet of paper, with dark text.
    case white
    /// Black, with white text.
    case black

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return "Glass"
        case .white: return "White"
        case .black: return "Black"
        }
    }
}

/// Where the countdown sits on the card and the widgets.
enum TimerPlace: String, Codable, CaseIterable, Identifiable {
    /// In the title line: costs no to-do.
    case topRight
    /// On its own line under the first or last column: costs one to-do there.
    case bottomLeft, bottomRight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .topRight: return "Top right"
        case .bottomLeft: return "Bottom left"
        case .bottomRight: return "Bottom right"
        }
    }
}

/// How the Lock Screen card (and its Dynamic Island versions) look.
struct CardSettings: Codable, Hashable {
    var timerPlace = TimerPlace.topRight
    var style = CardStyle.standard
    /// Each look's brightness, remembered separately, in steps of 0.05 from -0.25 (darker) to 0.25 (lighter);
    /// 0 is the middle mark. (`shade` is the Glass one: it was the only one before White and Black had theirs.)
    var shade = 0.0
    var whiteShade = 0.0
    var blackShade = 0.0
    /// The card's own text size (nil = the same as the lists). Smaller fits more to-dos on the card.
    var size: Double?
    /// Two columns fit twice as many short to-dos on the card.
    var columns = 1
    var showInIsland = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = CardSettings()
        timerPlace = (try? c.decodeIfPresent(TimerPlace.self, forKey: .timerPlace)) ?? d.timerPlace
        style = (try? c.decodeIfPresent(CardStyle.self, forKey: .style)) ?? d.style
        shade = try c.decodeIfPresent(Double.self, forKey: .shade) ?? d.shade
        whiteShade = try c.decodeIfPresent(Double.self, forKey: .whiteShade) ?? d.whiteShade
        blackShade = try c.decodeIfPresent(Double.self, forKey: .blackShade) ?? d.blackShade
        size = try c.decodeIfPresent(Double.self, forKey: .size)
        columns = try c.decodeIfPresent(Int.self, forKey: .columns) ?? d.columns
        showInIsland = try c.decodeIfPresent(Bool.self, forKey: .showInIsland) ?? d.showInIsland
    }

    /// The brightness of the look that's picked.
    var currentShade: Double {
        get {
            switch style {
            case .standard: return shade
            case .white: return whiteShade
            case .black: return blackShade
            }
        }
        set {
            switch style {
            case .standard: shade = newValue
            case .white: whiteShade = newValue
            case .black: blackShade = newValue
            }
        }
    }
}

struct TodoSettings: Codable, Hashable {
    /// The font and size of every to-do that doesn't have its own.
    var text = TextLook()
    var card = CardSettings()
    /// Columns on the Home Screen widgets (small widgets always have one).
    var widgetColumns = 1
    /// "resets in 2 hrs, 13 min" on the card and the widgets.
    var showCountdown = true
    /// The small explanations under sections in the app (off: the owner found them wordy).
    var showTips = false
    /// The daily reset, in minutes after midnight (0 = midnight): new lists end then unless told otherwise.
    var resetMinutes = 0
    var planReminder = false
    var planMinutes = 21 * 60
    var keepCard = true
    /// false: one card showing the top list (drag to reorder). true: a card for every running list that has
    /// "Show on the Lock Screen" on.
    var cardPerList = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = TodoSettings()
        text = (try? c.decodeIfPresent(TextLook.self, forKey: .text)) ?? d.text
        card = (try? c.decodeIfPresent(CardSettings.self, forKey: .card)) ?? d.card
        widgetColumns = try c.decodeIfPresent(Int.self, forKey: .widgetColumns) ?? d.widgetColumns
        showCountdown = try c.decodeIfPresent(Bool.self, forKey: .showCountdown) ?? d.showCountdown
        showTips = try c.decodeIfPresent(Bool.self, forKey: .showTips) ?? d.showTips
        resetMinutes = try c.decodeIfPresent(Int.self, forKey: .resetMinutes) ?? d.resetMinutes
        planReminder = try c.decodeIfPresent(Bool.self, forKey: .planReminder) ?? d.planReminder
        planMinutes = try c.decodeIfPresent(Int.self, forKey: .planMinutes) ?? d.planMinutes
        keepCard = try c.decodeIfPresent(Bool.self, forKey: .keepCard) ?? d.keepCard
        cardPerList = try c.decodeIfPresent(Bool.self, forKey: .cardPerList) ?? d.cardPerList
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

    /// Lists running at `date`, in the owner's order (drag to reorder on the first screen).
    func running(at date: Date) -> [TodoList] {
        lists.filter { $0.isRunning(at: date) }
    }

    /// Lists that start after `date`, soonest first.
    func planned(after date: Date) -> [TodoList] {
        lists.filter { $0.start > date }.sorted { $0.start < $1.start }
    }

    /// The list the card and the widgets follow: the top running list in the owner's order.
    func current(at date: Date) -> TodoList? {
        running(at: date).first
    }

    /// The lists that get a Lock Screen card: just the top one, or (Settings → Every list) each running list
    /// that has "Show on the Lock Screen" on.
    func listsOnCards(at date: Date) -> [TodoList] {
        guard settings.cardPerList else { return current(at: date).map { [$0] } ?? [] }
        return running(at: date).filter { $0.showOnCard }
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
