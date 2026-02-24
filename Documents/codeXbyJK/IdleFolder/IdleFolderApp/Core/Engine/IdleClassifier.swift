import Foundation

struct IdleClassifier {
    static func classify(
        app: AppUsage,
        rule: IdleRule,
        isWhitelisted: Bool
    ) -> IdleClass {
        if isWhitelisted {
            return .excluded
        }
        if app.minutes30d <= rule.confirmMinutesThreshold {
            return .idleConfirmed
        }
        if app.minutes90d < rule.candidateMinutesThreshold {
            return .idleCandidate
        }
        return .active
    }

    static func recommendAction(for idleClass: IdleClass) -> RecommendedAction {
        switch idleClass {
        case .idleConfirmed:
            return .removeFromHomeScreen
        case .idleCandidate:
            return .moveToIdleFolder
        case .excluded, .active:
            return .moveToIdleFolder
        }
    }
}
