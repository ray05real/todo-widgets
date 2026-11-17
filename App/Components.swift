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

/// "Its own size" for a to-do (when adding one, or while changing one) and, once on, its size slider. Off (nil) = the
/// size in Settings.
struct OwnSizeToggle: View {
    @Binding var size: Double?
    let defaultSize: Double

    var body: some View {
        Toggle("Its own size", isOn: Binding(
            get: { size != nil },
            set: { size = $0 ? defaultSize : nil }
        ))
        if let size {
            SizeSlider(size: Binding(get: { size }, set: { self.size = $0 }))
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
