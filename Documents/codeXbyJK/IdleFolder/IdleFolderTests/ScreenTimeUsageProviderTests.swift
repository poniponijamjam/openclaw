import XCTest
@testable import IdleFolder

private struct StubSnapshotStore: UsageSnapshotReading {
    let snapshot: UsageSnapshot?
    let error: Error?

    func loadLatestSnapshot() throws -> UsageSnapshot {
        if let error {
            throw error
        }
        if let snapshot {
            return snapshot
        }
        throw UsageSnapshotStoreError.noSnapshot
    }
}

final class ScreenTimeUsageProviderTests: XCTestCase {
    func testReturnsMappedUsageWhenSnapshotIsFresh() async throws {
        let snapshot = UsageSnapshot(
            generatedAt: Date(),
            entries: [
                UsageSnapshotEntry(
                    bundleId: "com.example.a",
                    displayName: "App A",
                    lastUsedAt: nil,
                    minutes30d: 3,
                    minutes90d: 10
                )
            ]
        )

        let provider = ScreenTimeUsageProvider(
            store: StubSnapshotStore(snapshot: snapshot, error: nil),
            maxSnapshotAgeHours: 72
        )

        let usages = try await provider.fetchUsages()
        XCTAssertEqual(usages.count, 1)
        XCTAssertEqual(usages.first?.bundleId, "com.example.a")
        XCTAssertEqual(usages.first?.minutes30d, 3)
        XCTAssertEqual(usages.first?.minutes90d, 10)
    }

    func testThrowsWhenSnapshotMissing() async {
        let provider = ScreenTimeUsageProvider(
            store: StubSnapshotStore(snapshot: nil, error: nil),
            maxSnapshotAgeHours: 72
        )

        do {
            _ = try await provider.fetchUsages()
            XCTFail("Expected throw")
        } catch {
            XCTAssertNotNil(error.localizedDescription)
        }
    }
}
