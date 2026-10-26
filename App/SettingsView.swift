import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

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
                Toggle("Show the card on the Lock Screen", isOn: $model.data.settings.keepCard)
                Toggle("Show the count in the Dynamic Island", isOn: $model.data.settings.card.showInIsland)
                Toggle("Show the countdown", isOn: $model.data.settings.showCountdown)
            } header: {
                Text("Where it shows")
            } footer: {
                Text("The countdown (bottom right of the card) is how long until your list resets. The card also shows when you pull down from the top of the Home Screen: that's the Lock Screen too, and Apple doesn't let apps show it in one and not the other. Widgets are added and removed on the Home Screen and Lock Screen themselves: press and hold, then Edit or Remove.")
            }

            Section {
                Picker("Look", selection: $model.data.settings.card.style) {
                    ForEach(CardStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brightness (\(model.data.settings.card.style.label))")
                    HStack(spacing: 12) {
                        Image(systemName: "moon.fill").foregroundStyle(.secondary)
                        VStack(spacing: 2) {
                            // Each look remembers its own brightness.
                            Slider(value: $model.data.settings.card.currentShade, in: -0.25...0.25, step: 0.05)
                            StepMarks(count: 11)
                        }
                        Image(systemName: "sun.max.fill").foregroundStyle(.secondary)
                    }
                }
                Picker("Columns", selection: $model.data.settings.card.columns) {
                    Text("1 column").tag(1)
                    Text("2 columns").tag(2)
                }
                .pickerStyle(.segmented)
                Toggle("Its own text size", isOn: Binding(
                    get: { model.data.settings.card.size != nil },
                    set: { model.data.settings.card.size = $0 ? 14 : nil }
                ))
                if let size = model.data.settings.card.size {
                    SizeSlider(size: Binding(get: { size }, set: { model.data.settings.card.size = $0 }), range: 9...24)
                }
            } header: {
                Text("Lock Screen card")
            } footer: {
                Text("Lock the phone to see changes. Each look keeps its own brightness. On Glass the middle mark is about as dark as your notifications and the right end is fully see-through; White is paper-white at the right end, Black solid black at the left end. Apple fixes the card's height (about a fifth of the screen), so 2 columns or smaller text fit more: about 6 a column at size 12, 7 at 10, 8 at 9. Apple also removes a card after 8 hours; it puts itself back whenever you tick something or open the app.")
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
