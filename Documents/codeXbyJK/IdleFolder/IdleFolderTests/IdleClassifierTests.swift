import XCTest
@testable import IdleFolder

final class IdleClassifierTests: XCTestCase {
    func testClassifiesWhitelistedAsExcluded() {
        let app = AppUsage(
            bundleId: "com.example.bank",
            displayName: "Bank",
            lastUsedAt: nil,
            minutes30d: 0,
            minutes90d: 0
        )

        let result = IdleClassifier.classify(app: app, rule: IdleRule(), isWhitelisted: true)
        XCTAssertEqual(result, .excluded)
    }

    func testClassifiesConfirmedWhen30DayUsageIsZero() {
        let app = AppUsage(
            bundleId: "com.example.game",
            displayName: "Game",
            lastUsedAt: nil,
            minutes30d: 0,
            minutes90d: 10
        )

        let result = IdleClassifier.classify(app: app, rule: IdleRule(), isWhitelisted: false)
        XCTAssertEqual(result, .idleConfirmed)
    }

    func testClassifiesCandidateWhen90DayUsageIsBelowThreshold() {
        let app = AppUsage(
            bundleId: "com.example.travel",
            displayName: "Travel",
            lastUsedAt: nil,
            minutes30d: 3,
            minutes90d: 4
        )

        let result = IdleClassifier.classify(app: app, rule: IdleRule(), isWhitelisted: false)
        XCTAssertEqual(result, .idleCandidate)
    }

    func testClassifiesActiveForRegularUse() {
        let app = AppUsage(
            bundleId: "com.example.video",
            displayName: "Video",
            lastUsedAt: nil,
            minutes30d: 20,
            minutes90d: 90
        )

        let result = IdleClassifier.classify(app: app, rule: IdleRule(), isWhitelisted: false)
        XCTAssertEqual(result, .active)
    }
}
