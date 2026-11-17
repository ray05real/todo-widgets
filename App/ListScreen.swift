import SwiftUI

/// One list: a box to add to-dos at the top, then its to-dos (tap one to change it, drag ≡ to move it), then
/// permanent to-dos and unfinished ones from last time to bring over.
struct ListScreen: View {
    @EnvironmentObject private var model: AppModel
    let listID: String
    @State private var newTitle = ""
    @State private var newColor = 0
    /// The font and size for to-dos being added (nil = the list's, from Settings); they stay picked for the next one.
    @State private var newFont: FontChoice?
    @State private var newSize: Double?
    @State private var editingTimes = false
    @FocusState private var focus: Field?
    /// While a ≡ handle is held: the to-dos in their new order (saved when it's let go), the one being moved, and how
    /// far the finger has gone in rows already passed.
    @State private var dragOrder: [String]?
    @State private var dragging: String?
    @State private var dragPassed: CGFloat = 0
    /// Each to-do's height, so a dragged one swaps places once the finger passes the middle of the next.
    @State private var rowHeights: [String: CGFloat] = [:]

    /// What the keyboard is typing into: the Add box or one of the to-dos.
    enum Field: Hashable {
        case add
        case item(String)
    }

    /// Space above and below each to-do inside its row (part of its height when dragging).
    private static let rowInset: CGFloat = 8

    var body: some View {
        if let list = model.list(listID) {
            content(list)
        } else {
            Text("This list was deleted.")
                .foregroundStyle(.secondary)
        }
    }

