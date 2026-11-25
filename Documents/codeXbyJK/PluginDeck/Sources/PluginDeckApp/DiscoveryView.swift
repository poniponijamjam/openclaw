import AppKit
import PluginDeckCore
import SwiftUI

enum AppSheet: String, Identifiable {
    case discovery
    case cleanup
    case history
    case scriptResult
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

/// 외장 드라이브 훑기. 처음 실행할 때 한 번 자동으로 열리고, 이후엔 툴바 버튼으로.
struct DiscoveryView: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var result: FolderSearchResult?
    @State private var searching = false
    @State private var elapsed: TimeInterval = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("외장 드라이브에서 플러그인 폴더 찾기").font(.title2.bold())
            Text("연결된 드라이브를 5단계 깊이까지 훑어서 .vst / .vst3 / .component 가 있는 폴더를 찾습니다. 파일은 읽기만 합니다.")
                .foregroundStyle(.secondary)
            Text("Ableton 환경설정 > Plug-Ins 의 커스텀 폴더와 같은 폴더를 골라 등록하세요.")
                .foregroundStyle(.secondary)

            if searching {
                HStack { ProgressView().controlSize(.small); Text("찾는 중...") }
            } else if let result {
                Text("폴더 \(result.visitedDirectories)개 확인, \(String(format: "%.1f", elapsed))초"
                     + (result.truncated ? " - 한도에 걸려 중간에 멈춤 (일부만 확인)" : ""))
                    .font(.caption).foregroundStyle(result.truncated ? Color.orange : Color.secondary)
                if result.candidates.isEmpty {
                    Text("플러그인 폴더를 찾지 못했습니다. 외장 드라이브가 연결되어 있는지 확인하세요.")
                } else {
                    List(result.candidates) { c in candidateRow(c) }
                        .frame(minHeight: 220)
                }
            }

            HStack {
                Button(result == nil ? "찾기" : "다시 찾기") { search() }.disabled(searching)
                Spacer()
                Button("닫기") {
                    dismiss()
                    model.rescan()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 680)
        .onAppear { if result == nil { search() } }
    }

    private func candidateRow(_ c: FolderCandidate) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(c.path).font(.callout.monospaced()).textSelection(.enabled)
                Text(countsText(c) + "  /  드라이브: \(c.volumeName)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if model.isRegistered(c.path) {
                Label("등록됨", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Menu("등록") {
                    Button("Ableton VST3 커스텀 폴더로") { model.register(c, as: .abletonVST3) }
                    Button("Ableton VST2 커스텀 폴더로") { model.register(c, as: .abletonVST2) }
                    Button("추가 스캔 폴더로 (DAW 판정 없음)") { model.register(c, as: .extra) }
                }
                .fixedSize()
            }
        }
        .padding(.vertical, 2)
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
