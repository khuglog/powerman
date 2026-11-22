import AppKit
import SwiftUI
import XCTest
@testable import Powerman

final class AlertEngineTests: XCTestCase {
    private func makeBattery(
        percentage: Int,
        isPluggedIn: Bool,
        isCharging: Bool = false
    ) -> BatteryInfo {
        BatteryInfo(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            isFullyCharged: isPluggedIn && percentage >= 100,
            timeRemainingMinutes: isPluggedIn ? nil : 45,
            cycleCount: 167,
            ratedCycleCount: 1000,
            designCapacityMah: 6249,
            maxCapacityMah: 5719,
            currentCapacityMah: 3600,
            temperatureCelsius: 32.5,
            voltageMv: 11850,
            amperageMa: isCharging ? 2000 : -1100,
            batteryPowerMw: nil,
            adapterWatts: isPluggedIn ? 96 : nil,
            adapterName: nil,
            hasBattery: true,
            lastUpdated: Date()
        )
    }

    @MainActor
    func testLowBatteryAlertHysteresisAndReset() {
        let engine = AlertEngine()
        let rules = [
            AlertRule(kind: .lowBattery, threshold: 20, colorHex: "#FFCC00"),
            AlertRule(kind: .lowBattery, threshold: 10, colorHex: "#FF3B30", borderGlow: true, persistent: true)
        ]
        let powerSource = PowerSourceAlertConfig(pluggedInEnabled: false, unpluggedEnabled: false)

        // Baseline at 25% -> no alert on launch
        let r1 = engine.evaluate(battery: makeBattery(percentage: 25, isPluggedIn: false), rules: rules, powerSource: powerSource, notificationsEnabled: true)
        XCTAssertNil(r1.triggeredAlert)

        // Drop to 20% -> fires 20% rule
        let r2 = engine.evaluate(battery: makeBattery(percentage: 20, isPluggedIn: false), rules: rules, powerSource: powerSource, notificationsEnabled: true)
        XCTAssertEqual(r2.triggeredAlert?.ruleID, rules[0].id)

        // Bounce to 21% and back to 20% -> hysteresis (requires >= 23%) prevents re-firing
        _ = engine.evaluate(battery: makeBattery(percentage: 21, isPluggedIn: false), rules: rules, powerSource: powerSource, notificationsEnabled: true)
        let r3 = engine.evaluate(battery: makeBattery(percentage: 20, isPluggedIn: false), rules: rules, powerSource: powerSource, notificationsEnabled: true)
        XCTAssertNil(r3.triggeredAlert)

        // Drop to 10% -> fires 10% rule
        let r4 = engine.evaluate(battery: makeBattery(percentage: 10, isPluggedIn: false), rules: rules, powerSource: powerSource, notificationsEnabled: true)
        XCTAssertEqual(r4.triggeredAlert?.ruleID, rules[1].id)
        XCTAssertTrue(r4.triggeredAlert?.persistent == true)

        // Plug in -> should request dismissal of active lowBattery persistent alert and reset flags
        let r5 = engine.evaluate(battery: makeBattery(percentage: 10, isPluggedIn: true, isCharging: true), rules: rules, powerSource: powerSource, notificationsEnabled: true)
        XCTAssertEqual(r5.dismissKind, .lowBattery)
        XCTAssertNil(r5.triggeredAlert)

        // Unplug again at 10% -> fires critical 10% rule once
        let r6 = engine.evaluate(battery: makeBattery(percentage: 10, isPluggedIn: false), rules: rules, powerSource: powerSource, notificationsEnabled: true)
        XCTAssertEqual(r6.triggeredAlert?.ruleID, rules[1].id)
    }

    @MainActor
    func testChargedAlertAndPowerSourceTransitions() {
        let engine = AlertEngine()
        let chargedRule = AlertRule(kind: .charged, threshold: 80, colorHex: "#34C759", sound: .chargedChime)
        let powerSource = PowerSourceAlertConfig(pluggedInEnabled: true, pluggedInSound: .powerConnect, unpluggedEnabled: true, unpluggedSound: .ping)

        // Baseline at 78% on battery
        _ = engine.evaluate(battery: makeBattery(percentage: 78, isPluggedIn: false), rules: [chargedRule], powerSource: powerSource, notificationsEnabled: true)

        // Plug in at 78% -> fires Plugged In power source alert
        let r1 = engine.evaluate(battery: makeBattery(percentage: 78, isPluggedIn: true, isCharging: true), rules: [chargedRule], powerSource: powerSource, notificationsEnabled: true)
        XCTAssertEqual(r1.triggeredAlert?.title, "Power Connected")

        // Reach 80% -> fires Charged rule
        let r2 = engine.evaluate(battery: makeBattery(percentage: 80, isPluggedIn: true, isCharging: true), rules: [chargedRule], powerSource: powerSource, notificationsEnabled: true)
        XCTAssertEqual(r2.triggeredAlert?.ruleID, chargedRule.id)
        XCTAssertEqual(r2.triggeredAlert?.title, "80% Charged")

        // Unplug -> dismisses charged alert & fires Unplugged notification
        let r3 = engine.evaluate(battery: makeBattery(percentage: 80, isPluggedIn: false), rules: [chargedRule], powerSource: powerSource, notificationsEnabled: true)
        XCTAssertEqual(r3.dismissKind, .charged)
        XCTAssertEqual(r3.triggeredAlert?.title, "On Battery Power")
    }

