import SwiftUI

/// The fonts to choose from: Apple's own text styles plus fonts that come with every iPhone.
enum FontChoice: String, Codable, CaseIterable, Identifiable {
    case system, rounded, serif, mono, avenir, futura, georgia, typewriter, marker, noteworthy, chalkboard, handwriting

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Normal"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .mono: return "Mono"
        case .avenir: return "Avenir"
        case .futura: return "Futura"
        case .georgia: return "Georgia"
        case .typewriter: return "Typewriter"
        case .marker: return "Marker"
        case .noteworthy: return "Noteworthy"
        case .chalkboard: return "Chalkboard"
        case .handwriting: return "Handwriting"
        }
    }

    func font(size: CGFloat) -> Font {
        switch self {
        case .system: return .system(size: size, weight: .medium)
        case .rounded: return .system(size: size, weight: .medium, design: .rounded)
        case .serif: return .system(size: size, weight: .medium, design: .serif)
        case .mono: return .system(size: size, weight: .medium, design: .monospaced)
        case .avenir: return .custom("AvenirNext-Medium", fixedSize: size)
        case .futura: return .custom("Futura-Medium", fixedSize: size)
        case .georgia: return .custom("Georgia", fixedSize: size)
        case .typewriter: return .custom("AmericanTypewriter", fixedSize: size)
        case .marker: return .custom("MarkerFelt-Wide", fixedSize: size)
        case .noteworthy: return .custom("Noteworthy-Bold", fixedSize: size)
        case .chalkboard: return .custom("ChalkboardSE-Regular", fixedSize: size)
        case .handwriting: return .custom("SnellRoundhand-Bold", fixedSize: size)
        }
    }
}

/// The colours a to-do can have (0 = the normal text colour).
enum Palette {
    static let colors: [Color] = [.primary, .red, .orange, .yellow, .green, .mint, .blue, .purple, .pink]

    static func color(_ index: Int) -> Color {
        colors.indices.contains(index) ? colors[index] : .primary
    }
}

/// Sizes that follow the text size, so bigger text gets bigger circles and taller rows (easier to hit).
extension TextLook {
    var swiftUIFont: Font { font.font(size: size) }
    var circle: CGFloat { (size * 1.3).rounded() }
    /// A row on a Home Screen widget.
    var row: Double { max(28, (size * 2.05).rounded()) }
    /// A row on the Lock Screen card, which Apple caps at 160 points tall.
    var cardRow: Double { max(24, (size * 1.65).rounded()) }
}

enum CardLayout {
    /// Room for rows on the Lock Screen card (160 points minus the top line and the padding).
    static let rowsHeight = 120.0
    /// Room for rows in the Dynamic Island when it's opened.
    static let islandHeight = 96.0
}
