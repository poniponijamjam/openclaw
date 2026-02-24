import Foundation

protocol AppUsageProviding {
    func fetchUsages() async throws -> [AppUsage]
}

enum AppUsageProviderError: Error {
    case unavailable(String)
}

extension AppUsageProviderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return reason
        }
    }
}

enum ScreenTimeAuthorizationStatus: String {
    case notDetermined
    case approved
    case denied
    case unavailable
}

protocol ScreenTimePermissionManaging {
    func authorizationStatus() -> ScreenTimeAuthorizationStatus
    func requestAuthorization() async throws -> ScreenTimeAuthorizationStatus
}
