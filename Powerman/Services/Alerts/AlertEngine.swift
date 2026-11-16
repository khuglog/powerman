import Foundation

struct AlertEvaluationResult: Equatable, Sendable {
    let triggeredAlert: ActiveAlertPresentation?
    let dismissKind: AlertKind?
}

@MainActor
final class AlertEngine {
    private var previousBattery: BatteryInfo?
    private var firedLowRuleIDs: Set<UUID> = []
    private var firedChargedRuleIDs: Set<UUID> = []

    func reset() {
        previousBattery = nil
        firedLowRuleIDs.removeAll()
        firedChargedRuleIDs.removeAll()
    }

    func evaluate(
        battery: BatteryInfo,
        rules: [AlertRule],
        powerSource: PowerSourceAlertConfig,
        notificationsEnabled: Bool
    ) -> AlertEvaluationResult {
        guard battery.hasBattery else {
            return AlertEvaluationResult(triggeredAlert: nil, dismissKind: nil)
        }

        // Establish initial baseline without spamming alerts on app launch.
        guard let previous = previousBattery else {
            previousBattery = battery
            if !battery.isPluggedIn {
                for rule in rules where rule.kind == .lowBattery && battery.percentage <= rule.threshold {
                    firedLowRuleIDs.insert(rule.id)
                }
            } else {
                for rule in rules where rule.kind == .charged && battery.percentage >= rule.threshold {
                    firedChargedRuleIDs.insert(rule.id)
                }
            }
            return AlertEvaluationResult(triggeredAlert: nil, dismissKind: nil)
        }

        previousBattery = battery

        // Reset hysteresis flags for rules that are no longer in the trigger zone.
        for rule in rules {
            switch rule.kind {
            case .lowBattery:
                if battery.isPluggedIn || battery.percentage >= rule.threshold + 3 {
                    firedLowRuleIDs.remove(rule.id)
                }
            case .charged:
                if !battery.isPluggedIn || battery.percentage <= rule.threshold - 3 {
                    firedChargedRuleIDs.remove(rule.id)
                }
            }
        }

        let dismissKind: AlertKind? = {
            if !previous.isPluggedIn && battery.isPluggedIn {
                return .lowBattery
            }
            if previous.isPluggedIn && !battery.isPluggedIn {
                return .charged
            }
            return nil
        }()

        guard notificationsEnabled else {
            return AlertEvaluationResult(triggeredAlert: nil, dismissKind: dismissKind)
        }

        // 1. Check Low Battery alerts (most critical lowest threshold first).
        if !battery.isPluggedIn {
            let matchingLow = rules
                .filter { $0.kind == .lowBattery && battery.percentage <= $0.threshold && !firedLowRuleIDs.contains($0.id) }
                .sorted { $0.threshold < $1.threshold }

            if let criticalRule = matchingLow.first {
                for rule in matchingLow {
                    firedLowRuleIDs.insert(rule.id)
                }
                return AlertEvaluationResult(
                    triggeredAlert: .from(rule: criticalRule, battery: battery),
                    dismissKind: dismissKind
                )
            }
        }

        // 2. Check Charged alerts (highest reached threshold first).
        if battery.isPluggedIn {
            let matchingCharged = rules
                .filter { $0.kind == .charged && battery.percentage >= $0.threshold && !firedChargedRuleIDs.contains($0.id) }
                .sorted { $0.threshold > $1.threshold }

            if let targetRule = matchingCharged.first {
                for rule in matchingCharged {
                    firedChargedRuleIDs.insert(rule.id)
                }
                return AlertEvaluationResult(
                    triggeredAlert: .from(rule: targetRule, battery: battery),
                    dismissKind: dismissKind
                )
            }
        }

        // 3. Check Power Source transition (Plugged In / Unplugged).
        if previous.isPluggedIn != battery.isPluggedIn {
            if battery.isPluggedIn && powerSource.pluggedInEnabled {
                return AlertEvaluationResult(
                    triggeredAlert: .powerSource(pluggedIn: true, battery: battery, sound: powerSource.pluggedInSound),
                    dismissKind: dismissKind
                )
            } else if !battery.isPluggedIn && powerSource.unpluggedEnabled {
                return AlertEvaluationResult(
                    triggeredAlert: .powerSource(pluggedIn: false, battery: battery, sound: powerSource.unpluggedSound),
                    dismissKind: dismissKind
                )
            }
        }

        return AlertEvaluationResult(triggeredAlert: nil, dismissKind: dismissKind)
    }
}
