import Foundation
import IOKit.pwr_mgt

@MainActor
protocol SleepPreventing: AnyObject {
    var isPreventingSleep: Bool { get }

    @discardableResult
    func beginPreventingSystemSleep(reason: String) -> Bool
    func endPreventingSystemSleep()
}

/// Uses IOKit's `PreventUserIdleSystemSleep` assertion (equivalent to `caffeinate -i`)
/// so the Mac stays awake for background tasks while still allowing the display to sleep
/// and the screen saver to activate normally.
@MainActor
final class IOKitSleepPreventionService: SleepPreventing {
    private var assertionID: IOPMAssertionID?

    var isPreventingSleep: Bool {
        assertionID != nil
    }

    @discardableResult
    func beginPreventingSystemSleep(reason: String) -> Bool {
        if assertionID != nil {
            return true
        }

        var newAssertionID: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &newAssertionID
        )

        guard status == kIOReturnSuccess else {
            return false
        }

        assertionID = newAssertionID
        return true
    }

    func endPreventingSystemSleep() {
        guard let assertionID else { return }
        IOPMAssertionRelease(assertionID)
        self.assertionID = nil
    }
}
