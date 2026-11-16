import AppKit
import SwiftUI

@MainActor
protocol AlertPresenting: AnyObject {
    var activeAlert: ActiveAlertPresentation? { get }
    func present(_ alert: ActiveAlertPresentation, onDismiss: (() -> Void)?)
    func dismiss()
}

@MainActor
final class OverlayWindowManager: AlertPresenting {
    private(set) var activeAlert: ActiveAlertPresentation?

    private let soundPlayer: SoundPlaying
    private var glowWindows: [NSWindow] = []
    private var popupPanel: NSPanel?
    private var autoDismissTask: Task<Void, Never>?
    private var dismissCallback: (() -> Void)?

    init(soundPlayer: SoundPlaying = SystemSoundPlayer()) {
        self.soundPlayer = soundPlayer
    }

    func present(_ alert: ActiveAlertPresentation, onDismiss: (() -> Void)? = nil) {
        dismiss(notifyCallback: false)

        self.activeAlert = alert
        self.dismissCallback = onDismiss

        if alert.borderGlow {
            showBorderGlow(for: alert)
        }

        if alert.showPopup {
            showFloatingPopup(for: alert)
        }

        if alert.sound != .none {
            soundPlayer.play(sound: alert.sound, repeating: alert.persistent)
        }

        if !alert.persistent {
            autoDismissTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(4.5))
                guard !Task.isCancelled else { return }
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        dismiss(notifyCallback: true)
    }

    private func dismiss(notifyCallback: Bool) {
        autoDismissTask?.cancel()
        autoDismissTask = nil

        soundPlayer.stop()

        for window in glowWindows {
            window.orderOut(nil)
            window.close()
        }
        glowWindows.removeAll()

        popupPanel?.orderOut(nil)
        popupPanel?.close()
        popupPanel = nil

        let wasActive = activeAlert != nil
        activeAlert = nil

        if notifyCallback && wasActive {
            let cb = dismissCallback
            dismissCallback = nil
            cb?()
        } else {
            dismissCallback = nil
        }
    }

    private func showBorderGlow(for alert: ActiveAlertPresentation) {
        for screen in NSScreen.screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.contentViewController = NSHostingController(
                rootView: ScreenBorderGlowView(color: alert.color, persistent: alert.persistent)
            )
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            glowWindows.append(panel)
        }
    }

    private func showFloatingPopup(for alert: ActiveAlertPresentation) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let bubbleView = FloatingAlertBubbleView(alert: alert) { [weak self] in
            self?.dismiss()
        }

        let hosting = NSHostingController(rootView: bubbleView)
        let fittingSize = hosting.sizeThatFits(in: NSSize(width: 400, height: 120))
        let panelWidth = max(310, fittingSize.width)
        let panelHeight = max(62, fittingSize.height)

        let originX = screen.frame.midX - (panelWidth / 2.0)
        let originY: CGFloat
        switch alert.position {
        case .topOfScreen:
            originY = screen.visibleFrame.maxY - panelHeight - 16
        case .centerOfScreen:
            originY = screen.visibleFrame.midY - (panelHeight / 2.0)
        }

        let frame = NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight)
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentViewController = hosting
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        self.popupPanel = panel
    }
}
