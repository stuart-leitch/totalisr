import SwiftUI
import SwiftData

@main
struct TotalisrApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [TotalList.self, Item.self])
        #if os(macOS)
        .defaultSize(width: 900, height: 620)
        .commands { SidebarCommands() }
        #endif
    }
}
