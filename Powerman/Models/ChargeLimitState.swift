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

enum ChargeLimitHelpers {
    static let defaultLimits = [80, 85, 90, 95, 100]

    static func snapToSupportedLimit(_ value: Int, availableLimits: [Int] = defaultLimits) -> Int {
        let valid = availableLimits.filter { (50...100).contains($0) }.sorted()
        let pool = valid.isEmpty ? defaultLimits : valid
        return pool.min(by: { abs($0 - value) < abs($1 - value) }) ?? 80
    }
}
