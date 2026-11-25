import AppKit
import PluginDeckCore
import SwiftUI

/// Ableton Live 12 환경설정 > Plug-Ins 탭과 같은 값을 입력받는다.
struct SettingsView: View {
    @EnvironmentObject var model: LibraryModel
    @AppStorage("PluginDeck.RetroSkin") private var retro = true

    var body: some View {
        Form {
            SwiftUI.Section("화면") {
                Toggle("레트로 스킨 사용", isOn: $retro)
            }
            SwiftUI.Section("Ableton Live 12 (환경설정 > Plug-Ins 와 똑같이 맞춰주세요)") {
                Toggle("Audio Units 사용", isOn: $model.settings.abletonUseAudioUnits)
                Toggle("VST2 시스템 폴더 사용", isOn: $model.settings.abletonUseVST2SystemFolders)
                Toggle("VST3 시스템 폴더 사용", isOn: $model.settings.abletonUseVST3SystemFolders)
                folderRow("VST2 커스텀 폴더", path: $model.settings.abletonVST2CustomFolder)
                folderRow("VST3 커스텀 폴더", path: $model.settings.abletonVST3CustomFolder)
            }
            SwiftUI.Section("추가 스캔 폴더 (외장 드라이브 등)") {
                ForEach(model.extraFolders, id: \.self) { f in
                    HStack {
                        Text(f).font(.caption.monospaced())
                        Spacer()
                        Button("삭제") { model.extraFolders.removeAll { $0 == f } }
                    }
                }
                Button("폴더 추가...") {
                    if let p = pickFolder() { model.extraFolders.append(p) }
                }
            }
            Text("Logic Pro는 표준 Components 폴더의 AU만 읽으므로 따로 설정할 항목이 없습니다.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .onDisappear { model.rescan() }
    }

    private func folderRow(_ title: String, path: Binding<String?>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(path.wrappedValue ?? "없음").font(.caption.monospaced()).foregroundStyle(.secondary)
            Button("선택...") { if let p = pickFolder() { path.wrappedValue = p } }
            if path.wrappedValue != nil { Button("해제") { path.wrappedValue = nil } }
        }
    }

    private func pickFolder() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
