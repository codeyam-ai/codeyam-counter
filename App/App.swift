import SwiftUI
import AppCore

@main
struct SwiftUIApp: App {
    var body: some Scene {
        WindowGroup {
            // codeyam component isolation: when CODEYAM_ISOLATE_COMPONENT is set
            // (via a component scenario's deviceState.launchEnv) the app boots
            // straight into that View in isolation; otherwise it renders normally.
            CodeyamIsolationHost.root() ?? AnyView(ContentView())
        }
    }
}
