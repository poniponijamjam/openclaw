import AppKit
import PluginDeckCore
import SwiftUI

/// 제품 하나의 번들 + 잔여물을 한꺼번에 Vault로 옮기는 스크립트 만들기
struct LeftoverView: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var report: LeftoverReport?
    @State private var selected = Set<String>()
    @State private var searching = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let product = model.leftoverProduct {
                Text("\(product.displayName) 정리").font(.title2.bold())
                Text("플러그인 번들과 같이 남는 파일을 찾습니다. 확실한 것(설치 기록, 번들 ID 일치)만 기본 선택됩니다.")
                    .foregroundStyle(.secondary)

                if searching {
                    HStack { ProgressView().controlSize(.small); Text("찾는 중... (설치 기록 확인)") }
                } else if let report {
                    content(product, report)
                }
            } else {
                Text("제품이 선택되지 않았습니다.")
            }
            HStack {
                Spacer()
                Button("닫기") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 780)
        .onAppear(perform: search)
    }

    @ViewBuilder
    private func content(_ product: Product, _ report: LeftoverReport) -> some View {
        let activeBundles = product.bundles.filter { $0.status == .active }
        List {
            SwiftUI.Section("플러그인 번들 (\(activeBundles.count)) - 항상 포함") {
                ForEach(activeBundles) { b in
                    HStack {
                        Text(b.format.displayName).font(.caption.monospaced()).frame(width: 44, alignment: .leading)
                        Text(b.path).font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                    }
                }
                if product.bundles.contains(where: { $0.format == .au && $0.status == .active }) {
                    Text("AU가 포함되어 있습니다. Logic에서 이 제품이 사라집니다.").font(.caption).foregroundStyle(.orange)
                }
            }
            SwiftUI.Section("잔여물 후보 (\(report.leftovers.count))") {
                if report.leftovers.isEmpty { Text("찾은 것 없음").foregroundStyle(.secondary) }
                ForEach(report.leftovers) { l in leftoverRow(l) }
            }
            if !report.packageIDs.isEmpty {
                SwiftUI.Section("설치 패키지 기록") {
                    ForEach(report.packageIDs, id: \.self) { Text($0).font(.caption.monospaced()) }
                    Text("설치 기록(pkgutil 영수증) 자체는 지우지 않습니다. 필요하면 직접: sudo pkgutil --forget <ID>")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if !report.otherPluginsInPackages.isEmpty {
                SwiftUI.Section("같은 설치 패키지에 들어 있는 다른 플러그인 (\(report.otherPluginsInPackages.count))") {
                    Text("여러 제품을 한 번에 설치하는 패키지입니다. 공용 파일은 다른 제품도 쓸 수 있습니다.")
                        .font(.caption).foregroundStyle(.orange)
                    ForEach(report.otherPluginsInPackages, id: \.self) { Text($0).font(.caption.monospaced()) }
                }
            }
        }
        .frame(minHeight: 380)

        Text("앱은 파일을 옮기지 않습니다. 스크립트를 만들면 같은 드라이브의 Vault로 옮기는 명령과 복구 명령이 생성됩니다.")
            .font(.caption).foregroundStyle(.secondary)
        Button("번들 \(activeBundles.count)개 + 잔여물 \(selected.count)개 비활성화 스크립트 만들기") {
            model.makeDisableScripts(activeBundles, extraPaths: report.leftovers.map(\.path).filter(selected.contains))
        }
        .disabled(activeBundles.isEmpty && selected.isEmpty)
    }

    private func leftoverRow(_ l: Leftover) -> some View {
        HStack(alignment: .top) {
            Toggle("", isOn: Binding(
                get: { selected.contains(l.id) },
                set: { on in if on { selected.insert(l.id) } else { selected.remove(l.id) } }
            ))
            .labelsHidden()
            VStack(alignment: .leading, spacing: 2) {
                Text(l.path).font(.caption.monospaced()).textSelection(.enabled)
                Text(l.reason + (l.sizeBytes.map { "  /  " + ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? ""))
                    .font(.caption).foregroundStyle(.secondary)
                if !l.sharedWith.isEmpty {
                    Text("같은 벤더의 다른 제품도 쓸 수 있음: " + l.sharedWith.prefix(5).joined(separator: ", ")
                         + (l.sharedWith.count > 5 ? " 외 \(l.sharedWith.count - 5)개" : ""))
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            Text(confidenceText(l.confidence)).font(.caption.bold())
                .foregroundStyle(l.confidence == .high ? Color.green : l.confidence == .medium ? Color.orange : Color.red)
        }
    }

    private func confidenceText(_ c: Leftover.Confidence) -> String {
        switch c {
        case .high: return "확실"
        case .medium: return "추정"
        case .low: return "공용"
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
