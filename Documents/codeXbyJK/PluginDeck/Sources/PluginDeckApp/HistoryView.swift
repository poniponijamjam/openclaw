import AppKit
import PluginDeckCore
import PluginDeckSkin
import SwiftUI

extension LibraryModel {
    var scriptDirectory: String { ScriptStore.defaultDirectory }

    func makeDisableScripts(_ bundles: [PluginBundle], extraPaths: [String] = []) {
        let moves = ScriptWriter.disableMoves(for: bundles, extraPaths: extraPaths, layout: VaultLayout())
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
        let pair = model.lastScripts
        let failed = model.scriptError != nil
        RetroSheet(
            failed ? "Script not created" : (pair?.disablePath == nil ? "Restore script ready" : "Disable script ready"),
            subtitle: failed ? [] : [
                "아직 아무 파일도 옮기지 않았습니다. 아래 명령을 복사해서 터미널에 붙여넣어 실행하세요.",
                "시스템 폴더(/Library) 항목이 있으면 관리자 비밀번호를 한 번 물어봅니다. Logic / Ableton이 켜져 있으면 스크립트가 멈춥니다.",
            ],
            leadingFooter: [RetroAction("Open folder") {
                NSWorkspace.shared.open(URL(fileURLWithPath: model.scriptDirectory))
            }],
            footer: [RetroAction("Close + rescan", highlight: true, shortcut: .defaultAction) {
                dismiss()
                model.rescan()
            }]
        ) {
            if let error = model.scriptError {
                RetroText(error, tone: .warn)
            } else if let pair {
                RetroSectionHeader("Run in Terminal")
                if let d = pair.disablePath { commandLine("1. Disable", path: d) }
                commandLine(pair.disablePath == nil ? "Restore" : "2. Undo", path: pair.restorePath)
                RetroSectionHeader("Moves", count: pair.moves.count)
                ForEach(pair.moves, id: \.self) { m in
                    RetroRow(m.from, detail: "-> " + m.to)
                }
            }
        }
    }

    private func commandLine(_ label: String, path: String) -> some View {
        let cmd = LibraryModel.terminalCommand(for: path)
        return RetroCommandLine(label: label, command: cmd, copy: RetroAction("Copy") { LibraryModel.copyToPasteboard(cmd) })
    }
}

/// 지금까지 만든 스크립트 목록
struct HistoryView: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var records: [ScriptRecord] = []

    var body: some View {
        RetroSheet(
            "Script history",
            subtitle: [
                model.scriptDirectory,
                "스크립트를 실행했는지는 기록하지 않습니다. 실제 상태는 목록의 '비활성화됨' 필터로 확인하세요.",
            ],
            footer: [RetroAction("Close", highlight: true, shortcut: .cancelAction) { dismiss() }]
        ) {
            if records.isEmpty {
                RetroText("아직 만든 스크립트가 없습니다.", tone: .dim)
            } else {
                ForEach(records) { r in
                    RetroRow(
                        tag: r.kind == "disable" ? "DISABLE" : "RESTORE",
                        r.title,
                        detail: r.stamp + "  /  \(r.items)개",
                        tone: r.kind == "disable" ? .accent : .normal,
                        actions: [
                            RetroAction("Copy") { LibraryModel.copyToPasteboard(LibraryModel.terminalCommand(for: r.path)) },
                            RetroAction("Show") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: r.path)]) },
                        ]
                    )
                }
            }
        }
        .onAppear { records = ScriptStore.list(directory: model.scriptDirectory) }
    }
}
