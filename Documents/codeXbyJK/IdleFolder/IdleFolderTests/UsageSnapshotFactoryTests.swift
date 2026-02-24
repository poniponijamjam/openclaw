import XCTest
@testable import IdleFolder

final class UsageSnapshotFactoryTests: XCTestCase {
    func testAggregatesMinutesFor30And90Days() {
        let now = Date()
        let calendar = Calendar.current

        let samples = [
            AppUsageSample(
                bundleId: "com.example.a",
                displayName: "App A",
                usedAt: calendar.date(byAdding: .day, value: -10, to: now) ?? now,
                durationSeconds: 1200 // 20m
            ),
            AppUsageSample(
                bundleId: "com.example.a",
                displayName: "App A",
                usedAt: calendar.date(byAdding: .day, value: -40, to: now) ?? now,
                durationSeconds: 1800 // 30m
            ),
            AppUsageSample(
                bundleId: "com.example.b",
                displayName: "App B",
                usedAt: calendar.date(byAdding: .day, value: -120, to: now) ?? now,
                durationSeconds: 3600 // out of 90d
            )
        ]

        let entries = UsageSnapshotFactory.makeEntries(from: samples, asOf: now)
        XCTAssertEqual(entries.count, 2)

        let appA = entries.first(where: { $0.bundleId == "com.example.a" })
        XCTAssertEqual(appA?.minutes30d, 20)
        XCTAssertEqual(appA?.minutes90d, 50)

        let appB = entries.first(where: { $0.bundleId == "com.example.b" })
        XCTAssertEqual(appB?.minutes30d, 0)
        XCTAssertEqual(appB?.minutes90d, 0)
    }
}