    private func content(_ list: TodoList) -> some View {
        let look = model.data.settings.text
        let permanent = model.data.permanentSuggestions(for: list, at: .now)
        let suggestions = model.data.suggestions(for: list, at: .now)
        let items = dragOrder.map { order in order.compactMap { id in list.items.first { $0.id == id } } } ?? list.items
        return List {
            Section {
                // Tap to change when the list starts and ends.
                Button {
                    editingTimes = true
                } label: {
                    HStack {
                        TimelineView(.everyMinute) { timeline in
                            TimeLabel(list: list, now: timeline.date)
                        }
                        Spacer()
                        Image(systemName: "calendar")
                    }
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // At the top (the owner's choice), so new to-dos are written before reading down the list.
            Section {
                TextField("Add a to-do", text: $newTitle)
                    .font((newFont ?? look.font).font(size: newSize ?? look.size))
                    .foregroundStyle(Palette.color(newColor))
                    .focused($focus, equals: .add)
                    .submitLabel(.done)
                    .onSubmit { add(to: list) }
                ColorDots(selection: $newColor)
                FontChips(selection: $newFont, sameAsList: true)
                OwnSizeToggle(size: $newSize, defaultSize: look.size)
            } header: {
                Text("Add")
            }

            Section {
                ForEach(items) { item in
                    HStack(spacing: 6) {
                        EditableItemRow(listID: list.id, item: item, look: look.applied(to: item), focus: $focus)
                            .background {
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear { rowHeights[item.id] = geo.size.height }
                                        .onChange(of: geo.size.height) { _, height in rowHeights[item.id] = height }
                                }
                            }
                        dragHandle(for: item, in: list)
                    }
                    .listRowInsets(EdgeInsets(top: Self.rowInset, leading: 20, bottom: Self.rowInset, trailing: 4))
                    .listRowBackground(dragging == item.id ? Color.accentColor.opacity(0.18) : Color(.secondarySystemGroupedBackground))
                    // Swiping left, like a chat in WhatsApp: a short swipe shows Make permanent and Delete, a long
                    // swipe deletes.
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            model.edit(list.id) { list in list.items.removeAll { $0.id == item.id } }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            model.togglePermanent(item)
                        } label: {
                            if model.data.isPermanent(item) {
                                Label("Not permanent", systemImage: "pin.slash")
                            } else {
                                Label("Make permanent", systemImage: "pin")
                            }
                        }
                        .tint(Color.orange)
                    }
                }
            } footer: {
                if !list.items.isEmpty {
                    Tip("Tap a to-do to change it, drag ≡ to move it, swipe left to make it permanent or delete it.")
                }
            }

            if !permanent.isEmpty {
                Section {
                    ForEach(permanent) { item in
                        offerRow(item, look: look, in: list)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    model.removePermanent(item.id)
                                } label: {
                                    Label("Not permanent", systemImage: "pin.slash")
                                }
                            }
                    }
                    if permanent.count > 1 {
                        Button("Add all \(permanent.count)") { bringOver(permanent, to: list) }
                    }
                } header: {
                    Text("Permanent")
                } footer: {
                    Tip("+ adds it to this list, × skips it here. Swipe left to stop it being permanent.")
                }
            }

            if !suggestions.isEmpty {
                Section {
                    ForEach(suggestions) { item in
                        offerRow(item, look: look, in: list)
                    }
                    if suggestions.count > 1 {
                        Button("Bring all \(suggestions.count) over") { bringOver(suggestions, to: list) }
                    }
                } header: {
                    Text("Not finished last time")
                } footer: {
                    Tip("+ brings it over, × leaves it behind.")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollDisabled(dragging != nil)
        .sensoryFeedback(.selection, trigger: dragOrder)
        .navigationTitle(list.displayName(at: .now))
        .toolbar {
            // Rename, Delete and Save moved to swiping the list on the first screen.
            if model.data.settings.cardPerList {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // Only matters when every list gets its own card (Settings → Every list).
                        Toggle("Show on the Lock Screen", isOn: Binding(
                            get: { list.showOnCard },
                            set: { on in model.edit(list.id) { $0.showOnCard = on } }
                        ))
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
            }
        }
        .sheet(isPresented: $editingTimes) {
            ListTimesEditor(list: list)
        }
    }

    /// A to-do offered for this list (permanent, or not finished last time): + adds it, × leaves it off this list.
    private func offerRow(_ item: TodoItem, look: TextLook, in list: TodoList) -> some View {
        HStack(spacing: 14) {
            Text(look.display(item.title))
                .font(look.applied(to: item).swiftUIFont)
                .foregroundStyle(Palette.color(item.color))
            Spacer()
            Button {
                bringOver([item], to: list)
            } label: {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
            .buttonStyle(.borderless)
            .tint(Color.green)
            Button {
                model.edit(list.id) { $0.dismissed.append(item.id) }
            } label: {
                Image(systemName: "xmark.circle").font(.title2)
            }
            .buttonStyle(.borderless)
            .tint(Color.secondary)
        }
    }

    /// The ≡ on the right of a to-do: hold it and drag up or down to move the to-do (the standard way on iPhone, so
    /// holding the row itself no longer moves it).
    private func dragHandle(for item: TodoItem, in list: TodoList) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.body.weight(.medium))
            .foregroundStyle(.tertiary)
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
            .gesture(
                // Measured on the whole screen: the handle itself moves as the to-do swaps places.
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in drag(item.id, by: value.translation.height, in: list) }
                    .onEnded { _ in endDrag(in: list) }
            )
            .accessibilityLabel("Move")
    }

    private func height(of id: String) -> CGFloat {
        (rowHeights[id] ?? 28) + Self.rowInset * 2
    }

    /// Moves the dragged to-do past each neighbour whose middle the finger has crossed.
    private func drag(_ id: String, by dy: CGFloat, in list: TodoList) {
        if dragging == nil {
            focus = nil
            dragging = id
            dragPassed = 0
        }
        var order = dragOrder ?? list.items.map(\.id)
        guard var i = order.firstIndex(of: id) else { return }
        var left = dy - dragPassed
        while left > 0, i + 1 < order.count, left > height(of: order[i + 1]) / 2 {
            let h = height(of: order[i + 1])
            order.swapAt(i, i + 1)
            i += 1
            dragPassed += h
            left -= h
        }
        while left < 0, i > 0, -left > height(of: order[i - 1]) / 2 {
            let h = height(of: order[i - 1])
            order.swapAt(i, i - 1)
            i -= 1
            dragPassed -= h
            left += h
        }
        if order != dragOrder {
            withAnimation(.snappy(duration: 0.18)) { dragOrder = order }
        }
    }

    private func endDrag(in list: TodoList) {
        if let order = dragOrder, order != list.items.map(\.id) {
            model.edit(list.id) { list in
                let byID = Dictionary(uniqueKeysWithValues: list.items.map { ($0.id, $0) })
                list.items = order.compactMap { byID[$0] } + list.items.filter { !order.contains($0.id) }
            }
        }
        dragOrder = nil
        dragging = nil
        dragPassed = 0
    }

    private func add(to list: TodoList) {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let color = newColor
        let font = newFont
        let size = newSize
        model.edit(list.id) { $0.items.append(TodoItem(title: title, color: color, font: font, size: size)) }
        newTitle = ""
        focus = .add
    }

    private func bringOver(_ items: [TodoItem], to list: TodoList) {
        model.edit(list.id) { list in
            list.items += items.map { TodoItem(title: $0.title, color: $0.color, font: $0.font, size: $0.size) }
        }
    }
}

