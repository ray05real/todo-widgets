import SwiftUI

/// Making a list: empty or from a saved list, an optional name, when it starts (now, at the next reset, or a time
/// you pick) and how long it lasts (4 hours to 3 days, a time you pick, or no end).
struct NewListSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    /// The saved list to start from, when opened by tapping one on the first screen.
    var startFrom: String? = nil
    let onCreate: (String) -> Void

    @State private var fromID: String?
    @State private var prepared = false

    enum Start: Hashable { case now, nextReset, custom }
    enum Length: Hashable { case untilReset, hours(Int), custom, noEnd }

    @State private var name = ""
    @State private var start = Start.now
    @State private var customStart = Date.now.addingTimeInterval(3600)
    @State private var length = Length.untilReset
    @State private var customEnd = Date.now.addingTimeInterval(86_400)

    private var settings: TodoSettings { model.data.settings }

    private var startDate: Date {
        switch start {
        case .now: return .now
        case .nextReset: return settings.nextReset(after: .now)
        case .custom: return customStart
        }
    }

    private var resetTime: String {
        settings.nextReset(after: .now).formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !model.data.saved.isEmpty {
                    Section("Start from") {
                        Picker("Start from", selection: $fromID) {
                            Text("Empty").tag(String?.none)
                            ForEach(model.data.saved) { saved in
                                Text("\(saved.name) (\(saved.items.count))").tag(Optional(saved.id))
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                        .onChange(of: fromID) { _, id in
                            if let saved = model.data.saved.first(where: { $0.id == id }) { name = saved.name }
                        }
                    }
                }
                Section("Name") {
                    TextField("Optional, e.g. Shopping", text: $name)
                }
                Section("Starts") {
                    Picker("Starts", selection: $start) {
                        Text("Now").tag(Start.now)
                        Text("At \(resetTime)").tag(Start.nextReset)
                        Text("Pick a time").tag(Start.custom)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    if start == .custom {
                        DatePicker("Starts", selection: $customStart, in: Date.now...)
                    }
                }
                Section("Lasts") {
                    Picker("Lasts", selection: $length) {
                        Text("Until \(resetTime)").tag(Length.untilReset)
                        Text("4 hours").tag(Length.hours(4))
                        Text("12 hours").tag(Length.hours(12))
                        Text("24 hours").tag(Length.hours(24))
                        Text("3 days").tag(Length.hours(72))
                        Text("Pick an end").tag(Length.custom)
                        Text("No end").tag(Length.noEnd)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    if length == .custom {
                        DatePicker("Ends", selection: $customEnd, in: startDate...)
                    }
                }
            }
            .navigationTitle("New list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                }
            }
        }
        .onAppear {
            guard !prepared else { return }
            prepared = true
            if let startFrom, let saved = model.data.saved.first(where: { $0.id == startFrom }) {
                fromID = saved.id
                name = saved.name
            }
        }
    }

    private func create() {
        let begins = startDate
        let ends: Date?
        switch length {
        case .untilReset: ends = settings.nextReset(after: begins.addingTimeInterval(60))
        case .hours(let hours): ends = begins.addingTimeInterval(Double(hours) * 3600)
        case .custom: ends = max(customEnd, begins.addingTimeInterval(60))
        case .noEnd: ends = nil
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let items = model.data.saved.first(where: { $0.id == fromID })?.freshItems ?? []
        let id = model.newList(name: trimmed.isEmpty ? nil : trimmed, start: begins, end: ends, items: items)
        dismiss()
        onCreate(id)
    }
}
