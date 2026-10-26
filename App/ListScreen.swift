import SwiftUI

/// One list: its to-dos (tap to tick), unfinished ones from last time to bring over, and a box to add more.
struct ListScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let listID: String
    @State private var newTitle = ""
    @State private var newColor = 0
    @State private var editing: TodoItem?
    @State private var renaming = false
    @State private var nameDraft = ""
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
                TimelineView(.everyMinute) { timeline in
                    TimeLabel(list: list, now: timeline.date)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(list.items) { item in
                    ItemRow(item: item, look: look.applied(to: item)) {
                        model.edit(list.id) { list in
                            if let i = list.items.firstIndex(where: { $0.id == item.id }) { list.items[i].done.toggle() }
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button("Edit") { editing = item }
                            .tint(Color.blue)
                    }
                    .contextMenu {
                        Button("Edit") { editing = item }
                        Button("Delete", role: .destructive) {
                            model.edit(list.id) { list in list.items.removeAll { $0.id == item.id } }
                        }
                    }
                }
                .onDelete { offsets in
                    model.edit(list.id) { $0.items.remove(atOffsets: offsets) }
                }
                .onMove { from, to in
                    model.edit(list.id) { $0.items.move(fromOffsets: from, toOffset: to) }
                }
            } footer: {
                if !list.items.isEmpty {
                    Tip("Tap to tick. Swipe right to edit.")
                }
            }

            Section {
                TextField("Add a to-do", text: $newTitle)
                    .font(look.swiftUIFont)
                    .foregroundStyle(Palette.color(newColor))
                    .focused($adding)
                    .submitLabel(.done)
                    .onSubmit { add(to: list) }
                ColorDots(selection: $newColor)
            } header: {
                Text("Add")
            }

            // Below the Add box (the owner's choice), so they don't sit on top of the new list.
            if !suggestions.isEmpty {
                Section {
                    ForEach(suggestions) { item in
                        HStack(spacing: 14) {
                            Text(item.title)
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
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename") {
                        nameDraft = list.name ?? ""
                        renaming = true
                    }
                    if model.data.settings.cardPerList {
                        // Only matters when every list gets its own card (Settings → Every list).
                        Toggle("Show on the Lock Screen", isOn: Binding(
                            get: { list.showOnCard },
                            set: { on in model.edit(list.id) { $0.showOnCard = on } }
                        ))
                    }
                    Button("Delete list", role: .destructive) {
                        model.deleteList(list.id)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $editing) { item in
            ItemEditor(listID: list.id, item: item)
        }
        .alert("Rename list", isPresented: $renaming) {
            TextField("Name", text: $nameDraft)
            Button("Save") {
                let name = nameDraft.trimmingCharacters(in: .whitespaces)
                model.edit(list.id) { $0.name = name.isEmpty ? nil : name }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Leave it empty to call it Today or Tomorrow.")
        }
    }

    private func add(to list: TodoList) {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let color = newColor
        model.edit(list.id) { $0.items.append(TodoItem(title: title, color: color)) }
        newTitle = ""
        adding = true
    }

    private func bringOver(_ items: [TodoItem], to list: TodoList) {
        model.edit(list.id) { list in
            list.items += items.map { TodoItem(title: $0.title, color: $0.color, font: $0.font, size: $0.size) }
        }
    }
}
