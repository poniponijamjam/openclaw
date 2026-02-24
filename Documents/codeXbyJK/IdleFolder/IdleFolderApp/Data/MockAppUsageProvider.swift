import Foundation

struct MockAppUsageProvider: AppUsageProviding {
    func fetchUsages() async throws -> [AppUsage] {
        let now = Date()
        return [
            AppUsage(bundleId: "com.example.game1", displayName: "Puzzle Blast", lastUsedAt: Calendar.current.date(byAdding: .day, value: -80, to: now), minutes30d: 0, minutes90d: 4),
            AppUsage(bundleId: "com.example.shopping", displayName: "ShopDay", lastUsedAt: Calendar.current.date(byAdding: .day, value: -35, to: now), minutes30d: 0, minutes90d: 0),
            AppUsage(bundleId: "com.example.video", displayName: "ClipNow", lastUsedAt: Calendar.current.date(byAdding: .day, value: -4, to: now), minutes30d: 64, minutes90d: 210),
            AppUsage(bundleId: "com.example.travel", displayName: "TravelPass", lastUsedAt: Calendar.current.date(byAdding: .day, value: -120, to: now), minutes30d: 0, minutes90d: 2),
            AppUsage(bundleId: "com.example.bank", displayName: "MyBank", lastUsedAt: Calendar.current.date(byAdding: .day, value: -20, to: now), minutes30d: 3, minutes90d: 8)
        ]
    }
}
