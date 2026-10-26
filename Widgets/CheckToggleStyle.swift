import SwiftUI

/// A circle that fills with a tick, then the to-do's text (crossed out once ticked), in the to-do's colour, font and
/// size. The whole row is the tap target.
struct CheckToggleStyle: ToggleStyle {
    var look: TextLook
    var color = 0

    func makeBody(configuration: Configuration) -> some View {
        let tint = Palette.color(color)
        return HStack(spacing: 8) {
            Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: look.circle))
                .foregroundStyle(tint.opacity(configuration.isOn ? 0.55 : 0.9))
            configuration.label
                .font(look.swiftUIFont)
                .lineLimit(1)
                .strikethrough(configuration.isOn)
                .foregroundStyle(tint.opacity(configuration.isOn ? 0.45 : 1))
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}
