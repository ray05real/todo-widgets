import SwiftUI

/// A small explanation under a section, shown only with Settings → Show tips on.
struct Tip: View {
    @EnvironmentObject private var model: AppModel
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        if model.data.settings.showTips {
            Text(text)
        }
    }
}

/// "Ends in 5 hr, 32 min" (counting down live), "Starts Tue 00:00", "Ended" or "No end".
struct TimeLabel: View {
    let list: TodoList
    let now: Date

    var body: some View {
        if list.start > now {
            Text("Starts ") + Text(list.start, format: .dateTime.weekday(.abbreviated).hour().minute())
        } else if let end = list.end {
            if end > now {
                Text("Ends in ") + Text(end, style: .relative)
            } else {
                Text("Ended")
            }
        } else {
            Text("No end")
        }
    }
}

/// A to-do in the app: tap anywhere on the row to tick it.
struct ItemRow: View {
    let item: TodoItem
    let look: TextLook
    let onTick: () -> Void

    var body: some View {
        let tint = Palette.color(item.color)
        Button(action: onTick) {
            HStack(spacing: 12) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: look.circle + 2))
                    .foregroundStyle(tint.opacity(item.done ? 0.55 : 0.9))
                Text(item.title)
                    .font(look.swiftUIFont)
                    .strikethrough(item.done)
                    .foregroundStyle(tint.opacity(item.done ? 0.45 : 1))
                Spacer(minLength: 0)
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The colours to pick from.
struct ColorDots: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 9) {
            ForEach(Palette.colors.indices, id: \.self) { i in
                Circle()
                    .fill(Palette.colors[i])
                    .frame(width: 24, height: 24)
                    .overlay {
                        if i == selection {
                            Circle().stroke(Color.accentColor, lineWidth: 2.5).padding(-4)
                        }
                    }
                    .contentShape(Circle())
                    .onTapGesture { selection = i }
            }
        }
        .padding(.vertical, 6)
    }
}

/// The fonts to pick from, each written in itself. With `sameAsList`, the first chip means "no font of its own".
struct FontChips: View {
    @Binding var selection: FontChoice?
    var sameAsList = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if sameAsList {
                    chip(nil, label: "Same as list")
                }
                ForEach(FontChoice.allCases) { choice in
                    chip(choice, label: choice.label)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func chip(_ choice: FontChoice?, label: String) -> some View {
        let picked = selection == choice
        return Text(label)
            .font((choice ?? .system).font(size: 16))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(picked ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(picked ? Color.accentColor : Color.clear, lineWidth: 1.5))
            .contentShape(Capsule())
            .onTapGesture { selection = choice }
    }
}

/// Changing one to-do: its words, colour, font and size, or deleting it.
struct ItemEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let listID: String
    @State var item: TodoItem

    var body: some View {
        let look = model.data.settings.text.applied(to: item)
        NavigationStack {
            Form {
                Section {
                    TextField("To-do", text: $item.title, axis: .vertical)
                        .font(look.swiftUIFont)
                        .foregroundStyle(Palette.color(item.color))
                }
                Section("Colour") {
                    ColorDots(selection: $item.color)
                }
                Section("Font") {
                    FontChips(selection: $item.font, sameAsList: true)
                }
                Section {
                    Toggle("Its own size", isOn: Binding(
                        get: { item.size != nil },
                        set: { item.size = $0 ? model.data.settings.text.size : nil }
                    ))
                    if let size = item.size {
                        SizeSlider(size: Binding(get: { size }, set: { item.size = $0 }))
                    }
                } header: {
                    Text("Size")
                } footer: {
                    Tip("Otherwise it uses the size in Settings.")
                }
                Section {
                    Button("Delete to-do", role: .destructive) {
                        model.edit(listID) { list in list.items.removeAll { $0.id == item.id } }
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit to-do")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let edited = item
                        model.edit(listID) { list in
                            if let i = list.items.firstIndex(where: { $0.id == edited.id }) { list.items[i] = edited }
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

/// A font size in points, like Word's size box.
struct SizeSlider: View {
    @Binding var size: Double
    var range: ClosedRange<Double> = 12...32

    var body: some View {
        HStack(spacing: 12) {
            Text("A").font(.system(size: 12))
            Slider(value: $size, in: range, step: 1)
            Text("A").font(.system(size: 24))
            Text("\(Int(size))")
                .monospacedDigit()
                .frame(width: 28, alignment: .trailing)
        }
    }
}

/// Small marks under a slider, one per step (the middle one taller), so you can see where each step is.
struct StepMarks: View {
    let count: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { i in
                Rectangle()
                    .fill(Color.secondary)
                    .frame(width: 1.5, height: i == count / 2 ? 9 : 5)
                if i < count - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
        // The slider's knob stops half its width short of each end of the track.
        .padding(.horizontal, 13)
    }
}
