import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var report = Report.text()
    @State private var log = Log.lines
    @State private var copied = false

    var body: some View {
        Form {
            Section {
                Text("Go for a run")
                    .font(model.data.settings.text.swiftUIFont)
                    .lineLimit(1)
                SizeSlider(size: $model.data.settings.text.size)
                FontChips(selection: Binding(
                    get: { model.data.settings.text.font },
                    set: { model.data.settings.text.font = $0 ?? .system }
                ))
            } header: {
                Text("Text")
            } footer: {
                Text("For every to-do that doesn't have its own font or size. Bigger text fits fewer to-dos on a widget.")
            }

            Section {
                DatePicker("New list at", selection: time(\.resetMinutes), displayedComponents: .hourAndMinute)
            } header: {
                Text("Daily reset")
            } footer: {
                Text("Lists end at this time unless you pick another length, and you get a notification to make the next one.")
            }

            Section {
                Toggle("Remind me to plan the next list", isOn: $model.data.settings.planReminder)
                if model.data.settings.planReminder {
                    DatePicker("At", selection: time(\.planMinutes), displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Plan ahead")
            }

            Section {
                Toggle("Keep the card on the Lock Screen", isOn: $model.data.settings.keepCard)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brightness")
                    HStack(spacing: 12) {
                        Image(systemName: "moon.fill").foregroundStyle(.secondary)
                        Slider(value: $model.data.settings.card.shade, in: -0.3...0.45, step: 0.05)
                        Image(systemName: "sun.max.fill").foregroundStyle(.secondary)
                    }
                }
                Toggle("See-through (no frosted glass)", isOn: $model.data.settings.card.seeThrough)
                Toggle("Its own text size", isOn: Binding(
                    get: { model.data.settings.card.size != nil },
                    set: { model.data.settings.card.size = $0 ? 14 : nil }
                ))
                if let size = model.data.settings.card.size {
                    SizeSlider(size: Binding(get: { size }, set: { model.data.settings.card.size = $0 }))
                }
                Button("Renew the card now") {
                    let data = model.data
                    Task { await LiveCard.sync(data, from: "app", forceRenew: true) }
                }
            } header: {
                Text("Lock Screen card")
            } footer: {
                Text("Lock the phone to see changes. Apple keeps the card to a fixed height (about a fifth of the screen), so smaller text fits more to-dos: about 4 at 17, 5 at 14, 6 at 12. Apple also removes a card 8 hours after it appears, so it renews itself whenever you tick something or open the app.")
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
        .navigationTitle("Settings")
        .onChange(of: model.data.settings) { _, _ in
            model.commit()
        }
    }

    /// A time of day for a DatePicker, kept as minutes after midnight.
    private func time(_ key: WritableKeyPath<TodoSettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = model.data.settings[keyPath: key]
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                model.data.settings[keyPath: key] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}
