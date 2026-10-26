import SwiftUI

/// A circle that fills with a tick, then the to-do's text (crossed out once ticked).
struct CheckToggleStyle: ToggleStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: compact ? 5 : 8) {
            Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: compact ? 14 : 18))
                .foregroundStyle(configuration.isOn ? Color.green : Color.secondary)
            configuration.label
                .font(.system(size: compact ? 13 : 14))
                .strikethrough(configuration.isOn)
                .foregroundStyle(configuration.isOn ? Color.secondary : Color.primary)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
