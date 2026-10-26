import ActivityKit
import SwiftUI
import WidgetKit

/// The Lock Screen card (sits with the notifications) and its Dynamic Island versions.
struct TodoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodoActivityAttributes.self) { context in
            LockScreenCard(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.title, systemImage: "checklist")
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let end = context.state.end, !context.isStale {
                        Text(end, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CardRows(state: context.state, height: CardLayout.islandHeight, source: "Dynamic Island")
                }
            } compactLeading: {
                Image(systemName: "checklist").foregroundStyle(Color.green)
            } compactTrailing: {
                Text("\(context.state.left)").foregroundStyle(Color.green)
            } minimal: {
                Text("\(context.state.left)").foregroundStyle(Color.green)
            }
        }
    }
}

/// The card's tick rows: as many of the card's to-dos as fit in `height`.
struct CardRows: View {
    let state: TodoActivityAttributes.ContentState
    let height: Double
    let source: String

    var body: some View {
        let shown = TodoList(id: state.listID ?? "", start: .now, items: state.items)
            .window(height: height) { state.look.applied(to: $0).cardRow }
        VStack(alignment: .leading, spacing: 0) {
            ForEach(shown.items) { item in
                let look = state.look.applied(to: item)
                Toggle(isOn: item.done, intent: ToggleItemIntent(listID: state.listID ?? "", itemID: item.id, source: source)) {
                    Text(item.title)
                }
                .toggleStyle(CheckToggleStyle(look: look, color: item.color))
                .frame(height: look.cardRow)
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
                Image(systemName: "checklist")
                Text(state.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                if state.total > state.items.count {
                    Text("\(state.first + 1)–\(state.first + state.items.count) of \(state.total)")
                }
                Spacer(minLength: 6)
                if let end = state.end, !context.isStale {
                    Image(systemName: "hourglass")
                    Text(end, style: .relative)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 96, alignment: .trailing)
                }
                Button(intent: RenewCardIntent()) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(height: 18)

            if context.isStale || state.listID == nil {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.nextReady ? "Your next list is ready" : (state.listID == nil ? "No list right now" : "\(state.title) has ended"))
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
