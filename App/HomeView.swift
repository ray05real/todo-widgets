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
            .navigationTitle("To-do")
            .navigationDestination(for: String.self) { id in
                ListScreen(listID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
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
                    Text("No list is running right now.")
                }
            } else {
                Section("Now") {
                    ForEach(running) { list in
                        NavigationLink(value: list.id) {
                            ListSummary(list: list, now: now)
                        }
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
                Text("Plan the next list ahead and it takes over when this one ends.")
            }
        }
    }
}

/// One list on the first screen: its name, how far through it you are, and its time.
struct ListSummary: View {
    let list: TodoList
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(list.displayName(at: now))
                    .font(.headline)
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
