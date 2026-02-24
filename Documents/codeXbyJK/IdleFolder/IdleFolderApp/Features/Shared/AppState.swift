import Foundation
import StoreKit

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .korean:
            return "ko"
        case .english:
            return "en"
        }
    }

    var label: String {
        switch self {
        case .korean:
            return "한국어"
        case .english:
            return "English"
        }
    }

    func text(ko: String, en: String) -> String {
        switch self {
        case .korean:
            return ko
        case .english:
            return en
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let screenTimeFeatureEnabled = false

    @Published var usages: [AppUsage] = []
    @Published var decisions: [String: AppDecision] = [:]
    @Published var tasks: [CleanupTask] = []
    @Published var rule: IdleRule
    @Published var whitelist: Set<String>
    @Published var didCompleteOnboarding = false
    @Published var useManualMode = true
    @Published var reminderEnabled: Bool
    @Published var reminderErrorMessage: String?
    @Published var useScreenTime: Bool
    @Published var screenTimeAuthStatus: ScreenTimeAuthorizationStatus
    @Published var scanInfoMessage: String?
    @Published var screenTimeSnapshotStatus: String = "스냅샷 없음"
    @Published var selectedLanguage: AppLanguage
    @Published var hasSelectedLanguage: Bool
    @Published var restoreInProgress: Bool = false
    @Published var restoreMessage: String?

    private let usageProvider: AppUsageProviding
    private let screenTimeUsageProvider: AppUsageProviding
    private let usageSnapshotReader: UsageSnapshotReading
    private let screenTimePermissionManager: ScreenTimePermissionManaging
    private let settingsStore: AppSettingsStore
    private let reminderScheduler: ReminderScheduler

    init(
        usageProvider: AppUsageProviding = MockAppUsageProvider(),
        screenTimeUsageProvider: AppUsageProviding = ScreenTimeUsageProvider(),
        usageSnapshotReader: UsageSnapshotReading = AppGroupUsageSnapshotStore(),
        screenTimePermissionManager: ScreenTimePermissionManaging = ScreenTimePermissionManager(),
        settingsStore: AppSettingsStore = AppSettingsStore(),
        reminderScheduler: ReminderScheduler = ReminderScheduler()
    ) {
        self.usageProvider = usageProvider
        self.screenTimeUsageProvider = screenTimeUsageProvider
        self.usageSnapshotReader = usageSnapshotReader
        self.screenTimePermissionManager = screenTimePermissionManager
        self.settingsStore = settingsStore
        self.reminderScheduler = reminderScheduler
        self.rule = settingsStore.loadRule()
        self.whitelist = settingsStore.loadWhitelist()
        self.reminderEnabled = settingsStore.loadReminderEnabled()
        if let savedLanguage = settingsStore.loadLanguage() {
            self.selectedLanguage = savedLanguage
            self.hasSelectedLanguage = true
        } else {
            self.selectedLanguage = .korean
            self.hasSelectedLanguage = false
        }
        self.useScreenTime = Self.screenTimeFeatureEnabled ? settingsStore.loadUseScreenTime() : false
        self.screenTimeAuthStatus = Self.screenTimeFeatureEnabled ? screenTimePermissionManager.authorizationStatus() : .unavailable
        if !Self.screenTimeFeatureEnabled {
            self.scanInfoMessage = "현재 빌드는 수동 모드 전용입니다."
            settingsStore.saveUseScreenTime(false)
        }
        refreshSnapshotStatus()
    }

    func runScan() async {
        scanInfoMessage = nil

        if !Self.screenTimeFeatureEnabled {
            await loadFromManualProvider()
            refreshSnapshotStatus()
            return
        }

        if useScreenTime {
            let status = screenTimePermissionManager.authorizationStatus()
            screenTimeAuthStatus = status

            if status != .approved {
                scanInfoMessage = "Screen Time 권한이 없어 수동 모드 데이터를 사용합니다."
                await loadFromManualProvider()
                refreshSnapshotStatus()
                return
            }

            do {
                usages = try await screenTimeUsageProvider.fetchUsages()
                recomputeDecisions()
                refreshSnapshotStatus()
                return
            } catch {
                scanInfoMessage = error.localizedDescription
            }
        }

        await loadFromManualProvider()
        refreshSnapshotStatus()
    }

    func setUseScreenTime(_ enabled: Bool) async {
        if !Self.screenTimeFeatureEnabled {
            useScreenTime = false
            settingsStore.saveUseScreenTime(false)
            screenTimeAuthStatus = .unavailable
            scanInfoMessage = "현재 빌드는 수동 모드 전용입니다."
            await runScan()
            return
        }

        if !enabled {
            useScreenTime = false
            settingsStore.saveUseScreenTime(false)
            screenTimeAuthStatus = screenTimePermissionManager.authorizationStatus()
            scanInfoMessage = "Screen Time 연동을 끄고 수동 모드로 전환했습니다."
            await runScan()
            refreshSnapshotStatus()
            return
        }

        do {
            let status = try await screenTimePermissionManager.requestAuthorization()
            screenTimeAuthStatus = status

            if status == .approved {
                useScreenTime = true
                settingsStore.saveUseScreenTime(true)
                scanInfoMessage = "Screen Time 권한이 승인되었습니다."
                await runScan()
            } else {
                useScreenTime = false
                settingsStore.saveUseScreenTime(false)
                scanInfoMessage = "Screen Time 권한이 승인되지 않아 수동 모드로 유지됩니다."
            }
        } catch {
            useScreenTime = false
            settingsStore.saveUseScreenTime(false)
            screenTimeAuthStatus = .unavailable
            scanInfoMessage = "Screen Time 권한 요청 오류: \(error.localizedDescription)"
        }

        refreshSnapshotStatus()
    }

    func requestScreenTimePermissionForQA() async {
        if !Self.screenTimeFeatureEnabled {
            screenTimeAuthStatus = .unavailable
            scanInfoMessage = "현재 빌드는 수동 모드 전용입니다."
            return
        }

        do {
            let status = try await screenTimePermissionManager.requestAuthorization()
            screenTimeAuthStatus = status
            scanInfoMessage = "Screen Time 권한 상태: \(status.rawValue)"
            if status == .approved {
                useScreenTime = true
                settingsStore.saveUseScreenTime(true)
                await runScan()
            }
        } catch {
            screenTimeAuthStatus = .unavailable
            scanInfoMessage = "Screen Time 권한 요청 오류: \(error.localizedDescription)"
        }
    }

    func setWhitelist(_ bundleId: String, enabled: Bool) {
        if enabled {
            whitelist.insert(bundleId)
        } else {
            whitelist.remove(bundleId)
        }
        settingsStore.saveWhitelist(whitelist)
        recomputeDecisions()
    }

    func updateRule(_ newRule: IdleRule) {
        rule = newRule
        settingsStore.saveRule(newRule)
        recomputeDecisions()
    }

    func setReminderEnabled(_ enabled: Bool) async {
        reminderErrorMessage = nil

        if enabled {
            do {
                let granted = try await reminderScheduler.requestAuthorization()
                guard granted else {
                    reminderEnabled = false
                    settingsStore.saveReminderEnabled(false)
                    reminderErrorMessage = "알림 권한이 허용되지 않았습니다. 설정 앱에서 권한을 켜주세요."
                    return
                }

                try await reminderScheduler.scheduleBiweeklyReminder()
                reminderEnabled = true
                settingsStore.saveReminderEnabled(true)
            } catch {
                reminderEnabled = false
                settingsStore.saveReminderEnabled(false)
                reminderErrorMessage = "리마인더를 설정하지 못했습니다. 잠시 후 다시 시도해주세요."
            }
        } else {
            reminderScheduler.cancelReminder()
            reminderEnabled = false
            settingsStore.saveReminderEnabled(false)
        }
    }

    func startSession(limit: Int = 5) {
        let targetApps = usages.filter {
            guard let decision = decisions[$0.bundleId] else { return false }
            return decision.idleClass == .idleConfirmed || decision.idleClass == .idleCandidate
        }

        tasks = Array(targetApps.prefix(limit)).map { app in
            CleanupTask(
                id: UUID(),
                bundleId: app.bundleId,
                status: .pending,
                recommendedAction: IdleClassifier.recommendAction(for: decisions[app.bundleId]?.idleClass ?? .active)
            )
        }
    }

    func markTask(_ id: UUID, status: TaskStatus) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].status = status
    }

    func appName(for bundleId: String) -> String {
        usages.first(where: { $0.bundleId == bundleId })?.displayName ?? bundleId
    }

    func idleClass(for bundleId: String) -> IdleClass {
        decisions[bundleId]?.idleClass ?? .active
    }

    private func loadFromManualProvider() async {
        do {
            usages = try await usageProvider.fetchUsages()
            recomputeDecisions()
        } catch {
            usages = []
            decisions = [:]
            tasks = []
        }
    }

    private func refreshSnapshotStatus() {
        do {
            let snapshot = try usageSnapshotReader.loadLatestSnapshot()
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let dateText = formatter.string(from: snapshot.generatedAt)
            screenTimeSnapshotStatus = "최근 스냅샷: \(dateText), 앱 \(snapshot.entries.count)개"
        } catch UsageSnapshotStoreError.noSnapshot {
            screenTimeSnapshotStatus = "최근 스냅샷: 없음"
        } catch UsageSnapshotStoreError.corruptData {
            screenTimeSnapshotStatus = "최근 스냅샷: 손상됨"
        } catch {
            screenTimeSnapshotStatus = "최근 스냅샷: 확인 불가"
        }
    }

    func refreshSnapshotStatusForQA() {
        refreshSnapshotStatus()
    }

    func restorePurchases() async {
        restoreInProgress = true
        restoreMessage = nil

        do {
            try await AppStore.sync()

            var restoredProductIds: [String] = []
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else { continue }
                restoredProductIds.append(transaction.productID)
            }

            if restoredProductIds.isEmpty {
                restoreMessage = selectedLanguage.text(
                    ko: "복원 완료: 활성 구매 내역이 없습니다.",
                    en: "Restore completed: no active purchases found."
                )
            } else {
                let count = Set(restoredProductIds).count
                restoreMessage = selectedLanguage.text(
                    ko: "복원 완료: \(count)개 상품이 확인되었습니다.",
                    en: "Restore completed: \(count) product(s) restored."
                )
            }
        } catch {
            restoreMessage = selectedLanguage.text(
                ko: "복원 실패: \(error.localizedDescription)",
                en: "Restore failed: \(error.localizedDescription)"
            )
        }

        restoreInProgress = false
    }

    func selectLanguage(_ language: AppLanguage) {
        selectedLanguage = language
        hasSelectedLanguage = true
        settingsStore.saveLanguage(language)
    }

    private func recomputeDecisions() {
        var updated: [String: AppDecision] = [:]
        for app in usages {
            let whitelisted = whitelist.contains(app.bundleId)
            let idleClass = IdleClassifier.classify(app: app, rule: rule, isWhitelisted: whitelisted)
            updated[app.bundleId] = AppDecision(bundleId: app.bundleId, idleClass: idleClass, isWhitelisted: whitelisted)
        }
        decisions = updated

        tasks = tasks.map { task in
            var item = task
            item.recommendedAction = IdleClassifier.recommendAction(for: updated[task.bundleId]?.idleClass ?? .active)
            return item
        }
    }
}
