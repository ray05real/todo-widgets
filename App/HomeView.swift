import Combine
import SwiftUI

/// The first screen: lists running now, planned lists, and buttons to make new ones.
struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [String] = []
    @State private var showNew = false

    var body: some View {
        NavigationStack(path: $path) {
            TimelineView(.everyMinute) { timeline in
                lists(at: timeline.date)
            }
            // The logo and the settings cog sit in iOS's own top bar, exactly where the back arrow is on the other
            // screens (the owner's reference). The logo has no glass bubble behind it; the cog keeps one, like the
            // back arrow.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Logo()
                        .frame(height: 30)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Self.settingsRoute) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
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
            NewListSheet { id in path.append(id) }
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
                    showNew = true
                } label: {
                    Label("New list…", systemImage: "plus")
                }
            } footer: {
                Tip("A planned list takes over when this one ends.")
            }
        }
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
