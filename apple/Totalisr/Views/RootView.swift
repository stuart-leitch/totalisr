import SwiftUI
import SwiftData

/// Lists on the left, the selected list's items on the right. On iPhone the split view
/// collapses to a push/pop stack; on iPad and Mac it stays side by side.
struct RootView: View {
    @State private var selection: TotalList?

    var body: some View {
        NavigationSplitView {
            ListsSidebar(selection: $selection)
        } detail: {
            if let selection {
                ItemsView(list: selection)
                    // Rebuild the detail column when the selected list changes, so
                    // per-list view state (quick-add fields, edit mode) doesn't leak
                    // from one list into the next.
                    .id(selection.persistentModelID)
            } else {
                ContentUnavailableView("No List Selected", systemImage: "list.bullet.rectangle", description: Text("Pick a list, or create one."))
            }
        }
    }
}
