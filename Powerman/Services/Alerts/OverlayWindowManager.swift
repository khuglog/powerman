import AppKit
import SwiftUI

@MainActor
protocol AlertPresenting: AnyObject {
    var activeAlert: ActiveAlertPresentation? { get }
    func present(
        _ alert: ActiveAlertPresentation,
        bubbleSize: AlertBubbleSize,
        glowIntensity: ScreenEdgeGlowIntensity,
        onDismiss: (() -> Void)?
    )
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

    func present(
        _ alert: ActiveAlertPresentation,
        bubbleSize: AlertBubbleSize = .default,
        glowIntensity: ScreenEdgeGlowIntensity = .default,
        onDismiss: (() -> Void)? = nil
    ) {
        dismiss(notifyCallback: false)

        self.activeAlert = alert
        self.dismissCallback = onDismiss

        if alert.borderGlow {
            showBorderGlow(for: alert, intensity: glowIntensity)
        }

        if alert.showPopup {
            showFloatingPopup(for: alert, bubbleSize: bubbleSize)
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

    private func showBorderGlow(for alert: ActiveAlertPresentation, intensity: ScreenEdgeGlowIntensity) {
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
            panel.isReleasedWhenClosed = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.contentViewController = NSHostingController(
                rootView: ScreenBorderGlowView(
                    color: alert.color,
                    persistent: alert.persistent,
                    edgeThickness: intensity.edgeThickness,
                    opacityMultiplier: intensity.opacityMultiplier
                )
            )
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            glowWindows.append(panel)
        }
    }

    private func showFloatingPopup(for alert: ActiveAlertPresentation, bubbleSize: AlertBubbleSize) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let bubbleView = FloatingAlertBubbleView(alert: alert, bubbleSize: bubbleSize) { [weak self] in
            self?.dismiss()
        }

        let hosting = NSHostingController(rootView: bubbleView)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.view.layer?.isOpaque = false

        let fittingSize = hosting.sizeThatFits(in: NSSize(width: 600, height: 200))
        let panelWidth = max(300 * bubbleSize.scale, fittingSize.width)
        let panelHeight = max(50 * bubbleSize.scale, fittingSize.height)

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
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentViewController = hosting
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView?.layer?.isOpaque = false
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        self.popupPanel = panel
    }
}
