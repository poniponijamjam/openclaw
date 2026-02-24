import Foundation

// Aggregates raw app usage samples into IdleFolder snapshot format and persists
// the result through app-group shared storage.
struct DeviceActivityAggregationService {
    private let bridge: ScreenTimeReportBridge

    init(bridge: ScreenTimeReportBridge = ScreenTimeReportBridge()) {
        self.bridge = bridge
    }

    func persist(samples: [AppUsageSample], asOf now: Date = Date()) throws {
        let entries = UsageSnapshotFactory.makeEntries(from: samples, asOf: now)
        try bridge.persist(entries: entries, generatedAt: now)
    }
}
