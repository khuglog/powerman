import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var menuBarController: MenuBarController?
    private var settingsWindow: NSWindow?

    private var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Avoid initializing MenuBar UI, IOKit, or Bluetooth TCC prompts when launched as a unit test host.
        guard !isRunningUnitTests else { return }

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
        guard !isRunningUnitTests else { return }
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
