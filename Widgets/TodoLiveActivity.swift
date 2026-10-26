import ActivityKit
import SwiftUI
import WidgetKit

/// The Lock Screen card (sits with the notifications) and its Dynamic Island versions.
struct TodoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodoActivityAttributes.self) { context in
            // Any background tint turns Apple's own card glass off, so it's only set for the other looks.
            if context.state.card.style == .standard {
                LockScreenCard(context: context)
            } else {
                LockScreenCard(context: context)
                    .activityBackgroundTint(Color.clear)
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
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

/// "resets in 2 hrs, 13 min", counting down by itself.
struct Countdown: View {
    let end: Date

    var body: some View {
        (Text("resets in ") + Text(end, style: .relative))
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
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
            HStack(spacing: 5) {
                Text(state.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                if state.total > state.items.count {
                    Text("\(state.first + 1)–\(state.first + state.items.count) of \(state.total)")
                }
                Spacer(minLength: 6)
                if let end = state.end, state.showCountdown, !context.isStale {
                    Countdown(end: end)
                        .frame(maxWidth: 170, alignment: .trailing)
                }
                if state.card.showRenew {
                    Button(intent: RenewCardIntent()) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(height: 16)

            if context.isStale || state.listID == nil {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.nextReady ? "Your next list is ready" : (state.listID == nil ? "No list right now" : "This list has ended"))
                        .font(.system(size: 17, weight: .semibold))
                    Text(state.nextReady ? "Tap to show it here." : "Tap to make your next list.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            } else if state.items.isEmpty {
                Text("Nothing on this list yet. Tap to add some.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            } else {
                CardRows(state: state, height: CardLayout.rowsHeight, source: "Lock Screen card")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background { CardBackground(card: state.card) }
    }
}

/// Behind the card: iOS 26's Liquid Glass for the glass looks, then the light or dark wash.
struct CardBackground: View {
    let card: CardSettings

    var body: some View {
        ZStack {
            if card.style == .glass || card.style == .clearGlass {
                if #available(iOS 26.0, *) {
                    Rectangle()
                        .fill(Color.clear)
                        .glassEffect(card.style == .glass ? .regular : .clear, in: Rectangle())
                }
            }
            card.shade >= 0 ? Color.white.opacity(card.shade) : Color.black.opacity(-card.shade)
        }
    }
}
