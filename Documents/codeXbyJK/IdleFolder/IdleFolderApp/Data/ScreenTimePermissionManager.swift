import Foundation

#if canImport(FamilyControls)
import FamilyControls
#endif

struct ScreenTimePermissionManager: ScreenTimePermissionManaging {
    func authorizationStatus() -> ScreenTimeAuthorizationStatus {
        #if canImport(FamilyControls)
        switch AuthorizationCenter.shared.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .approved:
            return .approved
        case .denied:
            return .denied
        @unknown default:
            return .unavailable
        }
        #else
        return .unavailable
        #endif
    }

    func requestAuthorization() async throws -> ScreenTimeAuthorizationStatus {
        #if canImport(FamilyControls)
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        return authorizationStatus()
        #else
        return .unavailable
        #endif
    }
}