/// A to-do in a list. Tap it to change its words right there (the keyboard opens); while it's being changed, its
/// colour, font and size show under it. The circle shows whether it's ticked: ticking happens on the widgets, the
/// Lock Screen card and the Dynamic Island.
struct EditableItemRow: View {
    @EnvironmentObject private var model: AppModel
    let listID: String
    let item: TodoItem
    let look: TextLook
    var focus: FocusState<ListScreen.Field?>.Binding
    @State private var draft = ""

    private var isEditing: Bool { focus.wrappedValue == .item(item.id) }

    var body: some View {
        let tint = Palette.color(item.color)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: look.circle + 2))
                    .foregroundStyle(tint.opacity(item.done ? 0.55 : 0.9))
                // The words as typed while changing them; otherwise as they show everywhere (capitals, crossed out).
                ZStack(alignment: .leading) {
                    TextField("To-do", text: $draft, axis: .vertical)
                        .font(look.swiftUIFont)
                        .foregroundStyle(tint)
                        .focused(focus, equals: .item(item.id))
                        .submitLabel(.done)
                        .opacity(isEditing ? 1 : 0)
                    if !isEditing {
                        Text(look.display(item.title))
                            .font(look.swiftUIFont)
                            .strikethrough(item.done)
                            .foregroundStyle(tint.opacity(item.done ? 0.45 : 1))
                            .allowsHitTesting(false)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 28)
            .contentShape(Rectangle())
            .onTapGesture { focus.wrappedValue = .item(item.id) }

            if isEditing {
                ColorDots(selection: Binding(get: { item.color }, set: { color in change { $0.color = color } }))
                FontChips(selection: Binding(get: { item.font }, set: { font in change { $0.font = font } }), sameAsList: true)
                OwnSizeToggle(size: Binding(get: { item.size }, set: { size in change { $0.size = size } }),
                              defaultSize: model.data.settings.text.size)
            }
        }
        .onAppear { draft = item.title }
        .onChange(of: item.title) { _, title in
            if !isEditing { draft = title }
        }
        .onChange(of: draft) { _, text in
            // The box wraps long to-dos, so Return would start a new line: here it finishes instead.
            if text.contains("\n") {
                draft = text.replacingOccurrences(of: "\n", with: "")
                focus.wrappedValue = nil
            }
        }
        .onChange(of: isEditing) { _, editing in
            if !editing { saveWords() }
        }
    }

    /// Keeps the new words (emptying them doesn't delete the to-do: swiping does).
    private func saveWords() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            draft = item.title
            return
        }
        if title != item.title { change { $0.title = title } }
    }

    private func change(_ edit: @escaping (inout TodoItem) -> Void) {
        let id = item.id
        model.edit(listID) { list in
            if let i = list.items.firstIndex(where: { $0.id == id }) { edit(&list.items[i]) }
        }
    }
}

/// Changing when a list starts and ends (tap the time line at the top of a list).
struct ListTimesEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let listID: String
    @State private var start: Date
    @State private var hasEnd: Bool
    @State private var end: Date

    init(list: TodoList) {
        listID = list.id
        _start = State(initialValue: list.start)
        _hasEnd = State(initialValue: list.end != nil)
        _end = State(initialValue: list.end ?? list.start.addingTimeInterval(86_400))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Starts", selection: $start)
                }
                Section {
                    Toggle("Has an end", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("Ends", selection: $end, in: start.addingTimeInterval(60)...)
                    }
                }
            }
            .navigationTitle("List times")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let begins = start
                        let ends = hasEnd ? max(end, start.addingTimeInterval(60)) : nil
                        model.edit(listID) { list in
                            list.start = begins
                            list.end = ends
                        }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
