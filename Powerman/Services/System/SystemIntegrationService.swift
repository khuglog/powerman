import AppKit
import ApplicationServices
import Foundation
import ServiceManagement

@MainActor
protocol SystemIntegrating: AnyObject {
    var isLaunchAtLoginEnabled: Bool { get }
    var launchAtLoginRequiresApproval: Bool { get }
    var isAccessibilityGranted: Bool { get }
    var isLowPowerModeEnabled: Bool { get }

    func setLaunchAtLogin(_ enabled: Bool) -> String?
    func applyAppearance(_ appearance: AppAppearanceOption)
    func requestAccessibilityPermission()
    func startLowPowerObserver(onChange: @escaping @MainActor @Sendable (Bool) -> Void)
    func stopLowPowerObserver()
    func setLowPowerMode(_ enabled: Bool, restoreBrightness: Bool) async -> Bool
    func startNotificationDismisser()
    func stopNotificationDismisser()
}

@MainActor
final class MacSystemIntegrationService: SystemIntegrating {
    private var powerObserver: NSObjectProtocol?
    private var dismisserTimer: Timer?
    private var savedBrightnessBeforeLowPower: Float?

    var isLaunchAtLoginEnabled: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled
    }

    var launchAtLoginRequiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    var isLowPowerModeEnabled: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    func setLaunchAtLogin(_ enabled: Bool) -> String? {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                    try SMAppService.mainApp.unregister()
                }
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func applyAppearance(_ appearance: AppAppearanceOption) {
        switch appearance {
        case .auto:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func startLowPowerObserver(onChange: @escaping @MainActor @Sendable (Bool) -> Void) {
        stopLowPowerObserver()
        powerObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                onChange(ProcessInfo.processInfo.isLowPowerModeEnabled)
            }
        }
    }

    func stopLowPowerObserver() {
        if let powerObserver {
            NotificationCenter.default.removeObserver(powerObserver)
            self.powerObserver = nil
        }
    }

    func setLowPowerMode(_ enabled: Bool, restoreBrightness: Bool) async -> Bool {
        if enabled && restoreBrightness {
            savedBrightnessBeforeLowPower = Self.readMainDisplayBrightness()
        }

        let targetValue = enabled ? 1 : 0
        let succeeded = await Task.detached(priority: .userInitiated) {
            Self.runPrivilegedPmsetLowPowerMode(targetValue)
        }.value

        if succeeded && !enabled && restoreBrightness, let saved = savedBrightnessBeforeLowPower {
            Self.setMainDisplayBrightness(saved)
            savedBrightnessBeforeLowPower = nil
        }
        return succeeded
    }

    func startNotificationDismisser() {
        stopNotificationDismisser()
        dismisserTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissBatteryNotificationsIfPresent()
            }
        }
    }

    func stopNotificationDismisser() {
        dismisserTimer?.invalidate()
        dismisserTimer = nil
    }

    private func dismissBatteryNotificationsIfPresent() {
        guard AXIsProcessTrusted() else { return }
        guard let ncApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.notificationcenterui"
        }) else {
            return
        }

        let appElement = AXUIElementCreateApplication(ncApp.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return
        }

        for window in windows {
            let texts = collectStaticTexts(in: window, maxDepth: 6)
            let isBatteryWarning = texts.contains { text in
                let lower = text.lowercased()
                return lower.contains("low battery")
                    || lower.contains("your mac will sleep soon")
                    || lower.contains("pin yếu")
                    || lower.contains("reserve battery power")
            }

            if isBatteryWarning {
                _ = pressCloseButton(in: window, maxDepth: 6)
            }
        }
    }

    private func collectStaticTexts(in element: AXUIElement, maxDepth: Int) -> [String] {
        guard maxDepth > 0 else { return [] }
        var results: [String] = []

        var valueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
           let str = valueRef as? String, !str.isEmpty {
            results.append(str)
        }
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success,
           let str = titleRef as? String, !str.isEmpty {
            results.append(str)
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                results.append(contentsOf: collectStaticTexts(in: child, maxDepth: maxDepth - 1))
            }
        }
        return results
    }

    private func pressCloseButton(in element: AXUIElement, maxDepth: Int) -> Bool {
        guard maxDepth > 0 else { return false }

        var actionsRef: CFArray?
        if AXUIElementCopyActionNames(element, &actionsRef) == .success,
           let actions = actionsRef as? [String],
           actions.contains(kAXPressAction as String) {
            var descRef: CFTypeRef?
            var titleRef: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
            _ = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
            let label = ((descRef as? String) ?? (titleRef as? String) ?? "").lowercased()
            if label.contains("close") || label.contains("dismiss") || label.contains("đóng") {
                return AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
            }
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if pressCloseButton(in: child, maxDepth: maxDepth - 1) {
                    return true
                }
            }
        }
        return false
    }

    private nonisolated static func runPrivilegedPmsetLowPowerMode(_ value: Int) -> Bool {
        let scriptSource = "do shell script \"/usr/bin/pmset -a lowpowermode \(value)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", scriptSource]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func readMainDisplayBrightness() -> Float? {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let sym = dlsym(handle, "DisplayServicesGetBrightness") else {
            return nil
        }
        typealias Fn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
        let fn = unsafeBitCast(sym, to: Fn.self)
        var brightness: Float = 0
        let status = fn(CGMainDisplayID(), &brightness)
        return status == 0 ? brightness : nil
    }

    private static func setMainDisplayBrightness(_ value: Float) {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let sym = dlsym(handle, "DisplayServicesSetBrightness") else {
            return
        }
        typealias Fn = @convention(c) (CGDirectDisplayID, Float) -> Int32
        let fn = unsafeBitCast(sym, to: Fn.self)
        _ = fn(CGMainDisplayID(), min(max(value, 0.05), 1.0))
    }
}
