import Foundation

struct ScreenTimeUsageProvider: AppUsageProviding {
    private let store: UsageSnapshotReading
    private let maxSnapshotAgeHours: Int

    init(
        store: UsageSnapshotReading = AppGroupUsageSnapshotStore(),
        maxSnapshotAgeHours: Int = 72
    ) {
        self.store = store
        self.maxSnapshotAgeHours = maxSnapshotAgeHours
    }

    func fetchUsages() async throws -> [AppUsage] {
        let snapshot: UsageSnapshot

        do {
            snapshot = try store.loadLatestSnapshot()
        } catch UsageSnapshotStoreError.noSnapshot {
            throw AppUsageProviderError.unavailable(
                "Screen Time 스냅샷이 없습니다. Report Extension 실행 후 다시 시도하세요."
            )
        } catch UsageSnapshotStoreError.corruptData {
            throw AppUsageProviderError.unavailable(
                "Screen Time 스냅샷 데이터가 손상되었습니다."
            )
        } catch {
            throw AppUsageProviderError.unavailable(
                "Screen Time 스냅샷을 불러오지 못했습니다."
            )
        }

        guard !snapshot.entries.isEmpty else {
            throw AppUsageProviderError.unavailable(
                "Screen Time 스냅샷은 있으나 앱 사용 데이터가 비어 있습니다."
            )
        }

        let ageSeconds = Date().timeIntervalSince(snapshot.generatedAt)
        let maxAgeSeconds = TimeInterval(maxSnapshotAgeHours * 3600)
        guard ageSeconds <= maxAgeSeconds else {
            throw AppUsageProviderError.unavailable(
                "Screen Time 스냅샷이 오래되었습니다. 최신 리포트를 다시 생성하세요."
            )
        }

        return snapshot.entries.map { entry in
            AppUsage(
                bundleId: entry.bundleId,
                displayName: entry.displayName,
                lastUsedAt: entry.lastUsedAt,
                minutes30d: max(0, entry.minutes30d),
                minutes90d: max(0, entry.minutes90d)
            )
        }
    }
}
