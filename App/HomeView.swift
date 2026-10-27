import Combine
import SwiftUI

/// The first screen: lists running now, planned lists, and buttons to make new ones.
struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [String] = []
    @State private var showNew = false
    /// The saved list a new list starts from (tapping one in Saved).
    @State private var newFrom: String?
    /// The list or saved list being renamed (from a swipe), and the name being typed.
    @State private var renaming: String?
    @State private var nameDraft = ""

    var body: some View {
        NavigationStack(path: $path) {
            TimelineView(.everyMinute) { timeline in
                lists(at: timeline.date)
            }
            .alert("Rename list", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $nameDraft)
                Button("Save") {
                    let name = nameDraft.trimmingCharacters(in: .whitespaces)
                    if let id = renaming {
                        if model.data.saved.contains(where: { $0.id == id }) {
                            model.renameSaved(id, to: name)
                        } else {
                            model.edit(id) { $0.name = name.isEmpty ? nil : name }
                        }
                    }
                    renaming = nil
                }
                Button("Cancel", role: .cancel) { renaming = nil }
            } message: {
                Text("Leave it empty to call it Today or Tomorrow.")
            }
            // The logo and the settings cog sit in iOS's own top bar, exactly where the back arrow is on the other
            // screens (the owner's reference). Neither gets iOS's glass bubble: the logo has a fixed size (the bar
            // shrank it), and the cog keeps the owner's look, a blue cog in a dark circle.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Logo()
                        .frame(width: 79, height: 36)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Self.settingsRoute) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .navigationDestination(for: String.self) { id in
                if id == Self.settingsRoute {
                    SettingsView()
                } else {
                    ListScreen(listID: id)
                }
            }
        }
        .sheet(isPresented: $showNew) {
            NewListSheet(startFrom: newFrom) { id in path.append(id) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            model.reload()
            let data = model.data
            Task { await LiveCard.sync(data, from: "app") }
        }
        .onReceive(NotificationCenter.default.publisher(for: .todoDataChanged)) { _ in
            model.reload()
        }
        .task {
            Reminders.ask()
            await LiveCard.sync(model.data, from: "app")
        }
    }

    /// The navigation value that opens Settings (list ids are UUIDs, so they can't clash with it).
    private static let settingsRoute = "settings"

    private func lists(at now: Date) -> some View {
        let running = model.data.running(at: now)
        let planned = model.data.planned(after: now)
        return List {
            if running.isEmpty {
                Section {
                    Button {
                        path.append(model.newListForToday())
                    } label: {
                        Label("Make today's list", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                } footer: {
                    Tip("No list is running right now.")
                }
            } else {
                Section {
                    let onCards = Set(model.data.listsOnCards(at: now).map { $0.id })
                    ForEach(running) { list in
                        NavigationLink(value: list.id) {
                            ListSummary(list: list, now: now, onCard: model.data.settings.keepCard && onCards.contains(list.id))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) { swipeActions(for: list) }
                    }
                    .onMove { source, destination in
                        model.moveRunning(from: source, to: destination, at: now)
                    }
                } header: {
                    Text("Now")
                } footer: {
                    if running.count > 1 {
                        Tip("Hold and drag to reorder. 🔒 = on the Lock Screen.")
                    }
                }
            }
            if !planned.isEmpty {
                Section("Planned") {
                    ForEach(planned) { list in
                        NavigationLink(value: list.id) {
                            ListSummary(list: list, now: now)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) { swipeActions(for: list) }
                    }
                }
            }
            Section {
                Button {
                    path.append(model.planNext())
                } label: {
                    Label("Plan the next list", systemImage: "calendar.badge.plus")
                }
                Button {
                    newFrom = nil
                    showNew = true
                } label: {
                    Label("New list…", systemImage: "plus")
                }
            } footer: {
                Tip("A planned list takes over when this one ends.")
            }
            if !model.data.saved.isEmpty {
                Section {
                    ForEach(model.data.saved) { saved in
                        Button {
                            newFrom = saved.id
                            showNew = true
                        } label: {
                            HStack {
                                Label(saved.name, systemImage: "tray.full")
                                Spacer()
                                Text("\(saved.items.count) to-dos")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                model.deleteSaved(saved.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                nameDraft = saved.name
                                renaming = saved.id
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(Color.gray)
                        }
                    }
                } header: {
                    Text("Saved")
                } footer: {
                    Tip("Tap one to start a new list with its to-dos.")
                }
            }
        }
    }

    /// Swiping a list left, like a chat in WhatsApp: a short swipe shows Rename and Delete, a long swipe deletes.
    @ViewBuilder
    private func swipeActions(for list: TodoList) -> some View {
        Button(role: .destructive) {
            model.deleteList(list.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        Button {
            nameDraft = list.name ?? ""
            renaming = list.id
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        .tint(Color.gray)
    }
}

/// One list on the first screen: its name, how far through it you are, and its time.
struct ListSummary: View {
    let list: TodoList
    let now: Date
    /// The list the Lock Screen card and the widgets show.
    var onCard = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(list.displayName(at: now))
                    .font(.headline)
                if onCard {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("On the Lock Screen")
                }
                Spacer()
                Text("\(list.items.count - list.leftCount) of \(list.items.count) done")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            TimeLabel(list: list, now: now)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
