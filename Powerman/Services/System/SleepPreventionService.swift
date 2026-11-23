import Foundation
import IOKit.pwr_mgt

@MainActor
protocol SleepPreventing: AnyObject {
    var isPreventingSleep: Bool { get }
    var activeAllowsScreenSaver: Bool? { get }

    @discardableResult
    func beginPreventingSystemSleep(reason: String, allowScreenSaver: Bool) -> Bool
    func endPreventingSystemSleep()
}

/// Uses IOKit power assertions:
/// - `PreventUserIdleSystemSleep` (`caffeinate -i`) when `allowScreenSaver` is true.
/// - `PreventUserIdleDisplaySleep` (`caffeinate -d`) when `allowScreenSaver` is false,
///   which prevents both the screen saver/display sleep and system idle sleep.
@MainActor
final class IOKitSleepPreventionService: SleepPreventing {
    private var assertionID: IOPMAssertionID?
    private(set) var activeAllowsScreenSaver: Bool?

    var isPreventingSleep: Bool {
        assertionID != nil
    }

    @discardableResult
    func beginPreventingSystemSleep(reason: String, allowScreenSaver: Bool) -> Bool {
        if assertionID != nil {
            if activeAllowsScreenSaver == allowScreenSaver {
                return true
            }
            endPreventingSystemSleep()
        }

        let assertionType = allowScreenSaver
            ? kIOPMAssertionTypePreventUserIdleSystemSleep
            : kIOPMAssertionTypePreventUserIdleDisplaySleep

        var newAssertionID: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(
            assertionType as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &newAssertionID
        )

        guard status == kIOReturnSuccess else {
            return false
        }

        assertionID = newAssertionID
        activeAllowsScreenSaver = allowScreenSaver
        return true
    }

    func endPreventingSystemSleep() {
        guard let assertionID else { return }
        IOPMAssertionRelease(assertionID)
        self.assertionID = nil
        self.activeAllowsScreenSaver = nil
    }
}
