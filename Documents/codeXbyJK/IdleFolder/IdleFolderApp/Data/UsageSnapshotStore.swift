import Foundation

struct UsageSnapshotEntry: Codable, Hashable {
    let bundleId: String
    let displayName: String
    let lastUsedAt: Date?
    let minutes30d: Int
    let minutes90d: Int
}

struct UsageSnapshot: Codable, Hashable {
    let generatedAt: Date
    let entries: [UsageSnapshotEntry]
}

protocol UsageSnapshotReading {
    func loadLatestSnapshot() throws -> UsageSnapshot
}

protocol UsageSnapshotWriting {
    func saveSnapshot(_ snapshot: UsageSnapshot) throws
}

enum UsageSnapshotStoreError: Error {
    case noSnapshot
    case corruptData
}

final class AppGroupUsageSnapshotStore: UsageSnapshotReading, UsageSnapshotWriting {
    private let defaults: UserDefaults
    private let key = "screen_time_usage_snapshot_v1"

    init(appGroupId: String = "group.com.example.IdleFolder") {
        if let shared = UserDefaults(suiteName: appGroupId) {
            self.defaults = shared
        } else {
            self.defaults = .standard
        }
    }

    func loadLatestSnapshot() throws -> UsageSnapshot {
        guard let data = defaults.data(forKey: key) else {
            throw UsageSnapshotStoreError.noSnapshot
        }
        guard let snapshot = try? JSONDecoder().decode(UsageSnapshot.self, from: data) else {
            throw UsageSnapshotStoreError.corruptData
        }
        return snapshot
    }

    func saveSnapshot(_ snapshot: UsageSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        defaults.set(data, forKey: key)
    }
}
