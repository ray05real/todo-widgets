import SwiftUI
import WidgetKit

@main
struct TodoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodoWidget()
        TodoLiveActivity()
    }
}