    @MainActor
    func testNotificationsDisabledSuppressesAlerts() {
        let engine = AlertEngine()
        let rule = AlertRule(kind: .lowBattery, threshold: 20, colorHex: "#FF3B30")
        let powerSource = PowerSourceAlertConfig()

        _ = engine.evaluate(battery: makeBattery(percentage: 25, isPluggedIn: false), rules: [rule], powerSource: powerSource, notificationsEnabled: false)
        let r = engine.evaluate(battery: makeBattery(percentage: 15, isPluggedIn: false), rules: [rule], powerSource: powerSource, notificationsEnabled: false)
        XCTAssertNil(r.triggeredAlert)
    }

    @MainActor
    func testAlertRulesPersistenceAndCRUD() {
        let suiteName = "com.powerman.alerts.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        let initialCount = settings.alertRules.count
        let added = settings.addAlertRule(kind: .lowBattery)
        XCTAssertEqual(settings.alertRules.count, initialCount + 1)

        settings.notificationsEnabled = false
        settings.powerSourceAlerts.pluggedInSound = .submarine

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.alertRules.count, initialCount + 1)
        XCTAssertTrue(reloaded.alertRules.contains(where: { $0.id == added.id }))
        XCTAssertFalse(reloaded.notificationsEnabled)
        XCTAssertEqual(reloaded.powerSourceAlerts.pluggedInSound, .submarine)

        reloaded.removeAlertRule(id: added.id)
        XCTAssertEqual(reloaded.alertRules.count, initialCount)
    }

    func testCustomSynthesizedSoundsGenerateValidWAVData() {
        for option in AlertSoundOption.customAlertSounds {
            let data = SynthesizedSoundGenerator.waveData(for: option)
            XCTAssertNotNil(data, "Expected WAV data for \(option.rawValue)")
            if let data {
                XCTAssertGreaterThan(data.count, 1000)
                let riff = String(data: data.prefix(4), encoding: .ascii)
                let wave = String(data: data.subdata(in: 8..<12), encoding: .ascii)
                XCTAssertEqual(riff, "RIFF")
                XCTAssertEqual(wave, "WAVE")
            }
        }

        XCTAssertNil(SynthesizedSoundGenerator.waveData(for: .none))
        XCTAssertNil(SynthesizedSoundGenerator.waveData(for: .glass))
    }

    func testSemanticDefaultAlertSounds() {
        let low5 = AlertRule.defaultRules.first { $0.kind == .lowBattery && $0.threshold == 5 }
        let low10 = AlertRule.defaultRules.first { $0.kind == .lowBattery && $0.threshold == 10 }
        let low20 = AlertRule.defaultRules.first { $0.kind == .lowBattery && $0.threshold == 20 }
        let charged80 = AlertRule.defaultRules.first { $0.kind == .charged && $0.threshold == 80 }

        XCTAssertEqual(low5?.sound, .criticalAlarm)
        XCTAssertEqual(low10?.sound, .urgentBeep)
        XCTAssertEqual(low20?.sound, .lowWarning)
        XCTAssertEqual(charged80?.sound, .chargedChime)

        let powerDefaults = PowerSourceAlertConfig()
        XCTAssertEqual(powerDefaults.pluggedInSound, .powerConnect)
        XCTAssertEqual(powerDefaults.unpluggedSound, .powerDisconnect)
    }

    @MainActor
    func testFloatingAlertBubbleCornersAreFullyTransparent() {
        let alert = ActiveAlertPresentation(
            id: UUID(),
            ruleID: nil,
            kind: .lowBattery,
            title: "15% Remaining",
            subtitle: "9min until empty",
            percentage: 15,
            colorHex: AlertColorPreset.orange.rawValue,
            showPopup: true,
            position: .topOfScreen,
            sound: .none,
            borderGlow: false,
            persistent: false,
            isChargingIcon: false
        )
        let hosting = NSHostingController(rootView: FloatingAlertBubbleView(alert: alert, bubbleSize: .default, onDismiss: {}))
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.view.layer?.isOpaque = false

        let fittingSize = hosting.sizeThatFits(in: NSSize(width: 600, height: 200))
        let frame = NSRect(x: 0, y: 0, width: fittingSize.width, height: fittingSize.height)
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.contentViewController = hosting
        panel.setFrame(frame, display: true)
        panel.displayIfNeeded()

        guard let contentView = panel.contentView,
              let rep = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) else {
            XCTFail("Failed to create bitmap image representation for popup contentView")
            return
        }
        contentView.cacheDisplay(in: contentView.bounds, to: rep)

        let cornerCoords = [
            (2, 2),
            (rep.pixelsWide - 3, 2),
            (2, rep.pixelsHigh - 3),
            (rep.pixelsWide - 3, rep.pixelsHigh - 3)
        ]
        for (x, y) in cornerCoords {
            let alpha = rep.colorAt(x: x, y: y)?.alphaComponent ?? 1.0
            XCTAssertEqual(alpha, 0.0, accuracy: 0.001, "Corner pixel (\(x), \(y)) should be completely transparent")
        }
    }
}
