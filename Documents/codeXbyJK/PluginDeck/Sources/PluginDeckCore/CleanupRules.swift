import Foundation

/// 중복 정리 제안. 파일은 건드리지 않고 후보만 계산한다.
public struct CleanupPlan: Sendable {
    /// 같은 제품에 VST3가 있는 VST2 번들 -> 비활성화 후보
    public var redundantVST2: [PluginBundle]
    /// Ableton에서 AU를 끄면 사라지는 제품 (AU는 있고 활성 VST2/VST3가 없음)
    public var auOnlyProducts: [Product]
    /// VST3 없이 VST2만 있는 제품 (VST2를 지우면 Ableton에서 사라짐 -> 유지 대상)
    public var vst2OnlyProducts: [Product]
}

public enum CleanupRules {
    public static func plan(for products: [Product]) -> CleanupPlan {
        var redundant: [PluginBundle] = []
        var auOnly: [Product] = []
        var vst2Only: [Product] = []

        for p in products {
            let active = p.bundles.filter { $0.status == .active }
            let has = { (f: PluginFormat) in active.contains { $0.format == f } }

            if has(.vst3) {
                redundant += active.filter { $0.format == .vst2 }
            } else if has(.vst2) {
                vst2Only.append(p)
            }
            if has(.au) && !has(.vst3) && !has(.vst2) {
                auOnly.append(p)
            }
        }

        let byName: (Product, Product) -> Bool = {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        return CleanupPlan(
            redundantVST2: redundant.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            auOnlyProducts: auOnly.sorted(by: byName),
            vst2OnlyProducts: vst2Only.sorted(by: byName)
        )
    }
}
