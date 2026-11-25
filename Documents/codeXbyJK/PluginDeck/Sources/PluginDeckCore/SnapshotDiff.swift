import Foundation

/// 예전 맥 스냅샷(JSON) vs 지금 스캔 결과 비교.
/// 제품 단위로 묶어서(ProductGrouper와 같은 이름 규칙) 비교한다.
public struct SnapshotDiff: Sendable {
    public struct MissingFormats: Identifiable, Hashable, Sendable {
        public var id: String { productKey }
        public var productKey: String
        public var displayName: String
        public var vendor: String?
        public var missing: [PluginFormat]
    }

    public struct VersionChange: Identifiable, Hashable, Sendable {
        public enum Direction: String, Sendable { case newer, older, different }
        public var id: String { productKey + "|" + format.rawValue }
        public var productKey: String
        public var displayName: String
        public var format: PluginFormat
        public var oldVersion: String
        public var newVersion: String
        public var direction: Direction
    }

    public var oldMachine: String
    public var oldDate: Date
    /// 예전 맥에는 (활성으로) 있었는데 지금은 어떤 형태로도 없는 제품 -> 재설치 대상
    public var missingProducts: [Product]
    /// 제품은 있지만 예전에 있던 포맷 일부가 빠짐 (예: AU가 없어서 Logic에서 안 보임)
    public var missingFormats: [MissingFormats]
    /// 같은 제품·포맷의 버전이 다름
    public var versionChanges: [VersionChange]
    /// 지금 맥에만 있는 제품
    public var newProducts: [Product]
    /// 예전 맥에서도 비활성화(Vault)돼 있던 제품 -> 재설치 목록에서 제외
    public var ignoredDisabled: [Product]
}

public enum SnapshotComparer {
    public static func compare(old: PluginSnapshot, current: [PluginBundle]) -> SnapshotDiff {
        let oldProducts = ProductGrouper.group(old.bundles)
        let newProducts = ProductGrouper.group(current)
        let newByKey = Dictionary(newProducts.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let oldKeys = Set(oldProducts.map(\.id))

        var missing: [Product] = []
        var missingFormats: [SnapshotDiff.MissingFormats] = []
        var versions: [SnapshotDiff.VersionChange] = []
        var ignored: [Product] = []

        for op in oldProducts {
            let oldActive = op.bundles.filter { $0.status != .disabled }
            if oldActive.isEmpty {
                ignored.append(op)
                continue
            }
            guard let np = newByKey[op.id] else {
                missing.append(Product(id: op.id, displayName: op.displayName, vendor: op.vendor, bundles: oldActive))
                continue
            }
            // 지금 맥에 있는 포맷 (비활성화된 것도 "있음"으로 본다: 일부러 끈 것)
            let nowFormats = Set(np.bundles.map(\.format))
            let lost = PluginFormat.allCases.filter { f in
                oldActive.contains { $0.format == f } && !nowFormats.contains(f)
            }
            if !lost.isEmpty {
                missingFormats.append(.init(productKey: op.id, displayName: op.displayName, vendor: op.vendor, missing: lost))
            }
            for f in PluginFormat.allCases {
                guard let ov = oldActive.first(where: { $0.format == f })?.version,
                      let nv = np.bundles.first(where: { $0.format == f })?.version,
                      ov != nv else { continue }
                versions.append(.init(productKey: op.id, displayName: op.displayName, format: f,
                                      oldVersion: ov, newVersion: nv, direction: direction(old: ov, new: nv)))
            }
        }

        let added = newProducts.filter { !oldKeys.contains($0.id) }
        let byName: (Product, Product) -> Bool = {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        return SnapshotDiff(
            oldMachine: old.machineName,
            oldDate: old.createdAt,
            missingProducts: missing.sorted(by: byName),
            missingFormats: missingFormats.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending },
            versionChanges: versions.sorted { ($0.displayName.lowercased(), $0.format.rawValue) < ($1.displayName.lowercased(), $1.format.rawValue) },
            newProducts: added.sorted(by: byName),
            ignoredDisabled: ignored.sorted(by: byName)
        )
    }

    /// "1.10.0" > "1.9.2" 처럼 숫자 단위로 비교
    static func direction(old: String, new: String) -> SnapshotDiff.VersionChange.Direction {
        switch new.compare(old, options: .numeric) {
        case .orderedDescending: return .newer
        case .orderedAscending: return .older
        case .orderedSame: return .different
        }
    }

    /// 재설치 체크리스트 (빠진 제품 + 빠진 포맷)
    public static func reinstallMarkdown(_ diff: SnapshotDiff, currentMachine: String, date: Date = Date()) -> String {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]
        var lines = [
            "# 다시 설치할 플러그인 - \(diff.oldMachine) -> \(currentMachine)",
            "",
            "예전 스냅샷: \(df.string(from: diff.oldDate)) / 비교일: \(df.string(from: date))",
            "",
            "빠진 제품 \(diff.missingProducts.count)개, 포맷 일부 빠짐 \(diff.missingFormats.count)개",
            "",
        ]

        if !diff.missingProducts.isEmpty {
            lines += ["## 빠진 제품", ""]
            let byVendor = Dictionary(grouping: diff.missingProducts) { $0.vendor ?? "알 수 없음" }
            for vendor in byVendor.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
                lines.append("### \(vendor)")
                lines.append("")
                for p in byVendor[vendor]! { lines.append(ChecklistExporter.line(for: p)) }
                lines.append("")
            }
        }
        if !diff.missingFormats.isEmpty {
            lines += ["## 포맷 일부 빠짐", ""]
            for m in diff.missingFormats {
                let fs = m.missing.map(\.displayName).joined(separator: ", ")
                var why: [String] = []
                if m.missing.contains(.au) { why.append("Logic에서 안 보임") }
                if m.missing.contains(.vst3) { why.append("Ableton VST3 없음") }
                let suffix = why.isEmpty ? "" : " (" + why.joined(separator: ", ") + ")"
                lines.append("- [ ] \(m.displayName) (\(m.vendor ?? "알 수 없음")) - \(fs) 없음\(suffix)")
            }
            lines.append("")
        }
        if diff.missingProducts.isEmpty && diff.missingFormats.isEmpty {
            lines += ["빠진 플러그인이 없습니다.", ""]
        }
        return lines.joined(separator: "\n")
    }
}
