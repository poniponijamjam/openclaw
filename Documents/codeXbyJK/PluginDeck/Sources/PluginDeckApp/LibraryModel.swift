import Foundation
import PluginDeckCore
import SwiftUI

enum Grouping: String, CaseIterable, Identifiable {
    case product = "제품"
    case vendor = "벤더"
    case format = "포맷"
    case drive = "드라이브"
    var id: String { rawValue }
}

enum QuickFilter: String, CaseIterable, Identifiable {
    case all = "전체"
    case intelOnly = "Intel 전용"
    case offline = "오프라인"
    case unusedFormats = "DAW에서 안 보임"
    case external = "외장 드라이브"
    case disabled = "비활성화됨"
    var id: String { rawValue }
}

struct LibrarySection: Identifiable {
    var id: String { title }
    var title: String
    var products: [Product]
}

@MainActor
final class LibraryModel: ObservableObject {
    @Published var bundles: [PluginBundle] = []
    @Published var missingLocations: [String] = []
    @Published var lastScan: Date?
    @Published var isScanning = false
    @Published var grouping: Grouping = .product
    @Published var filter: QuickFilter = .all
    @Published var searchText = ""
    @Published var selection: Product.ID?
    @Published var sheet: AppSheet?
    @Published var lastScripts: ScriptPair?
    @Published var leftoverProduct: Product?
    @Published var scriptError: String?
    @Published var settings: HostSettings { didSet { saveSettings() } }
    @Published var extraFolders: [String] { didSet { saveSettings() } }

    private let settingsKey = "PluginDeck.HostSettings"
    private let foldersKey = "PluginDeck.ExtraFolders"

    init() {
        let d = UserDefaults.standard
        settings = d.data(forKey: settingsKey).flatMap { try? JSONDecoder().decode(HostSettings.self, from: $0) } ?? HostSettings()
        extraFolders = d.stringArray(forKey: foldersKey) ?? []
    }

    private func saveSettings() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(settings) { d.set(data, forKey: settingsKey) }
        d.set(extraFolders, forKey: foldersKey)
    }

    func rescan() {
        guard !isScanning else { return }
        isScanning = true
        let locations = ScanLocations.all(settings: settings, extraFolders: extraFolders)
        Task.detached(priority: .userInitiated) {
            let result = PluginScanner().scan(locations)
            await MainActor.run {
                self.bundles = result.bundles
                self.missingLocations = result.missingLocations
                self.lastScan = result.scannedAt
                self.isScanning = false
            }
        }
    }

    // MARK: - 표시용 계산

    func visibleHosts(_ b: PluginBundle) -> [HostDAW] {
        HostDAW.allCases.filter { b.isVisible(in: $0, settings: settings) }
    }

    private func passes(_ b: PluginBundle) -> Bool {
        switch filter {
        case .all: return true
        case .intelOnly: return b.isIntelOnly
        case .offline: return b.status == .offline
        case .unusedFormats: return visibleHosts(b).isEmpty
        case .external: return b.volume?.isInternal == false
        case .disabled: return b.status == .disabled
        }
    }

    private var filteredBundles: [PluginBundle] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return bundles.filter { b in
            passes(b) && (q.isEmpty
                || b.name.lowercased().contains(q)
                || (b.vendor?.lowercased().contains(q) ?? false))
        }
    }

    var products: [Product] { ProductGrouper.group(filteredBundles) }

    var sections: [LibrarySection] {
        let items = products
        let keyed: [(String, Product)]
        switch grouping {
        case .product:
            return [LibrarySection(title: "모든 제품 (\(items.count))", products: items)]
        case .vendor:
            keyed = items.map { ($0.vendor ?? "알 수 없음", $0) }
        case .format:
            keyed = items.flatMap { p in p.formats.map { f in (f.displayName, p) } }
        case .drive:
            keyed = items.flatMap { p in
                Set(p.bundles.map { b in
                    let v = b.volume
                    return (v?.name ?? "알 수 없음") + ((v?.isOnline == false) ? " (연결 안 됨)" : "")
                }).map { ($0, p) }
            }
        }
        let dict = Dictionary(grouping: keyed, by: \.0)
        return dict.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.map { k in
            LibrarySection(title: "\(k) (\(dict[k]!.count))", products: dict[k]!.map(\.1))
        }
    }

    var selectedProduct: Product? {
        guard let selection else { return nil }
        return products.first { $0.id == selection }
    }

    var totalSize: Int64 { bundles.compactMap(\.sizeBytes).reduce(0, +) }
}
