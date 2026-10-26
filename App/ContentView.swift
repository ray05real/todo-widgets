import SwiftUI
import UIKit
import WidgetKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var items = TodoStore.load()
    @State private var newTitle = ""
    @State private var cardOn = LiveCard.isRunning
    @State private var report = Report.text()
    @State private var log = Log.lines
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    ForEach(items) { item in
                        Button {
                            toggle(item.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(item.done ? Color.green : Color.secondary)
                                Text(item.title)
                                    .strikethrough(item.done)
                                    .foregroundStyle(item.done ? Color.secondary : Color.primary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        items.remove(atOffsets: offsets)
                        saved()
                    }
                    HStack {
                        TextField("Add a to-do", text: $newTitle)
                            .onSubmit(add)
                        Button("Add", action: add)
                            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    if cardOn {
                        Button("Renew the card (a fresh 8 hours)") {
                            Task {
                                await LiveCard.restart(items, from: "app")
                                refresh()
                            }
                        }
                        Button("Remove the card", role: .destructive) {
                            Task {
                                await LiveCard.stop()
                                refresh()
                            }
                        }
                    } else {
                        Button("Show on the Lock Screen") {
                            LiveCard.start(items, from: "app")
                            refresh()
                        }
                    }
                } header: {
                    Text("Lock Screen card")
                } footer: {
                    Text("Lock the phone to see it. It shows in the Dynamic Island too.")
                }

                Section("Test report") {
                    Text(report)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    Button(copied ? "Copied" : "Copy report") {
                        UIPasteboard.general.string = report + "\n\nLog:\n" + log.joined(separator: "\n")
                        copied = true
                    }
                }

                Section("What happened") {
                    if log.isEmpty {
                        Text("Nothing yet").foregroundStyle(.secondary)
                    }
                    ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption.monospaced())
                    }
                }
            }
            .navigationTitle("To-do test")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    private func toggle(_ id: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].done.toggle()
        saved()
    }

    private func add() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        items.append(TodoItem(title: title))
        newTitle = ""
        saved()
    }

    /// Keeps the widgets and the Lock Screen card in step with the app.
    private func saved() {
        TodoStore.save(items)
        WidgetCenter.shared.reloadAllTimelines()
        Task { await LiveCard.update(items) }
    }

    /// Picks up ticks made outside the app while it was closed.
    private func refresh() {
        items = TodoStore.load()
        cardOn = LiveCard.isRunning
        report = Report.text()
        log = Log.lines
        copied = false
    }
}
