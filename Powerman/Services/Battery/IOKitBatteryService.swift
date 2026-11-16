import AppKit
import Foundation
import IOKit
import IOKit.ps

@MainActor
protocol BatteryMonitoring: AnyObject {
    var currentBattery: BatteryInfo { get }
    func startMonitoring(onUpdate: @escaping @MainActor (BatteryInfo) -> Void)
    func stopMonitoring()
    @discardableResult
    func refreshNow() -> BatteryInfo
}

@MainActor
final class IOKitBatteryService: BatteryMonitoring {
    private(set) var currentBattery: BatteryInfo = .placeholder

    private var iopsRunLoopSource: CFRunLoopSource?
    private var limitedPowerRunLoopSource: CFRunLoopSource?
    private var notificationPort: IONotificationPortRef?
    private var portRunLoopSource: CFRunLoopSource?
    private var interestNotifications: [io_object_t] = []
    private var wakeObserver: NSObjectProtocol?
    private var fallbackTimer: Timer?
    private var transitionConfirmTask: Task<Void, Never>?
    private var lastEmitDate: Date = .distantPast
    private var updateHandler: (@MainActor (BatteryInfo) -> Void)?

    func startMonitoring(onUpdate: @escaping @MainActor (BatteryInfo) -> Void) {
        stopMonitoring()
        self.updateHandler = onUpdate

        let initial = refreshNow()
        lastEmitDate = initial.lastUpdated
        onUpdate(initial)

        let context = Unmanaged.passUnretained(self).toOpaque()

        if let source = IOPSNotificationCreateRunLoopSource({ contextPtr in
            guard let contextPtr else { return }
            let service = Unmanaged<IOKitBatteryService>.fromOpaque(contextPtr).takeUnretainedValue()
            MainActor.assumeIsolated {
                service.handlePowerSourceChange()
            }
        }, context)?.takeRetainedValue() {
            iopsRunLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        if let limitedSource = IOPSCreateLimitedPowerNotification({ contextPtr in
            guard let contextPtr else { return }
            let service = Unmanaged<IOKitBatteryService>.fromOpaque(contextPtr).takeUnretainedValue()
            MainActor.assumeIsolated {
                service.handlePowerSourceChange()
            }
        }, context)?.takeRetainedValue() {
            limitedPowerRunLoopSource = limitedSource
            CFRunLoopAddSource(CFRunLoopGetMain(), limitedSource, .commonModes)
        }

        registerKernelInterestNotifications(context: context)

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handlePowerSourceChange(forceEmit: true)
            }
        }

        // Low-overhead fallback timer with tolerance for passive telemetry (temperature/voltage) refresh.
        let timer = Timer(timeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handlePowerSourceChange(forceEmit: true)
            }
        }
        timer.tolerance = 2.0
        RunLoop.main.add(timer, forMode: .common)
        fallbackTimer = timer
    }

    func stopMonitoring() {
        transitionConfirmTask?.cancel()
        transitionConfirmTask = nil

        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }

        if let source = iopsRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            iopsRunLoopSource = nil
        }

        if let limitedSource = limitedPowerRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), limitedSource, .commonModes)
            limitedPowerRunLoopSource = nil
        }

        for notification in interestNotifications {
            IOObjectRelease(notification)
        }
        interestNotifications.removeAll()

        if let portSource = portRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), portSource, .commonModes)
            portRunLoopSource = nil
        }
        if let notificationPort {
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
        }

        fallbackTimer?.invalidate()
        fallbackTimer = nil
        updateHandler = nil
    }

    @discardableResult
    func refreshNow() -> BatteryInfo {
        let iopsDict = Self.readIOPSPrimaryBattery()
        let smartBatteryDict = Self.readIORegistryService(named: "AppleSmartBattery")
        let smartBatteryPackDict = Self.readIORegistryService(named: "AppleSmartBatteryPack")
        let parsed = BatterySnapshotParser.parse(
            iops: iopsDict,
            smartBattery: smartBatteryDict,
            smartBatteryPack: smartBatteryPackDict
        )
        currentBattery = parsed
        return parsed
    }

    private func registerKernelInterestNotifications(context: UnsafeMutableRawPointer) {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notificationPort = port

        let source = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
        portRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        let callback: IOServiceInterestCallback = { contextPtr, _, _, _ in
            guard let contextPtr else { return }
            let service = Unmanaged<IOKitBatteryService>.fromOpaque(contextPtr).takeUnretainedValue()
            MainActor.assumeIsolated {
                service.handlePowerSourceChange()
            }
        }

        for serviceName in ["AppleSmartBattery", "AppleSmartBatteryPack"] {
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(serviceName))
            guard service != IO_OBJECT_NULL else { continue }
            defer { IOObjectRelease(service) }

            var notification: io_object_t = IO_OBJECT_NULL
            let result = IOServiceAddInterestNotification(
                port,
                service,
                kIOGeneralInterest,
                callback,
                context,
                &notification
            )
            if result == KERN_SUCCESS && notification != IO_OBJECT_NULL {
                interestNotifications.append(notification)
            }
        }
    }

    private func handlePowerSourceChange(forceEmit: Bool = false) {
        let previous = currentBattery
        let updated = refreshNow()

        let visualChanged = updated.hasVisualOrStatusChange(from: previous)
        if updated.isPluggedIn != previous.isPluggedIn {
            scheduleTransitionConfirmation()
        }

        if forceEmit || visualChanged {
            lastEmitDate = updated.lastUpdated
            updateHandler?(updated)
            return
        }

        if updated.hasTelemetryChange(from: previous),
           updated.lastUpdated.timeIntervalSince(lastEmitDate) >= 1.0 {
            lastEmitDate = updated.lastUpdated
            updateHandler?(updated)
        }
    }

    private func scheduleTransitionConfirmation() {
        transitionConfirmTask?.cancel()
        transitionConfirmTask = Task { @MainActor [weak self] in
            // USB-C / MagSafe PD negotiation can raise IsCharging ~1-3s after ExternalConnected attaches.
            for delayNs in [1_000_000_000 as UInt64, 1_500_000_000 as UInt64] {
                try? await Task.sleep(nanoseconds: delayNs)
                guard !Task.isCancelled else { return }
                self?.handlePowerSourceChange(forceEmit: false)
            }
        }
    }

    private static func readIOPSPrimaryBattery() -> [String: Any]? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return nil
        }
        guard let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in list {
            if let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] {
                let type = description[kIOPSTypeKey] as? String
                if type == nil || type == kIOPSInternalBatteryType {
                    return description
                }
            }
        }
        return nil
    }

    private static func readIORegistryService(named serviceName: String) -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(serviceName))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS, let dict = properties?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return dict
    }
}
