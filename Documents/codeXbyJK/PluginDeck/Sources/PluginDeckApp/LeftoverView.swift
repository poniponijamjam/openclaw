import AppKit
import PluginDeckCore
import PluginDeckSkin
import SwiftUI

/// 제품 하나의 번들 + 잔여물을 한꺼번에 Vault로 옮기는 스크립트 만들기
struct LeftoverView: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var report: LeftoverReport?
    @State private var selected = Set<String>()
    @State private var searching = false

    var body: some View {
        let product = model.leftoverProduct
        let active = product?.bundles.filter { $0.status == .active } ?? []
        let extra = report?.leftovers.map(\.path).filter(selected.contains) ?? []
        RetroSheet(
            (product?.displayName ?? "?") + " cleanup",
            subtitle: [
                "플러그인 번들과 같이 남는 파일을 찾습니다. 확실한 것(설치 기록, 번들 ID 일치)만 기본 선택됩니다.",
                "앱은 파일을 옮기지 않습니다. 같은 드라이브의 Vault로 옮기는 스크립트와 복구 스크립트를 만듭니다.",
            ],
            width: 800,
            minBodyHeight: 400,
            footer: [
                RetroAction("Make script (\(active.count) + \(extra.count))", highlight: true,
                            enabled: report != nil && !(active.isEmpty && extra.isEmpty)) {
                    model.makeDisableScripts(active, extraPaths: extra)
                },
                RetroAction("Close", shortcut: .cancelAction) { dismiss() },
            ]
        ) {
            if product == nil {
                RetroText("제품이 선택되지 않았습니다.", tone: .warn)
            } else if searching {
                RetroBusy("CHECKING INSTALL RECEIPTS")
            } else if let product, let report {
                content(product, active, report)
            }
        }
        .onAppear(perform: search)
    }

    @ViewBuilder
    private func content(_ product: Product, _ active: [PluginBundle], _ report: LeftoverReport) -> some View {
        RetroSectionHeader("Plugin bundles - always included", count: active.count)
        ForEach(active) { b in RetroRow(tag: b.format.displayName, b.path) }
        if active.contains(where: { $0.format == .au }) {
            RetroText("AU가 포함되어 있습니다. Logic에서 이 제품이 사라집니다.", tone: .accent, size: 10)
        }

        RetroSectionHeader("Leftovers", count: report.leftovers.count)
        if report.leftovers.isEmpty { RetroText("찾은 것 없음", tone: .dim) }
        ForEach(report.leftovers) { l in leftoverRow(l) }

        if !report.packageIDs.isEmpty {
            RetroSectionHeader("Install receipts", count: report.packageIDs.count)
            ForEach(report.packageIDs, id: \.self) { RetroText($0, size: 10, selectable: true) }
            RetroText("설치 기록(pkgutil 영수증) 자체는 지우지 않습니다. 필요하면 직접: sudo pkgutil --forget <ID>", tone: .dim, size: 9)
        }
        if !report.otherPluginsInPackages.isEmpty {
            RetroSectionHeader("Other plugins in the same installer", count: report.otherPluginsInPackages.count)
            RetroText("여러 제품을 한 번에 설치하는 패키지입니다. 공용 파일은 다른 제품도 쓸 수 있습니다.", tone: .accent, size: 10)
            ForEach(report.otherPluginsInPackages, id: \.self) { RetroText($0, tone: .dim, size: 9) }
        }
    }

    private func leftoverRow(_ l: Leftover) -> some View {
        RetroCheckRow(isOn: Binding(
            get: { selected.contains(l.id) },
            set: { on in if on { selected.insert(l.id) } else { selected.remove(l.id) } }
        )) {
            VStack(alignment: .leading, spacing: 1) {
                RetroText(l.path, selectable: true)
                RetroText(l.reason + (l.sizeBytes.map { "  /  " + ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? ""),
                          tone: .dim, size: 9)
                if !l.sharedWith.isEmpty {
                    RetroText("같은 벤더의 다른 제품도 쓸 수 있음: " + l.sharedWith.prefix(5).joined(separator: ", ")
                              + (l.sharedWith.count > 5 ? " 외 \(l.sharedWith.count - 5)개" : ""), tone: .accent, size: 9)
                }
            }
            Spacer(minLength: 6)
            RetroText(confidenceText(l.confidence), tone: l.confidence == .high ? .good : l.confidence == .medium ? .accent : .warn,
                      size: 9, bold: true)
        }
    }

    private func confidenceText(_ c: Leftover.Confidence) -> String {
        switch c {
        case .high: return "SURE"
        case .medium: return "GUESS"
        case .low: return "SHARED"
        }
    }

    private func search() {
        guard let product = model.leftoverProduct, report == nil else { return }
        searching = true
        let all = ProductGrouper.group(model.bundles)
        Task {
            let r = await Task.detached(priority: .userInitiated) {
                LeftoverFinder().find(for: product, among: all)
            }.value
            report = r
            selected = Set(r.leftovers.filter { $0.confidence == .high }.map(\.id))
            searching = false
        }
    }
}
