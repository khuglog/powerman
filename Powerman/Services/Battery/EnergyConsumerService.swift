import AppKit
import Darwin
import Foundation

struct AppEnergyUsage: Identifiable, Equatable, Sendable {
    let id: String
    let pid: pid_t
    let name: String
    let bundleIdentifier: String?
    let cpuPercent: Double

    var impactLabel: String {
        if cpuPercent >= 35 {
            return "High"
        } else if cpuPercent >= 10 {
            return "Medium"
        } else {
            return "Low"
        }
    }
}

@MainActor
protocol EnergyConsuming: AnyObject {
    var topConsumers: [AppEnergyUsage] { get }
    func refresh(completion: (@MainActor ([AppEnergyUsage]) -> Void)?)
}

@MainActor
final class ProcessEnergyConsumerService: EnergyConsuming {
    private(set) var topConsumers: [AppEnergyUsage] = []

    private var previousSample: Snapshot?
    private var isSampling = false

    private struct Snapshot: Sendable {
        let timestamp: Date
        let cpuTicksByPID: [pid_t: UInt64]
    }

    private struct AppDescriptor: Sendable {
        let pid: pid_t
        let name: String
        let bundleID: String?
    }

    func refresh(completion: (@MainActor ([AppEnergyUsage]) -> Void)? = nil) {
        guard !isSampling else { return }
        isSampling = true

        let appDescriptors = NSWorkspace.shared.runningApplications.compactMap { app -> AppDescriptor? in
            guard app.activationPolicy == .regular,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  let name = app.localizedName, !name.isEmpty else {
                return nil
            }
            return AppDescriptor(pid: app.processIdentifier, name: name, bundleID: app.bundleIdentifier)
        }

        let prior = previousSample

        Task.detached(priority: .utility) {
            let baseline: Snapshot
            if let prior, Date().timeIntervalSince(prior.timestamp) >= 0.3 {
                baseline = prior
            } else {
                baseline = Self.captureSnapshot()
                try? await Task.sleep(for: .milliseconds(350))
            }

            let current = Self.captureSnapshot()
            let consumers = Self.computeTopConsumers(
                from: baseline,
                to: current,
                runningApps: appDescriptors
            )

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.previousSample = current
                self.topConsumers = consumers
                self.isSampling = false
                completion?(consumers)
            }
        }
    }

    nonisolated static func computeTopConsumers(
        from baseline: (timestamp: Date, cpuTicksByPID: [pid_t: UInt64]),
        to current: (timestamp: Date, cpuTicksByPID: [pid_t: UInt64]),
        parentByPID: [pid_t: pid_t],
        appPIDs: [pid_t: (name: String, bundleID: String?)],
        machTimebase: mach_timebase_info_data_t
    ) -> [AppEnergyUsage] {
        let elapsedSeconds = current.timestamp.timeIntervalSince(baseline.timestamp)
        guard elapsedSeconds > 0.05 else { return [] }

        let denom = max(UInt64(machTimebase.denom), 1)
        let numer = UInt64(machTimebase.numer)
        var cpuPercentByAppPID: [pid_t: Double] = [:]

        for (pid, currentTicks) in current.cpuTicksByPID {
            guard let oldTicks = baseline.cpuTicksByPID[pid], currentTicks >= oldTicks else {
                continue
            }
            let deltaTicks = currentTicks - oldTicks
            guard deltaTicks > 0 else { continue }

            let deltaSeconds = (Double(deltaTicks) * Double(numer) / Double(denom)) / 1_000_000_000.0
            let cpuPercent = (deltaSeconds / elapsedSeconds) * 100.0
            guard cpuPercent >= 0.2 else { continue }

            // Roll child/helper processes up to their ancestor GUI application.
            var cursor = pid
            var depth = 0
            while appPIDs[cursor] == nil && depth < 5 {
                guard let parent = parentByPID[cursor], parent > 1, parent != cursor else {
                    break
                }
                cursor = parent
                depth += 1
            }

            if appPIDs[cursor] != nil {
                cpuPercentByAppPID[cursor, default: 0] += cpuPercent
            }
        }

        return cpuPercentByAppPID
            .compactMap { pid, totalCPU -> AppEnergyUsage? in
                guard totalCPU >= 1.0, let meta = appPIDs[pid] else { return nil }
                return AppEnergyUsage(
                    id: meta.bundleID ?? "\(pid)-\(meta.name)",
                    pid: pid,
                    name: meta.name,
                    bundleIdentifier: meta.bundleID,
                    cpuPercent: totalCPU
                )
            }
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(5)
            .map { $0 }
    }

    private nonisolated static func computeTopConsumers(
        from baseline: Snapshot,
        to current: Snapshot,
        runningApps: [AppDescriptor]
    ) -> [AppEnergyUsage] {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)

        let parentMap = captureParentPIDMap(for: Array(current.cpuTicksByPID.keys))
        var appMap: [pid_t: (name: String, bundleID: String?)] = [:]
        for app in runningApps {
            appMap[app.pid] = (app.name, app.bundleID)
        }

        return computeTopConsumers(
            from: (baseline.timestamp, baseline.cpuTicksByPID),
            to: (current.timestamp, current.cpuTicksByPID),
            parentByPID: parentMap,
            appPIDs: appMap,
            machTimebase: timebase
        )
    }

    private nonisolated static func captureSnapshot() -> Snapshot {
        let bufferCount = proc_listallpids(nil, 0)
        guard bufferCount > 0 else {
            return Snapshot(timestamp: Date(), cpuTicksByPID: [:])
        }

        var pids = [pid_t](repeating: 0, count: Int(bufferCount) + 32)
        let bytesReturned = pids.withUnsafeMutableBytes { rawBuffer in
            proc_listallpids(rawBuffer.baseAddress, Int32(rawBuffer.count))
        }
        guard bytesReturned > 0 else {
            return Snapshot(timestamp: Date(), cpuTicksByPID: [:])
        }

        let count = Int(bytesReturned) / MemoryLayout<pid_t>.stride
        var ticksByPID: [pid_t: UInt64] = [:]
        ticksByPID.reserveCapacity(count)

        let taskInfoSize = Int32(MemoryLayout<proc_taskinfo>.stride)
        for i in 0..<count {
            let pid = pids[i]
            guard pid > 1 else { continue }
            var info = proc_taskinfo()
            let res = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, taskInfoSize)
            if res == taskInfoSize {
                ticksByPID[pid] = info.pti_total_user &+ info.pti_total_system
            }
        }

        return Snapshot(timestamp: Date(), cpuTicksByPID: ticksByPID)
    }

    private nonisolated static func captureParentPIDMap(for pids: [pid_t]) -> [pid_t: pid_t] {
        var parents: [pid_t: pid_t] = [:]
        parents.reserveCapacity(pids.count)
        let bsdSize = Int32(MemoryLayout<proc_bsdinfo>.stride)

        for pid in pids {
            var bsd = proc_bsdinfo()
            let res = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, bsdSize)
            if res == bsdSize {
                parents[pid] = pid_t(bsd.pbi_ppid)
            }
        }
        return parents
    }
}
