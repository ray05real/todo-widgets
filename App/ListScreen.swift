import SwiftUI

/// One list: its to-dos (tap to tick), unfinished ones from last time to bring over, and a box to add more.
struct ListScreen: View {
    @EnvironmentObject private var model: AppModel
    let listID: String
    @State private var newTitle = ""
    @State private var newColor = 0
    /// The font for to-dos being added (nil = the list's font from Settings); it stays picked for the next one.
    @State private var newFont: FontChoice?
    @State private var editing: TodoItem?
    @State private var editingTimes = false
    @FocusState private var adding: Bool

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
        let suggestions = model.data.suggestions(for: list, at: .now)
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

            Section {
                ForEach(list.items) { item in
                    ItemRow(item: item, look: look.applied(to: item)) {
                        model.edit(list.id) { list in
                            if let i = list.items.firstIndex(where: { $0.id == item.id }) { list.items[i].done.toggle() }
                        }
                    }
                    // Swiping left, like a chat in WhatsApp: a short swipe shows Edit and Delete, a long swipe deletes.
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            model.edit(list.id) { list in list.items.removeAll { $0.id == item.id } }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            editing = item
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(Color.gray)
                    }
                    .contextMenu {
                        Button("Edit") { editing = item }
                        Button("Delete", role: .destructive) {
                            model.edit(list.id) { list in list.items.removeAll { $0.id == item.id } }
                        }
                    }
                }
                .onMove { from, to in
                    model.edit(list.id) { $0.items.move(fromOffsets: from, toOffset: to) }
                }
            } footer: {
                if !list.items.isEmpty {
                    Tip("Tap to tick. Swipe left to edit or delete.")
                }
            }

            Section {
                TextField("Add a to-do", text: $newTitle)
                    .font((newFont ?? look.font).font(size: look.size))
                    .foregroundStyle(Palette.color(newColor))
                    .focused($adding)
                    .submitLabel(.done)
                    .onSubmit { add(to: list) }
                ColorDots(selection: $newColor)
                FontChips(selection: $newFont, sameAsList: true)
            } header: {
                Text("Add")
            }

            // Below the Add box (the owner's choice), so they don't sit on top of the new list.
            if !suggestions.isEmpty {
                Section {
                    ForEach(suggestions) { item in
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
        .navigationTitle(list.displayName(at: .now))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            // Rename and Delete moved to swiping the list left on the first screen; this menu is only there for the
            // per-list card switch (Settings → Every list).
            if model.data.settings.cardPerList {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
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
        .sheet(item: $editing) { item in
            ItemEditor(listID: list.id, item: item)
        }
        .sheet(isPresented: $editingTimes) {
            ListTimesEditor(list: list)
        }
    }

    private func add(to list: TodoList) {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let color = newColor
        let font = newFont
        model.edit(list.id) { $0.items.append(TodoItem(title: title, color: color, font: font)) }
        newTitle = ""
        adding = true
    }

    private func bringOver(_ items: [TodoItem], to list: TodoList) {
        model.edit(list.id) { list in
            list.items += items.map { TodoItem(title: $0.title, color: $0.color, font: $0.font, size: $0.size) }
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
