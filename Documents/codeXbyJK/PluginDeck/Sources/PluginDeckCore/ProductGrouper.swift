import Foundation

/// 같은 제품의 AU / VST2 / VST3 / CLAP / AAX 번들을 하나로 묶는다.
public enum ProductGrouper {
    public static func group(_ bundles: [PluginBundle]) -> [Product] {
        var buckets: [String: [PluginBundle]] = [:]
        var order: [String] = []
        for b in bundles {
            let key = key(for: b)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(b)
        }
        return order.map { key in
            let items = buckets[key]!.sorted { $0.format.rawValue < $1.format.rawValue }
            let vendor = items.compactMap(\.vendor).first
            return Product(id: key, displayName: items[0].name, vendor: vendor, bundles: items)
        }
    }

    /// 키 = 정규화한 이름. 포맷마다 벤더 표기가 달라서(AU는 "FabFilter", VST3 번들 ID는 "fabfilter")
    /// 벤더는 키에 넣지 않는다. 다른 회사의 동명 제품이 합쳐질 수 있음 -> M2에서 수동 분리 제공 예정.
    static func key(for bundle: PluginBundle) -> String {
        normalize(bundle.name)
    }

    static func normalize(_ name: String) -> String {
        var s = name.lowercased()
        for suffix in [" (mono)", " (stereo)", " mono", " stereo", " au", " vst3", " vst"] where s.hasSuffix(suffix) {
            s.removeLast(suffix.count)
        }
        return s.filter { $0.isLetter || $0.isNumber }
    }
}
