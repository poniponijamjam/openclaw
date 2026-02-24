import Foundation

struct AppUsage: Identifiable, Codable, Hashable {
    var id: String { bundleId }
    let bundleId: String
    let displayName: String
    let lastUsedAt: Date?
    let minutes30d: Int
    let minutes90d: Int
}

enum IdleClass: String, Codable, CaseIterable {
    case idleConfirmed
    case idleCandidate
    case active
    case excluded
}

struct IdleRule: Codable, Hashable {
    var confirmMinutesThreshold: Int = 0
    var candidateMinutesThreshold: Int = 5
}

struct AppDecision: Codable, Hashable {
    let bundleId: String
    var idleClass: IdleClass
    var isWhitelisted: Bool
}

enum RecommendedAction: String, Codable, CaseIterable {
    case moveToIdleFolder
    case removeFromHomeScreen
    case offload
    case delete

    var title: String {
        switch self {
        case .moveToIdleFolder: return "Idle 폴더로 모으기"
        case .removeFromHomeScreen: return "홈 화면에서 제거"
        case .offload: return "오프로드"
        case .delete: return "삭제"
        }
    }
}

enum TaskStatus: String, Codable {
    case pending
    case done
    case skipped
}

struct CleanupTask: Identifiable, Codable, Hashable {
    let id: UUID
    let bundleId: String
    var status: TaskStatus
    var recommendedAction: RecommendedAction
}
