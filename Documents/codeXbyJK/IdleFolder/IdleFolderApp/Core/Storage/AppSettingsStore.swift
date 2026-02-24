import Foundation

final class AppSettingsStore {
    private enum Keys {
        static let rule = "idle_rule"
        static let whitelist = "idle_whitelist"
        static let reminderEnabled = "reminder_enabled"
        static let useScreenTime = "use_screentime"
        static let language = "app_language"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadRule() -> IdleRule {
        guard let data = defaults.data(forKey: Keys.rule),
              let rule = try? JSONDecoder().decode(IdleRule.self, from: data) else {
            return IdleRule()
        }
        return rule
    }

    func saveRule(_ rule: IdleRule) {
        guard let data = try? JSONEncoder().encode(rule) else { return }
        defaults.set(data, forKey: Keys.rule)
    }

    func loadWhitelist() -> Set<String> {
        let items = defaults.stringArray(forKey: Keys.whitelist) ?? []
        return Set(items)
    }

    func saveWhitelist(_ whitelist: Set<String>) {
        defaults.set(Array(whitelist).sorted(), forKey: Keys.whitelist)
    }

    func loadReminderEnabled() -> Bool {
        defaults.bool(forKey: Keys.reminderEnabled)
    }

    func saveReminderEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.reminderEnabled)
    }

    func loadUseScreenTime() -> Bool {
        defaults.bool(forKey: Keys.useScreenTime)
    }

    func saveUseScreenTime(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.useScreenTime)
    }

    func loadLanguage() -> AppLanguage? {
        guard let raw = defaults.string(forKey: Keys.language) else { return nil }
        return AppLanguage(rawValue: raw)
    }

    func saveLanguage(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: Keys.language)
    }
}
