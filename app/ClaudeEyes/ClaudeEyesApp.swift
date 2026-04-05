import SwiftUI

@main
struct ClaudeEyesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty settings scene — everything runs from the menu bar
        Settings {
            EmptyView()
        }
    }
}
