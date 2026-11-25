import AppKit
import PluginDeckCore
import PluginDeckSkin
import SwiftUI
import UniformTypeIdentifiers

/// 예전 맥 스냅샷(JSON)과 지금 맥 비교 -> 다시 설치할 목록
struct CompareView: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var diff: SnapshotDiff?
    @State private var error: String?

    var body: some View {
        let canExport = diff.map { !$0.missingProducts.isEmpty || !$0.missingFormats.isEmpty } ?? false
        RetroSheet(
            "Compare with old Mac",
            subtitle: ["예전 맥에서 내보낸 JSON 스냅샷(파일 > 스냅샷 내보내기)을 열면, 지금 맥에 없는 플러그인을 찾습니다."],
            width: 760,
            minBodyHeight: 380,
            leadingFooter: [
                RetroAction(diff == nil ? "Open snapshot" : "Open another", highlight: diff == nil) { open() },
                RetroAction("Export list", enabled: canExport) { if let diff { export(diff) } },
            ],
            footer: [RetroAction("Close", shortcut: .cancelAction) { dismiss() }]
        ) {
            if let error { RetroText(error, tone: .warn) }
            if let diff {
                let date = diff.oldDate.formatted(date: .abbreviated, time: .omitted)
                RetroText("\(diff.oldMachine) (\(date)) -> \(model.machineName)", bold: true)

                RetroSectionHeader("Missing - reinstall", count: diff.missingProducts.count)
                if diff.missingProducts.isEmpty { RetroText("없음", tone: .dim) }
                ForEach(diff.missingProducts) { p in
                    RetroRow(p.displayName, detail: p.vendor, trailing: p.formats.map(\.displayName).joined(separator: " "), tone: .accent)
                }

                RetroSectionHeader("Formats missing", count: diff.missingFormats.count)
                if diff.missingFormats.isEmpty { RetroText("없음", tone: .dim) }
                ForEach(diff.missingFormats) { m in
                    RetroRow(m.displayName, detail: m.vendor,
                             trailing: m.missing.map(\.displayName).joined(separator: " ") + " 없음", tone: .accent)
                }

                RetroSectionHeader("Version changed", count: diff.versionChanges.count)
                if diff.versionChanges.isEmpty { RetroText("없음", tone: .dim) }
                ForEach(diff.versionChanges) { v in
                    RetroRow(tag: v.format.displayName, v.displayName,
                             trailing: "\(v.oldVersion) -> \(v.newVersion)" + (v.direction == .older ? " (예전이 더 최신)" : ""),
                             tone: v.direction == .older ? .accent : .normal)
                }

                RetroSectionHeader("Only on this Mac", count: diff.newProducts.count)
                ForEach(diff.newProducts) { p in RetroRow(p.displayName, trailing: p.vendor ?? "?", tone: .dim) }

                if !diff.ignoredDisabled.isEmpty {
                    RetroSectionHeader("Disabled on old Mac - skipped", count: diff.ignoredDisabled.count)
                    ForEach(diff.ignoredDisabled) { p in RetroRow(p.displayName, trailing: p.vendor ?? "?", tone: .dim) }
                }
            } else if error == nil {
                RetroText("스냅샷을 열어 주세요 (OPEN SNAPSHOT).", tone: .dim)
            }
        }
    }

    private func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let snap = try PluginSnapshot.decode(Data(contentsOf: url))
            diff = SnapshotComparer.compare(old: snap, current: model.bundles)
            error = nil
        } catch {
            self.error = "스냅샷을 읽지 못했습니다: \(error.localizedDescription)"
        }
    }

    private func export(_ diff: SnapshotDiff) {
        let text = SnapshotComparer.reinstallMarkdown(diff, currentMachine: model.machineName)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "plugins-to-reinstall.md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try Data(text.utf8).write(to: url) } catch { self.error = error.localizedDescription }
    }
}
