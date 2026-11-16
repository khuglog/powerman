import Foundation
import ObjectiveC

@MainActor
protocol ChargeLimitManaging: AnyObject {
    func fetchStatus() -> ChargeLimitStatus
    func setEnabled(_ enabled: Bool, targetLimit: Int) -> ChargeLimitStatus
    func setLimit(_ percentage: Int) -> ChargeLimitStatus
}

@MainActor
final class NativeChargeLimitService: ChargeLimitManaging {
    private static let frameworkPath = "/System/Library/PrivateFrameworks/PowerUI.framework/PowerUI"
    private let client: NSObject?

    init() {
        guard dlopen(Self.frameworkPath, RTLD_LAZY) != nil,
              let cls = NSClassFromString("PowerUISmartChargeClient") as? NSObject.Type else {
            self.client = nil
            return
        }

        let allocObj = cls.perform(NSSelectorFromString("alloc")).takeUnretainedValue() as? NSObject
        let initSel = NSSelectorFromString("initWithClientName:")
        guard let allocObj, allocObj.responds(to: initSel) else {
            self.client = nil
            return
        }

        typealias InitFn = @convention(c) (AnyObject, Selector, NSString) -> AnyObject?
        let imp = unsafeBitCast(allocObj.method(for: initSel), to: InitFn.self)
        self.client = imp(allocObj, initSel, "com.khuglog.powerman" as NSString) as? NSObject
    }

    func fetchStatus() -> ChargeLimitStatus {
        guard let client, isMCLSupported(client) else {
            return .unsupported
        }

        var error: NSError?
        let enabledRaw = readMCLEnabled(client, error: &error)
        let firstError = error?.localizedDescription

        error = nil
        let available = readAvailableLimits(client, error: &error)
        let limits = available.isEmpty ? ChargeLimitHelpers.defaultLimits : available

        error = nil
        let limitRaw = readMCLLimit(client, error: &error)
        let snappedLimit = ChargeLimitHelpers.snapToSupportedLimit(limitRaw > 0 ? limitRaw : 80, availableLimits: limits)

        return ChargeLimitStatus(
            isSupported: true,
            isEnabled: enabledRaw != 0,
            limitPercentage: snappedLimit,
            availableLimits: limits,
            lastError: firstError ?? error?.localizedDescription
        )
    }

    func setEnabled(_ enabled: Bool, targetLimit: Int) -> ChargeLimitStatus {
        guard let client, isMCLSupported(client) else {
            return .unsupported
        }

        var error: NSError?
        let ok: Bool
        if enabled {
            let enableOk = callBoolErrorMethod(client, selectorName: "enableMCL:", error: &error)
            let available = readAvailableLimits(client, error: &error)
            // macOS interprets 100% as "Charge Limit Off", so enabling must target an active cap < 100%.
            let activeLimits = available.filter { $0 < 100 }
            let safeTarget = targetLimit < 100 ? targetLimit : 80
            let snapped = ChargeLimitHelpers.snapToSupportedLimit(
                safeTarget,
                availableLimits: activeLimits.isEmpty ? [80, 85, 90, 95] : activeLimits
            )
            let limitOk = setMCLLimit(client, limit: UInt8(snapped), error: &error)
            ok = enableOk || limitOk
        } else {
            ok = callBoolErrorMethod(client, selectorName: "disableMCL:", error: &error)
        }

        var status = fetchStatus()
        if !ok && status.lastError == nil {
            status.lastError = error?.localizedDescription ?? "Unable to update macOS Charge Limit."
        }
        return status
    }

    func setLimit(_ percentage: Int) -> ChargeLimitStatus {
        guard let client, isMCLSupported(client) else {
            return .unsupported
        }

        var error: NSError?
        let available = readAvailableLimits(client, error: &error)
        let snapped = ChargeLimitHelpers.snapToSupportedLimit(percentage, availableLimits: available)

        error = nil
        let ok = setMCLLimit(client, limit: UInt8(snapped), error: &error)

        var status = fetchStatus()
        if !ok && status.lastError == nil {
            status.lastError = error?.localizedDescription ?? "Unable to set Charge Limit to \(snapped)%."
        }
        return status
    }

    // MARK: - Objective-C Runtime Bridges

    private func isMCLSupported(_ client: NSObject) -> Bool {
        let sel = NSSelectorFromString("isMCLSupported")
        guard client.responds(to: sel) else { return false }
        typealias Fn = @convention(c) (AnyObject, Selector) -> ObjCBool
        let imp = unsafeBitCast(client.method(for: sel), to: Fn.self)
        return imp(client, sel).boolValue
    }

    private func readMCLEnabled(_ client: NSObject, error: inout NSError?) -> UInt64 {
        let sel = NSSelectorFromString("isMCLCurrentlyEnabled:")
        guard client.responds(to: sel) else { return 0 }
        typealias Fn = @convention(c) (AnyObject, Selector, NSErrorPointer) -> UInt64
        let imp = unsafeBitCast(client.method(for: sel), to: Fn.self)
        return imp(client, sel, &error)
    }

    private func readAvailableLimits(_ client: NSObject, error: inout NSError?) -> [Int] {
        let sel = NSSelectorFromString("availableChargeLimitsWithError:")
        guard client.responds(to: sel) else { return ChargeLimitHelpers.defaultLimits }
        typealias Fn = @convention(c) (AnyObject, Selector, NSErrorPointer) -> NSArray?
        let imp = unsafeBitCast(client.method(for: sel), to: Fn.self)
        guard let arr = imp(client, sel, &error) as? [NSNumber] else {
            return ChargeLimitHelpers.defaultLimits
        }
        let parsed = arr.map(\.intValue).sorted()
        return parsed.isEmpty ? ChargeLimitHelpers.defaultLimits : parsed
    }

    private func readMCLLimit(_ client: NSObject, error: inout NSError?) -> Int {
        let sel = NSSelectorFromString("getMCLLimitWithError:")
        guard client.responds(to: sel) else { return 80 }
        typealias Fn = @convention(c) (AnyObject, Selector, NSErrorPointer) -> UInt8
        let imp = unsafeBitCast(client.method(for: sel), to: Fn.self)
        return Int(imp(client, sel, &error))
    }

    private func setMCLLimit(_ client: NSObject, limit: UInt8, error: inout NSError?) -> Bool {
        let sel = NSSelectorFromString("setMCLLimit:error:")
        guard client.responds(to: sel) else { return false }
        typealias Fn = @convention(c) (AnyObject, Selector, UInt8, NSErrorPointer) -> ObjCBool
        let imp = unsafeBitCast(client.method(for: sel), to: Fn.self)
        return imp(client, sel, limit, &error).boolValue
    }

    private func callBoolErrorMethod(_ client: NSObject, selectorName: String, error: inout NSError?) -> Bool {
        let sel = NSSelectorFromString(selectorName)
        guard client.responds(to: sel) else { return false }
        typealias Fn = @convention(c) (AnyObject, Selector, NSErrorPointer) -> ObjCBool
        let imp = unsafeBitCast(client.method(for: sel), to: Fn.self)
        return imp(client, sel, &error).boolValue
    }
}
