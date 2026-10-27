import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Text(model.data.settings.text.display("Go for a run"))
                    .font(model.data.settings.text.swiftUIFont)
                    .lineLimit(1)
                SizeSlider(size: $model.data.settings.text.size)
                Picker("Letters", selection: $model.data.settings.text.letterCase) {
                    ForEach(LetterCase.allCases) { letterCase in
                        Text(letterCase.label).tag(letterCase)
                    }
                }
                .pickerStyle(.segmented)
                FontChips(selection: Binding(
                    get: { model.data.settings.text.font },
                    set: { model.data.settings.text.font = $0 ?? .system }
                ))
            } header: {
                Text("Text")
            } footer: {
                Tip("For to-dos without their own font or size.")
            }

            Section {
                DatePicker("New list at", selection: time(\.resetMinutes), displayedComponents: .hourAndMinute)
            } header: {
                Text("Daily reset")
            } footer: {
                Tip("Lists end at this time, and a notification reminds you to make the next one.")
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
                Toggle("Show cards on the Lock Screen", isOn: $model.data.settings.keepCard)
                if model.data.settings.keepCard {
                    Picker("Cards", selection: $model.data.settings.cardPerList) {
                        Text("Top list only").tag(false)
                        Text("Every list").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                Toggle("Show the count in the Dynamic Island", isOn: $model.data.settings.card.showInIsland)
                Toggle("Show the countdown", isOn: $model.data.settings.showCountdown)
                if model.data.settings.showCountdown {
                    Picker("Countdown", selection: $model.data.settings.card.timerPlace) {
                        ForEach(TimerPlace.allCases) { place in
                            Text(place.label).tag(place)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Where it shows")
            } footer: {
                Tip("Top list only: one card, for the list at the top. Every list: a card each (switch one off in its ••• menu).")
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
                Tip("Lock the phone to see changes. Apple fixes the card’s height: 2 columns or smaller text fit more.")
            }

            Section {
                Toggle("Show tips", isOn: $model.data.settings.showTips)
            }
        }
        .navigationTitle("Settings")
        .onChange(of: model.data.settings) { _, _ in
            model.commit()
        }
        .onChange(of: model.data.settings.resetMinutes) { old, new in
            // Today's list and the planned ones follow the new reset time.
            model.moveResetTimes(from: old, to: new)
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
