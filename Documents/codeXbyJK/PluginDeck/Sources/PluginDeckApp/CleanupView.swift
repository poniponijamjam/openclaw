import AppKit
import PluginDeckCore
import SwiftUI
import UniformTypeIdentifiers

extension LibraryModel {
    var cleanupPlan: CleanupPlan { CleanupRules.plan(for: ProductGrouper.group(bundles)) }

    var machineName: String { Host.current().localizedName ?? "Mac" }

    func exportMarkdown() {
        let text = ChecklistExporter.markdown(products: ProductGrouper.group(bundles), machineName: machineName)
        save(Data(text.utf8), suggestedName: "plugins-checklist.md", type: UTType(filenameExtension: "md") ?? .plainText)
    }

    func exportJSON() {
        do {
            let data = try PluginSnapshot(machineName: machineName, bundles: bundles).encoded()
            save(data, suggestedName: "plugins-snapshot.json", type: .json)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func save(_ data: Data, suggestedName: String, type: UTType) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [type]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try data.write(to: url) } catch { NSAlert(error: error).runModal() }
    }
}

/// 중복 정리 제안 + 선택한 VST2의 비활성화 스크립트 생성
struct CleanupView: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    /// 체크 해제한 VST2 번들 (기본은 전부 선택)
    @State private var excluded = Set<String>()

    var body: some View {
        let plan = model.cleanupPlan
        let selected = plan.redundantVST2.filter { !excluded.contains($0.id) }
        let conflicts = VaultLayout().conflicts(withScanFolders: model.settings.customFolders + model.extraFolders,
                                                forOriginals: selected.map(\.path))
        VStack(alignment: .leading, spacing: 12) {
            Text("중복 정리 제안").font(.title2.bold())
            Text("규칙: Logic은 AU, Ableton은 VST3. AU는 건드리지 않고, VST3가 있는 제품의 VST2만 비활성화 후보로 봅니다.")
                .foregroundStyle(.secondary)

            List {
                SwiftUI.Section("VST2 비활성화 후보 - VST3 있음 (\(plan.redundantVST2.count))") {
                    if plan.redundantVST2.isEmpty { Text("없음").foregroundStyle(.secondary) }
                    ForEach(plan.redundantVST2) { b in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { !excluded.contains(b.id) },
                                set: { on in if on { excluded.remove(b.id) } else { excluded.insert(b.id) } }
                            ))
                            .labelsHidden()
                            Text(b.name)
                            Spacer()
                            Text(b.path).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
                SwiftUI.Section("Ableton에서 AU를 끄면 사라지는 제품 (\(plan.auOnlyProducts.count))") {
                    if plan.auOnlyProducts.isEmpty { Text("없음 - Ableton에서 AU를 꺼도 빠지는 제품 없음").foregroundStyle(.secondary) }
                    ForEach(plan.auOnlyProducts) { p in
                        HStack {
                            Text(p.displayName)
                            Spacer()
                            Text(p.vendor ?? "알 수 없음").foregroundStyle(.secondary)
                        }
                    }
                }
                SwiftUI.Section("VST2만 있는 제품 - 유지 (\(plan.vst2OnlyProducts.count))") {
                    if plan.vst2OnlyProducts.isEmpty { Text("없음").foregroundStyle(.secondary) }
                    ForEach(plan.vst2OnlyProducts) { p in
                        HStack {
                            Text(p.displayName)
                            Spacer()
                            Text(p.vendor ?? "알 수 없음").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(minHeight: 360)

            if !conflicts.isEmpty {
                Text("주의: Vault 폴더가 스캔 폴더 안에 있습니다. 비활성화해도 Ableton에 계속 보일 수 있습니다: " + conflicts.joined(separator: ", "))
                    .font(.caption).foregroundStyle(.orange)
            }
            Text("스크립트만 만듭니다. 파일은 터미널에서 직접 실행해야 옮겨집니다. 복구 스크립트가 같이 만들어집니다.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Button("선택한 VST2 \(selected.count)개 비활성화 스크립트 만들기") {
                    // 시트를 닫지 않고 결과 화면으로 교체
                    model.makeDisableScripts(selected)
                }
                .disabled(selected.isEmpty)
                Spacer()
                Button("닫기") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 720)
    }
}
