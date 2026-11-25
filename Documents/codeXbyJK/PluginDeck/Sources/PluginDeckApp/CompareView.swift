import AppKit
import PluginDeckCore
import SwiftUI
import UniformTypeIdentifiers

/// 예전 맥 스냅샷(JSON)과 지금 맥 비교 -> 다시 설치할 목록
struct CompareView: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var diff: SnapshotDiff?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("예전 맥과 비교").font(.title2.bold())
            Text("예전 맥에서 내보낸 JSON 스냅샷(파일 > 스냅샷 내보내기)을 열면, 지금 맥에 없는 플러그인을 찾습니다.")
                .foregroundStyle(.secondary)

            if let error { Text(error).foregroundStyle(.red) }

            if let diff {
                let df = diff.oldDate.formatted(date: .abbreviated, time: .omitted)
                Text("\(diff.oldMachine) (\(df)) -> \(model.machineName)").font(.headline)
                List {
                    SwiftUI.Section("빠진 제품 - 다시 설치 필요 (\(diff.missingProducts.count))") {
                        if diff.missingProducts.isEmpty { Text("없음").foregroundStyle(.secondary) }
                        ForEach(diff.missingProducts) { p in
                            row(p.displayName, p.vendor, p.formats.map(\.displayName).joined(separator: ", "))
                        }
                    }
                    SwiftUI.Section("포맷 일부 빠짐 (\(diff.missingFormats.count))") {
                        if diff.missingFormats.isEmpty { Text("없음").foregroundStyle(.secondary) }
                        ForEach(diff.missingFormats) { m in
                            row(m.displayName, m.vendor, m.missing.map(\.displayName).joined(separator: ", ") + " 없음")
                        }
                    }
                    SwiftUI.Section("버전 다름 (\(diff.versionChanges.count))") {
                        if diff.versionChanges.isEmpty { Text("없음").foregroundStyle(.secondary) }
                        ForEach(diff.versionChanges) { v in
                            let arrow = v.direction == .older ? " (예전이 더 최신)" : ""
                            row(v.displayName, v.format.displayName, "\(v.oldVersion) -> \(v.newVersion)\(arrow)")
                        }
                    }
                    SwiftUI.Section("지금 맥에만 있음 (\(diff.newProducts.count))") {
                        ForEach(diff.newProducts) { p in row(p.displayName, p.vendor, "") }
                    }
                    if !diff.ignoredDisabled.isEmpty {
                        SwiftUI.Section("예전 맥에서도 비활성화돼 있던 제품 - 제외 (\(diff.ignoredDisabled.count))") {
                            ForEach(diff.ignoredDisabled) { p in row(p.displayName, p.vendor, "") }
                        }
                    }
                }
                .frame(minHeight: 360)
            }

            HStack {
                Button(diff == nil ? "스냅샷 열기..." : "다른 스냅샷 열기...") { open() }
                if let diff {
                    Button("다시 설치할 목록 내보내기 (Markdown)...") { export(diff) }
                        .disabled(diff.missingProducts.isEmpty && diff.missingFormats.isEmpty)
                }
                Spacer()
                Button("닫기") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 760)
    }

    private func row(_ name: String, _ sub: String?, _ detail: String) -> some View {
        HStack {
            Text(name)
            Text(sub ?? "알 수 없음").foregroundStyle(.secondary)
            Spacer()
            Text(detail).font(.caption.monospaced()).foregroundStyle(.secondary)
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
