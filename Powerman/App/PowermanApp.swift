import SwiftUI

@main
struct PowermanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsRootView(appState: appDelegate.appState)
        }
    }
}
