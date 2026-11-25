import AppKit
import PluginDeckCore
import PluginDeckSkin
import SwiftUI

enum AppSheet: String, Identifiable {
    case discovery
    case cleanup
    case history
    case scriptResult
    case compare
    case leftovers
    var id: String { rawValue }
}

extension LibraryModel {
    private static let discoveryDoneKey = "PluginDeck.DiscoveryDone"

    func openDiscoveryOnFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: Self.discoveryDoneKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.discoveryDoneKey)
        sheet = .discovery
    }

    func isRegistered(_ path: String) -> Bool {
        settings.customFolders.contains(path) || extraFolders.contains(path)
    }

    func register(_ c: FolderCandidate, as role: FolderRole) {
        switch role {
        case .abletonVST2: settings.abletonVST2CustomFolder = c.path
        case .abletonVST3: settings.abletonVST3CustomFolder = c.path
        case .extra: if !extraFolders.contains(c.path) { extraFolders.append(c.path) }
        }
    }
}

enum FolderRole {
    case abletonVST2, abletonVST3, extra
}

/// 외장 드라이브 훑기. 처음 실행할 때 한 번 자동으로 열리고, 이후엔 버튼으로.
struct DiscoveryView: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var result: FolderSearchResult?
    @State private var searching = false
    @State private var elapsed: TimeInterval = 0

    var body: some View {
        RetroSheet(
            "Find plugin folders",
            subtitle: [
                "연결된 드라이브를 5단계 깊이까지 훑어서 .vst / .vst3 / .component 가 있는 폴더를 찾습니다. 파일은 읽기만 합니다.",
                "Ableton 환경설정 > Plug-Ins 의 커스텀 폴더와 같은 폴더를 골라 VST3 / VST2 로 등록하세요. 추천 칸은 주황색입니다.",
            ],
            leadingFooter: [RetroAction(result == nil ? "Search" : "Search again", enabled: !searching) { search() }],
            footer: [RetroAction("Close", highlight: true, shortcut: .cancelAction) {
                dismiss()
                model.rescan()
            }]
        ) {
            if searching {
                RetroBusy("SEARCHING DRIVES")
            } else if let result {
                RetroText("폴더 \(result.visitedDirectories)개 확인, \(String(format: "%.1f", elapsed))초"
                          + (result.truncated ? " - 한도에 걸려 중간에 멈춤 (일부만 확인)" : ""),
                          tone: result.truncated ? .accent : .dim, size: 10)
                if result.candidates.isEmpty {
                    RetroText("플러그인 폴더를 찾지 못했습니다. 외장 드라이브가 연결되어 있는지 확인하세요.")
                        .padding(.top, 8)
                } else {
                    RetroSectionHeader("Candidates", count: result.candidates.count)
                    ForEach(result.candidates) { c in row(c) }
                }
            }
        }
        .onAppear { if result == nil { search() } }
    }

    private func row(_ c: FolderCandidate) -> some View {
        let registered = model.isRegistered(c.path)
        return RetroRow(
            tag: c.volumeName,
            c.path,
            detail: countsText(c),
            trailing: registered ? "REGISTERED" : nil,
            tone: registered ? .dim : .normal,
            actions: registered ? [] : [
                RetroAction("VST3", highlight: c.suggestedFormat == .vst3) { model.register(c, as: .abletonVST3) },
                RetroAction("VST2", highlight: c.suggestedFormat == .vst2) { model.register(c, as: .abletonVST2) },
                RetroAction("Extra") { model.register(c, as: .extra) },
            ]
        )
    }

    private func countsText(_ c: FolderCandidate) -> String {
        PluginFormat.allCases.compactMap { f in
            guard let n = c.counts[f], n > 0 else { return nil }
            return "\(f.displayName) \(n)"
        }.joined(separator: ", ")
    }

    private func search() {
        searching = true
        let start = Date()
        Task {
            let r = await Task.detached(priority: .userInitiated) { ExternalFolderFinder().find() }.value
            result = r
            elapsed = Date().timeIntervalSince(start)
            searching = false
        }
    }
}
