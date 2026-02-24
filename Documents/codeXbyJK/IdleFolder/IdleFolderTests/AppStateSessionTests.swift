import XCTest
@testable import IdleFolder

private struct StubUsageProvider: AppUsageProviding {
    let apps: [AppUsage]

    func fetchUsages() async throws -> [AppUsage] {
        apps
    }
}

@MainActor
final class AppStateSessionTests: XCTestCase {
    func testStartSessionSelectsOnlyIdleAppsWithLimit() async {
        let apps = [
            AppUsage(bundleId: "a", displayName: "A", lastUsedAt: nil, minutes30d: 0, minutes90d: 0),
            AppUsage(bundleId: "b", displayName: "B", lastUsedAt: nil, minutes30d: 1, minutes90d: 2),
            AppUsage(bundleId: "c", displayName: "C", lastUsedAt: nil, minutes30d: 30, minutes90d: 60),
            AppUsage(bundleId: "d", displayName: "D", lastUsedAt: nil, minutes30d: 0, minutes90d: 0)
        ]

        let sut = AppState(
            usageProvider: StubUsageProvider(apps: apps),
            settingsStore: AppSettingsStore(defaults: UserDefaults(suiteName: #function)!),
            reminderScheduler: ReminderScheduler()
        )

        await sut.runScan()
        sut.startSession(limit: 2)

        XCTAssertEqual(sut.tasks.count, 2)
        XCTAssertTrue(sut.tasks.allSatisfy { task in
            let idleClass = sut.idleClass(for: task.bundleId)
            return idleClass == .idleConfirmed || idleClass == .idleCandidate
        })
    }

    func testMarkTaskUpdatesStatus() async {
        let apps = [
            AppUsage(bundleId: "a", displayName: "A", lastUsedAt: nil, minutes30d: 0, minutes90d: 0)
        ]

        let sut = AppState(
            usageProvider: StubUsageProvider(apps: apps),
            settingsStore: AppSettingsStore(defaults: UserDefaults(suiteName: #function)!),
            reminderScheduler: ReminderScheduler()
        )

        await sut.runScan()
        sut.startSession(limit: 1)

        guard let id = sut.tasks.first?.id else {
            XCTFail("Expected one task")
            return
        }

        sut.markTask(id, status: .done)
        XCTAssertEqual(sut.tasks.first?.status, .done)
    }
}
