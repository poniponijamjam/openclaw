import Foundation

#if canImport(DeviceActivity)
import DeviceActivity
#endif

// Bridge used by DeviceActivityReportExtension to persist aggregated usage
// into app-group shared storage. The app then loads this snapshot via
// ScreenTimeUsageProvider.
struct ScreenTimeReportBridge {
    private let store: UsageSnapshotWriting

    init(store: UsageSnapshotWriting = AppGroupUsageSnapshotStore()) {
        self.store = store
    }

    func persist(entries: [UsageSnapshotEntry], generatedAt: Date = Date()) throws {
        let snapshot = UsageSnapshot(generatedAt: generatedAt, entries: entries)
        try store.saveSnapshot(snapshot)
    }
}
