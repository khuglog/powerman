import Foundation

struct ChargeLimitStatus: Equatable, Sendable {
    var isSupported: Bool
    var isEnabled: Bool
    var limitPercentage: Int
    var availableLimits: [Int]
    var lastError: String?

    static let unsupported = ChargeLimitStatus(
        isSupported: false,
        isEnabled: false,
        limitPercentage: 100,
        availableLimits: [80, 85, 90, 95, 100],
        lastError: nil
    )
}

enum ChargeLimitOverrideEndCondition: String, CaseIterable, Identifiable, Codable, Sendable {
    case onUnplug = "onUnplug"
    case onFirstFullCharge = "onFirstFullCharge"

    var id: String { rawValue }

    var title: String {
        title(in: Locale(identifier: "en"))
    }

    func title(in locale: Locale) -> String {
        switch self {
        case .onUnplug:
            return L10n.string("Immediately when unplugged", locale: locale)
        case .onFirstFullCharge:
            return L10n.string("When reaching 100% for the first time", locale: locale)
        }
    }

    func subtitle(in locale: Locale) -> String {
        switch self {
        case .onUnplug:
            return L10n.string("Restores your charge limit as soon as you disconnect the charger.", locale: locale)
        case .onFirstFullCharge:
            return L10n.string("Restores your charge limit automatically as soon as the battery reaches 100%.", locale: locale)
        }
    }
}

struct TemporaryChargeOverrideState: Codable, Equatable, Sendable {
    var restoreLimitPercentage: Int
    var hasObservedPluggedIn: Bool
    var activatedAt: Date
}

enum ChargeLimitHelpers {
    static let defaultLimits = [80, 85, 90, 95, 100]

    static func snapToSupportedLimit(_ value: Int, availableLimits: [Int] = defaultLimits) -> Int {
        let valid = availableLimits.filter { (50...100).contains($0) }.sorted()
        let pool = valid.isEmpty ? defaultLimits : valid
        return pool.min(by: { abs($0 - value) < abs($1 - value) }) ?? 80
    }
}
