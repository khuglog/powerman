import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var menuBarController: MenuBarController?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState.onOpenSettings = { [weak self] in
            self?.showSettingsWindow()
        }
        appState.onQuitApp = {
            NSApp.terminate(nil)
        }

        appState.start()
        menuBarController = MenuBarController(appState: appState)
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.stop()
        menuBarController?.tearDown()
    }

    func showSettingsWindow() {
        if settingsWindow == nil {
            let rootView = SettingsRootView(appState: appState)
            let hostingController = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Powerman"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 820, height: 600))
            window.center()
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = false
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
