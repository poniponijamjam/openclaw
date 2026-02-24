import Foundation

struct AppUsageSample: Codable, Hashable {
    let bundleId: String
    let displayName: String
    let usedAt: Date
    let durationSeconds: TimeInterval
}

struct UsageSnapshotFactory {
    static func makeEntries(
        from samples: [AppUsageSample],
        asOf now: Date = Date()
    ) -> [UsageSnapshotEntry] {
        let day30 = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let day90 = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now

        struct Bucket {
            var displayName: String
            var lastUsedAt: Date?
            var seconds30d: TimeInterval
            var seconds90d: TimeInterval
        }

        var buckets: [String: Bucket] = [:]

        for sample in samples {
            guard sample.durationSeconds > 0 else { continue }
            var bucket = buckets[sample.bundleId] ?? Bucket(
                displayName: sample.displayName,
                lastUsedAt: nil,
                seconds30d: 0,
                seconds90d: 0
            )

            if sample.usedAt >= day90 {
                bucket.seconds90d += sample.durationSeconds
            }
            if sample.usedAt >= day30 {
                bucket.seconds30d += sample.durationSeconds
            }

            if let last = bucket.lastUsedAt {
                if sample.usedAt > last {
                    bucket.lastUsedAt = sample.usedAt
                }
            } else {
                bucket.lastUsedAt = sample.usedAt
            }

            buckets[sample.bundleId] = bucket
        }

        return buckets.map { bundleId, bucket in
            UsageSnapshotEntry(
                bundleId: bundleId,
                displayName: bucket.displayName,
                lastUsedAt: bucket.lastUsedAt,
                minutes30d: Int(bucket.seconds30d / 60.0),
                minutes90d: Int(bucket.seconds90d / 60.0)
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
