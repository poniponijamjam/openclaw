import Foundation

/// JSON 스냅샷. 나중에(M4) 다른 맥의 스냅샷과 비교하는 데 쓴다.
public struct PluginSnapshot: Codable, Sendable {
    public static let currentSchema = 1

    public var schemaVersion: Int
    public var createdAt: Date
    public var machineName: String
    public var bundles: [PluginBundle]

    public init(createdAt: Date = Date(), machineName: String, bundles: [PluginBundle]) {
        self.schemaVersion = Self.currentSchema
        self.createdAt = createdAt
        self.machineName = machineName
        self.bundles = bundles
    }

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return try e.encode(self)
    }

    public static func decode(_ data: Data) throws -> PluginSnapshot {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try d.decode(PluginSnapshot.self, from: data)
    }
}

/// 재설치용 Markdown 체크리스트 (벤더별 묶음).
public enum ChecklistExporter {
    public static func markdown(products: [Product], machineName: String, date: Date = Date()) -> String {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]

        var lines: [String] = [
            "# 플러그인 체크리스트 - \(machineName)",
            "",
            "생성일: \(df.string(from: date)) / 제품 \(products.count)개",
            "",
        ]

        let byVendor = Dictionary(grouping: products) { $0.vendor ?? "알 수 없음" }
        for vendor in byVendor.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
            let items = byVendor[vendor]!.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            lines.append("## \(vendor) (\(items.count))")
            lines.append("")
            for p in items { lines.append(line(for: p)) }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    static func line(for p: Product) -> String {
        let version = p.bundles.compactMap(\.version).first.map { " \($0)" } ?? ""
        let formats = p.formats.map(\.displayName).joined(separator: ", ")
        var notes: [String] = []
        if p.bundles.contains(where: \.isIntelOnly) { notes.append("Intel 전용") }
        if p.bundles.contains(where: { $0.status == .offline }) { notes.append("드라이브 연결 안 됨") }
        let external = Set(p.bundles.compactMap { b in b.volume?.isInternal == false ? b.volume?.name : nil })
        if !external.isEmpty { notes.append("외장: " + external.sorted().joined(separator: ", ")) }
        let suffix = notes.isEmpty ? "" : " (" + notes.joined(separator: ", ") + ")"
        return "- [ ] \(p.displayName)\(version) - \(formats)\(suffix)"
    }
}
