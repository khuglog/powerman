import AppKit
import Observation
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var eventMonitor: Any?
    private var appearanceObservation: NSKeyValueObservation?
    private var themeObserver: NSObjectProtocol?

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        appState.onDismissPopover = { [weak self] in
            self?.closePopover(nil)
        }

        setupPopover()
        setupStatusButton()
        observeAppearanceChanges()
        observeStateChanges()
        updateStatusItemIcon()
    }

    func tearDown() {
        removeEventMonitor()
        if let themeObserver {
            DistributedNotificationCenter.default().removeObserver(themeObserver)
            self.themeObserver = nil
        }
        appearanceObservation?.invalidate()
        appearanceObservation = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let hosting = NSHostingController(rootView: MenuBarPopoverView(appState: appState))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
    }

    private func setupStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func observeAppearanceChanges() {
        if let button = statusItem.button {
            appearanceObservation = button.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.updateStatusItemIcon()
                }
            }
        }

        themeObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStatusItemIcon()
            }
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        appState.refreshBattery()
        appState.refreshDevices()
        appState.refreshEnergyConsumers()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)

        removeEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePopover(nil)
            }
        }
    }

    private func closePopover(_ sender: Any?) {
        popover.performClose(sender)
        removeEventMonitor()
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        removeEventMonitor()
    }

    private func observeStateChanges() {
        withObservationTracking {
            _ = appState.batteryInfo
            _ = appState.bluetoothDevices
            _ = appState.settings.devicePreferences
            _ = appState.settings.menuBarIconStyle
            _ = appState.settings.menuBarDisplayMode
            _ = appState.settings.menuBarColorMode
            _ = appState.settings.menuBarSize
            _ = appState.settings.statusColorsEnabled
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateStatusItemIcon()
                self.observeStateChanges()
            }
        }
    }

    private func updateStatusItemIcon() {
        guard let button = statusItem.button else { return }
        let settings = appState.settings
        let isDarkMenuBar = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let useTemplate = (settings.menuBarColorMode == .monochrome)
        let effectiveDark = switch settings.menuBarColorMode {
        case .white: true
        case .black: false
        case .auto, .monochrome: isDarkMenuBar
        }

        let iconView = MenuBarIconView(
            battery: appState.batteryInfo,
            pinnedDevices: appState.pinnedMenuBarDevices,
            style: settings.menuBarIconStyle,
            displayMode: settings.menuBarDisplayMode,
            colorMode: settings.menuBarColorMode,
            size: settings.menuBarSize,
            statusColorsEnabled: settings.statusColorsEnabled,
            isDarkMenuBar: effectiveDark,
            isTemplateMode: useTemplate
        )
        .environment(\.colorScheme, effectiveDark ? .dark : .light)

        let renderer = ImageRenderer(content: iconView)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0

        if let nsImage = renderer.nsImage {
            nsImage.isTemplate = useTemplate
            button.image = nsImage
            button.title = ""
        } else {
            button.title = "\(appState.batteryInfo.percentage)%"
        }
    }
}
