import ActivityKit
import SwiftUI
import WidgetKit

/// The Lock Screen card (sits with the notifications) and its Dynamic Island versions.
struct TodoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodoActivityAttributes.self) { context in
            // Apple's own card glass turns light or dark with the wallpaper behind it (cream over a light wallpaper,
            // so it never matched the notifications), so the card always gets a tint of its own instead.
            if context.state.card.style == .white {
                LockScreenCard(context: context)
                    .environment(\.colorScheme, .light)
                    .activityBackgroundTint(CardTint.color(for: context.state.card))
                    .activitySystemActionForegroundColor(Color.black)
            } else {
                LockScreenCard(context: context)
                    .environment(\.colorScheme, .dark)
                    .activityBackgroundTint(CardTint.color(for: context.state.card))
                    .activitySystemActionForegroundColor(Color.white)
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TitleBadge(title: context.state.title)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let end = context.state.end, context.state.showCountdown, !context.isStale {
                        Countdown(end: end)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CardRows(state: context.state, height: CardLayout.islandHeight, source: "Dynamic Island")
                }
            } compactLeading: {
                if context.state.card.showInIsland {
                    Image(systemName: "checklist").foregroundStyle(Color.green)
                }
            } compactTrailing: {
                if context.state.card.showInIsland {
                    Text("\(context.state.left)").foregroundStyle(Color.green)
                }
            } minimal: {
                if context.state.card.showInIsland {
                    Text("\(context.state.left)").foregroundStyle(Color.green)
                }
            }
        }
    }
}

/// The card's background for each look. The brightness slider runs from -0.25 (darker) to 0.25 (lighter) in 11
/// steps, remembered separately for each look:
/// - Glass: see-through black; the middle is about as dark as iOS 26's notifications, the lightest step clear.
/// - White: paper white at the lightest step, letting more of the wallpaper through as it goes darker.
/// - Black: solid black at the darkest step, letting more of the wallpaper through as it goes lighter.
enum CardTint {
    static func color(for card: CardSettings) -> Color {
        let step = min(max(card.currentShade / 0.25, -1), 1)   // -1 darkest … 0 middle … 1 lightest
        switch card.style {
        case .standard:
            return Color.black.opacity(0.32 - step * 0.32)
        case .white:
            return Color.white.opacity(0.85 + step * 0.15)
        case .black:
            return Color.black.opacity(0.85 - step * 0.15)
        }
    }
}

/// How long until the list resets ("2 hrs, 13 min"), counting down by itself.
struct Countdown: View {
    let end: Date

    var body: some View {
        Text(end, style: .relative)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }
}

/// The list's title ("TO DO") in an outlined box with rounded corners, top left.
struct TitleBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 19)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.6), lineWidth: 1.2)
            )
    }
}

/// The card's tick rows: as many of the card's to-dos as fit in `height`, in one or two columns.
struct CardRows: View {
    let state: TodoActivityAttributes.ContentState
    let height: Double
    let source: String

    var body: some View {
        let rowHeight = { (item: TodoItem) in state.look.applied(to: item).cardRow }
        let shown = TodoList(id: state.listID ?? "", start: .now, items: state.items)
            .window(height: height, columns: state.card.columns, rowHeight: rowHeight)
        let columns = shown.items.inColumns(state.card.columns, height: height, rowHeight: rowHeight)
        HStack(alignment: .top, spacing: 10) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(column) { item in
                        let look = state.look.applied(to: item)
                        Toggle(isOn: item.done, intent: ToggleItemIntent(listID: state.listID ?? "", itemID: item.id, source: source)) {
                            Text(item.title)
                        }
                        .toggleStyle(CheckToggleStyle(look: look, color: item.color))
                        .frame(height: look.cardRow)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct LockScreenCard: View {
    let context: ActivityViewContext<TodoActivityAttributes>

    var body: some View {
        let state = context.state
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                TitleBadge(title: state.title)
                if state.total > state.items.count {
                    Text("\(state.first + 1)–\(state.first + state.items.count) of \(state.total)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 21, alignment: .top)

            if context.isStale || state.listID == nil {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.nextReady ? "Your next list is ready" : (state.listID == nil ? "No list right now" : "This list has ended"))
                        .font(.system(size: 17, weight: .semibold))
                    Text(state.nextReady ? "Tap to show it here." : "Tap to make your next list.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            } else if state.items.isEmpty {
                Text("Nothing on this list yet. Tap to add some.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            } else {
                CardRows(state: state, height: CardLayout.rowsHeight, source: "Lock Screen card")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .overlay(alignment: .bottomTrailing) {
            // Centred on the last row's line, inside the same margins as the to-dos; the size and brightness of a
            // notification's "6m ago".
            if let end = state.end, state.showCountdown, !context.isStale {
                Countdown(end: end)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .frame(maxWidth: 150, alignment: .trailing)
                    .frame(height: state.look.cardRow)
                    .padding(.trailing, 14)
                    .padding(.bottom, 7)
            }
        }
    }
}
