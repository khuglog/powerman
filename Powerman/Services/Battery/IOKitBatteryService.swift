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

    private var runLoopSource: CFRunLoopSource?
    private var fallbackTimer: Timer?
    private var updateHandler: (@MainActor (BatteryInfo) -> Void)?

    func startMonitoring(onUpdate: @escaping @MainActor (BatteryInfo) -> Void) {
        stopMonitoring()
        self.updateHandler = onUpdate

        let initial = refreshNow()
        onUpdate(initial)

        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ contextPtr in
            guard let contextPtr else { return }
            let service = Unmanaged<IOKitBatteryService>.fromOpaque(contextPtr).takeUnretainedValue()
            MainActor.assumeIsolated {
                service.handlePowerSourceChange()
            }
        }, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }

        // Light 30-second fallback timer to keep temperature and wattage fresh without draining battery.
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handlePowerSourceChange()
            }
        }
    }

    func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        updateHandler = nil
    }

    @discardableResult
    func refreshNow() -> BatteryInfo {
        let iopsDict = Self.readIOPSPrimaryBattery()
        let smartBatteryDict = Self.readAppleSmartBattery()
        let parsed = BatterySnapshotParser.parse(iops: iopsDict, smartBattery: smartBatteryDict)
        currentBattery = parsed
        return parsed
    }

    private func handlePowerSourceChange() {
        let updated = refreshNow()
        updateHandler?(updated)
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

    private static func readAppleSmartBattery() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
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
