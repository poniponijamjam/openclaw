import AppKit
import PluginDeckCore
import SwiftUI

extension LibraryModel {
    var scriptDirectory: String { ScriptStore.defaultDirectory }

    func makeDisableScripts(_ bundles: [PluginBundle]) {
        let moves = ScriptWriter.disableMoves(for: bundles, layout: VaultLayout())
        guard !moves.isEmpty else {
            scriptError = "옮길 수 있는 번들이 없습니다 (오프라인이거나 이미 비활성화됨)."
            sheet = .scriptResult
            return
        }
        do {
            lastScripts = try ScriptWriter.writeDisablePair(moves: moves, to: scriptDirectory)
            scriptError = nil
        } catch {
            scriptError = error.localizedDescription
        }
        sheet = .scriptResult
    }

    func makeRestoreScript(_ bundles: [PluginBundle]) {
        let moves = ScriptWriter.restoreMoves(for: bundles)
        guard !moves.isEmpty else {
            scriptError = "복구할 수 있는 번들이 없습니다."
            sheet = .scriptResult
            return
        }
        do {
            lastScripts = try ScriptWriter.writeRestore(moves: moves, to: scriptDirectory)
            scriptError = nil
        } catch {
            scriptError = error.localizedDescription
        }
        sheet = .scriptResult
    }

    static func terminalCommand(for path: String) -> String {
        "bash '" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// 스크립트를 만든 직후 보여주는 화면
struct ScriptResultView: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = model.scriptError {
                Text("스크립트를 만들지 못했습니다").font(.title2.bold())
                Text(error).foregroundStyle(.red)
            } else if let pair = model.lastScripts {
                Text(pair.disablePath == nil ? "복구 스크립트를 만들었습니다" : "비활성화 스크립트를 만들었습니다")
                    .font(.title2.bold())
                Text("번들 \(pair.moves.count)개. 아직 아무 파일도 옮기지 않았습니다. 아래 명령을 터미널에 붙여넣어 실행하세요.")
                    .foregroundStyle(.secondary)
                Text("시스템 폴더(/Library) 항목이 있으면 관리자 비밀번호를 한 번 물어봅니다. Logic / Ableton이 켜져 있으면 스크립트가 멈춥니다.")
                    .font(.caption).foregroundStyle(.secondary)

                if let d = pair.disablePath { commandRow("1. 비활성화", path: d) }
                commandRow(pair.disablePath == nil ? "복구" : "2. 되돌릴 때 (복구)", path: pair.restorePath)

                List(pair.moves, id: \.self) { m in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(m.from).font(.caption.monospaced())
                        Text("-> " + m.to).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 180)
            }
            HStack {
                Button("Finder에서 스크립트 폴더 열기") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: model.scriptDirectory))
                }
                Spacer()
                Button("닫기 후 다시 스캔") {
                    dismiss()
                    model.rescan()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 720)
    }

    private func commandRow(_ label: String, path: String) -> some View {
        let cmd = LibraryModel.terminalCommand(for: path)
        return HStack {
            Text(label).frame(width: 130, alignment: .leading)
            Text(cmd).font(.caption.monospaced()).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
            Spacer()
            Button("명령 복사") { LibraryModel.copyToPasteboard(cmd) }
        }
    }
}

/// 지금까지 만든 스크립트 목록
struct HistoryView: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var records: [ScriptRecord] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("스크립트 이력").font(.title2.bold())
            Text(model.scriptDirectory).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)

            if records.isEmpty {
                Text("아직 만든 스크립트가 없습니다.").foregroundStyle(.secondary)
            } else {
                List(records) { r in
                    HStack {
                        Text(r.kind == "disable" ? "비활성화" : "복구")
                            .font(.caption.bold())
                            .frame(width: 56, alignment: .leading)
                            .foregroundStyle(r.kind == "disable" ? Color.orange : Color.green)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.title)
                            Text(r.stamp + "  /  \(r.items)개").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("명령 복사") { LibraryModel.copyToPasteboard(LibraryModel.terminalCommand(for: r.path)) }
                        Button("보기") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: r.path)]) }
                    }
                }
                .frame(minHeight: 280)
            }
            Text("스크립트를 실행했는지는 기록하지 않습니다. 실제 상태는 목록의 '비활성화됨' 필터로 확인하세요.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("닫기") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 720)
        .onAppear { records = ScriptStore.list(directory: model.scriptDirectory) }
    }
}
