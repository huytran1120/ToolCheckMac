import SwiftUI

@main
struct ToolCheckMacBookApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 720, minHeight: 520)
        }
        .windowResizability(.automatic)
        .defaultSize(width: 1040, height: 720)
    }
}
