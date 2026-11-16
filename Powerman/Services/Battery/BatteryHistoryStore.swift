import Foundation

@MainActor
protocol BatteryHistoryStoring: AnyObject {
    var samples: [BatteryHistorySample] { get }
    func load()
    @discardableResult
    func recordIfNeeded(from info: BatteryInfo) -> Bool
    func clearAll()
}

@MainActor
final class JSONBatteryHistoryStore: BatteryHistoryStoring {
    private(set) var samples: [BatteryHistorySample] = []
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.fileURL = appSupport
                .appendingPathComponent("Powerman", isDirectory: true)
                .appendingPathComponent("battery_history.json")
        }
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            samples = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([BatteryHistorySample].self, from: data)
            samples = BatteryHistoryAnalytics.pruneExpired(decoded)
        } catch {
            samples = []
        }
    }

    @discardableResult
    func recordIfNeeded(from info: BatteryInfo) -> Bool {
        guard info.hasBattery else { return false }
        let candidate = BatteryHistorySample(from: info)

        guard BatteryHistoryAnalytics.shouldRecord(newSample: candidate, lastSample: samples.last) else {
            return false
        }

        samples.append(candidate)
        samples = BatteryHistoryAnalytics.pruneExpired(samples, referenceDate: candidate.timestamp)
        save()
        return true
    }

    func clearAll() {
        samples = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func save() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(samples)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Non-fatal persistence error; keep in-memory samples intact.
        }
    }
}
