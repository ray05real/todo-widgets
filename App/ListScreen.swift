import SwiftUI

/// One list: a box to add to-dos at the top, then its to-dos (tap one to change it, hold and drag to move it), then
/// pinned to-dos and unfinished ones from last time to bring over.
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

    /// What the keyboard is typing into: the Add box or one of the to-dos.
    enum Field: Hashable {
        case add
        case item(String)
    }

    private var isEditingItem: Bool {
        if case .item? = focus { return true }
        return false
    }

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
        return ScrollViewReader { scroller in
        List {
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
                ForEach(list.items) { item in
                    EditableItemRow(listID: list.id, item: item, look: look.applied(to: item), focus: $focus)
                        // Swiping left, like a chat in WhatsApp: a short swipe shows Pin and Delete, a long swipe
                        // deletes. Icons only: iOS puts a button's word beside its icon on short rows and under it on
                        // tall ones, so with words the buttons (and how far the row slides) changed size row to row.
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                model.edit(list.id) { list in list.items.removeAll { $0.id == item.id } }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .labelStyle(.iconOnly)
                            Button {
                                model.togglePermanent(item)
                            } label: {
                                if model.data.isPermanent(item) {
                                    Label("Unpin", systemImage: "pin.slash.fill")
                                } else {
                                    Label("Pin", systemImage: "pin.fill")
                                }
                            }
                            .labelStyle(.iconOnly)
                            .tint(Color.orange)
                        }
                }
                // Hold a to-do and drag it to move it: iOS's own lift-and-drag, smooth and only after a hold.
                .onMove { from, to in
                    model.edit(list.id) { $0.items.move(fromOffsets: from, toOffset: to) }
                }
            } footer: {
                if !list.items.isEmpty {
                    Tip("Tap a to-do to change it, hold and drag to move it, swipe left to pin or delete it.")
                }
            }

            if !permanent.isEmpty {
                Section {
                    ForEach(permanent) { item in
                        offerRow(item, look: look, in: list, plus: .red)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    model.removePermanent(item.id)
                                } label: {
                                    Label("Unpin", systemImage: "pin.slash.fill")
                                }
                                .labelStyle(.iconOnly)
                            }
                    }
                    if permanent.count > 1 {
                        Button("Add all \(permanent.count)") { bringOver(permanent, to: list) }
                    }
                } header: {
                    Text("Pinned")
                } footer: {
                    Tip("+ adds it to this list, × skips it here. Swipe left to unpin it.")
                }
            }

            if !suggestions.isEmpty {
                Section {
                    ForEach(suggestions) { item in
                        offerRow(item, look: look, in: list, plus: .green)
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
        // While a to-do is being changed, room below the list, so even the last to-do can scroll up.
        .contentMargins(.bottom, isEditingItem ? 420 : 0, for: .scrollContent)
        .onChange(of: focus) { _, field in
            guard case .item(let id)? = field else { return }
            // Straight away (the next frame, once that room is there), without waiting for the keyboard: the tapped
            // to-do's words land about halfway between the top bar and where the keyboard will be (the owner's
            // choice), with its colour, font and size still clear of the keyboard. scrollTo lines up the point 35% down
            // the to-do with the point 35% down the screen; with the keyboard taking the lower ~40% that puts the words
            // near the middle of what's left.
            DispatchQueue.main.async {
                withAnimation(.snappy(duration: 0.3)) { scroller.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.35)) }
            }
        }
        }
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
        }
        .sheet(isPresented: $editingTimes) {
            ListTimesEditor(list: list)
        }
    }

    /// A to-do offered for this list (pinned, with a red +, or not finished last time, with a green one): + adds it,
    /// × leaves it off this list.
    private func offerRow(_ item: TodoItem, look: TextLook, in list: TodoList, plus: Color) -> some View {
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
            .tint(plus)
            Button {
                model.edit(list.id) { $0.dismissed.append(item.id) }
            } label: {
                Image(systemName: "xmark.circle").font(.title2)
            }
            .buttonStyle(.borderless)
            .tint(Color.secondary)
        }
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
                        // Hidden, it mustn't catch touches: holding the row is how it's dragged.
                        .allowsHitTesting(isEditing)
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
