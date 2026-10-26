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
                    Label(context.attributes.listName, systemImage: "checklist")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.left) left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(context.state.items.prefix(3)) { item in
                            Toggle(isOn: item.done, intent: ToggleItemIntent(itemID: item.id, source: "Dynamic Island")) {
                                Text(item.title).lineLimit(1)
                            }
                            .toggleStyle(CheckToggleStyle())
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "checklist").foregroundStyle(.green)
            } compactTrailing: {
                Text("\(context.state.left)").foregroundStyle(.green)
            } minimal: {
                Text("\(context.state.left)").foregroundStyle(.green)
            }
        }
    }
}

struct LockScreenCard: View {
    let context: ActivityViewContext<TodoActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(context.attributes.listName, systemImage: "checklist")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(context.state.left) left")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            ForEach(context.state.items) { item in
                Toggle(isOn: item.done, intent: ToggleItemIntent(itemID: item.id, source: "Lock Screen card")) {
                    Text(item.title).lineLimit(1)
                }
                .toggleStyle(CheckToggleStyle(compact: true))
            }
            HStack {
                Text("Card started \(context.attributes.startedAt.formatted(date: .omitted, time: .shortened))")
                Spacer()
                Button(intent: RenewCardIntent()) {
                    Text("Renew")
                }
                .tint(.green)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
