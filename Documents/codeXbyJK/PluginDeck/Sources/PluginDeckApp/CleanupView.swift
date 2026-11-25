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

/// 중복 정리 제안 (M2: 보기만. 이동 스크립트 생성은 M3)
struct CleanupView: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let plan = model.cleanupPlan
        VStack(alignment: .leading, spacing: 12) {
            Text("중복 정리 제안").font(.title2.bold())
            Text("규칙: Logic은 AU, Ableton은 VST3. AU는 건드리지 않고, VST3가 있는 제품의 VST2만 비활성화 후보로 봅니다.")
                .foregroundStyle(.secondary)

            List {
                SwiftUI.Section("VST2 비활성화 후보 - VST3 있음 (\(plan.redundantVST2.count))") {
                    if plan.redundantVST2.isEmpty { Text("없음").foregroundStyle(.secondary) }
                    ForEach(plan.redundantVST2) { b in
                        HStack {
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

            Text("이동 스크립트 생성은 다음 단계(M3)에서 추가됩니다. 지금은 확인용입니다.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("닫기") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 720)
    }
}
