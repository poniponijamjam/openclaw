import AppKit
import PluginDeckCore
import SwiftUI

@main
struct PluginDeckApp: App {
    @StateObject private var model = LibraryModel()

    init() {
        // `swift run`으로 실행할 때도 Dock 아이콘과 창이 앞으로 오도록
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("PluginDeck") {
            LibraryView()
                .environmentObject(model)
                .frame(minWidth: 900, minHeight: 560)
                .onAppear {
                    model.rescan()
                    model.openDiscoveryOnFirstLaunch()
                }
                .sheet(item: $model.sheet) { sheet in
                    switch sheet {
                    case .discovery: DiscoveryView().environmentObject(model)
                    case .cleanup: CleanupView().environmentObject(model)
                    case .history: HistoryView().environmentObject(model)
                    case .scriptResult: ScriptResultView().environmentObject(model)
                    }
                }
        }
        .commands {
            CommandGroup(after: .saveItem) {
                Button("체크리스트 내보내기 (Markdown)...") { model.exportMarkdown() }
                    .keyboardShortcut("e", modifiers: [.command])
                Button("스냅샷 내보내기 (JSON)...") { model.exportJSON() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
        Settings {
            SettingsView().environmentObject(model)
        }
    }
}

// MARK: - 메인 화면 (디자인은 M6에서 레트로 스킨으로 교체)

struct LibraryView: View {
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selection) {
                ForEach(model.sections) { section in
                    SwiftUI.Section(section.title) {
                        ForEach(section.products) { p in
                            ProductRow(product: p).tag(p.id)
                        }
                    }
                }
            }
            .searchable(text: $model.searchText, prompt: "이름 / 벤더 검색")
            .navigationSplitViewColumnWidth(min: 320, ideal: 380)
        } detail: {
            if let p = model.selectedProduct {
                ProductDetailView(product: p)
            } else {
                SummaryView()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Picker("묶기", selection: $model.grouping) {
                    ForEach(Grouping.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("필터", selection: $model.filter) {
                    ForEach(QuickFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                Button {
                    model.sheet = .discovery
                } label: {
                    Label("외장 드라이브에서 찾기", systemImage: "externaldrive.badge.plus")
                }
                Button {
                    model.sheet = .cleanup
                } label: {
                    Label("중복 정리", systemImage: "square.stack.3d.down.right")
                }
                Button {
                    model.sheet = .history
                } label: {
                    Label("스크립트 이력", systemImage: "clock.arrow.circlepath")
                }
                Button {
                    model.rescan()
                } label: {
                    if model.isScanning { ProgressView().controlSize(.small) } else { Label("다시 스캔", systemImage: "arrow.clockwise") }
                }
            }
        }
    }
}

struct ProductRow: View {
    @EnvironmentObject var model: LibraryModel
    let product: Product

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName).fontWeight(.medium)
                Text(product.vendor ?? "알 수 없음").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            ForEach(product.formats, id: \.self) { f in
                Text(f.displayName)
                    .font(.caption2.monospaced())
                    .padding(.horizontal, 4)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
            }
            if product.bundles.contains(where: \.isIntelOnly) {
                Image(systemName: "cpu").foregroundStyle(.orange).help("Intel 전용 번들 있음")
            }
            if product.bundles.contains(where: { $0.status == .disabled }) {
                Image(systemName: "archivebox").foregroundStyle(.secondary).help("비활성화된 번들 있음 (Vault)")
            }
            if product.bundles.contains(where: { $0.status == .offline }) {
                Image(systemName: "externaldrive.badge.xmark").foregroundStyle(.red).help("드라이브 연결 안 됨")
            }
        }
    }
}

struct ProductDetailView: View {
    @EnvironmentObject var model: LibraryModel
    let product: Product

    var body: some View {
        Form {
            SwiftUI.Section {
                LabeledContent("벤더", value: product.vendor ?? "알 수 없음")
                LabeledContent("포맷", value: product.formats.map(\.displayName).joined(separator: ", "))
                LabeledContent("총 용량", value: ByteCountFormatter.string(fromByteCount: product.totalSize, countStyle: .file))
            } header: {
                Text(product.displayName).font(.title2.bold())
            }

            ForEach(product.bundles) { b in
                SwiftUI.Section(b.format.displayName) {
                    LabeledContent("위치", value: b.path).textSelection(.enabled)
                    if b.status == .disabled {
                        LabeledContent("상태", value: "비활성화됨 (Vault)")
                        LabeledContent("원래 위치", value: b.originalPath ?? "알 수 없음").textSelection(.enabled)
                    }
                    if b.isSymlink {
                        LabeledContent("실제 위치", value: b.resolvedPath).textSelection(.enabled)
                    }
                    LabeledContent("드라이브", value: driveText(b))
                    LabeledContent("버전", value: b.version ?? "-")
                    LabeledContent("번들 ID", value: b.bundleID ?? "-")
                    LabeledContent("아키텍처", value: b.architectures.isEmpty ? "확인 못 함" : b.architectures.map(\.rawValue).joined(separator: ", "))
                    LabeledContent("보이는 DAW", value: hostsText(b))
                    if let size = b.sizeBytes {
                        LabeledContent("용량", value: ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    }
                    HStack {
                        Button("Finder에서 보기") {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: b.status == .offline ? b.path : b.resolvedPath)])
                        }
                        if b.status == .active {
                            Button("비활성화 스크립트 만들기") { model.makeDisableScripts([b]) }
                        }
                        if b.status == .disabled {
                            Button("복구 스크립트 만들기") { model.makeRestoreScript([b]) }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func driveText(_ b: PluginBundle) -> String {
        guard let v = b.volume else { return "알 수 없음" }
        var s = v.name
        if let isInternal = v.isInternal { s += isInternal ? " (내장)" : " (외장)" }
        if !v.isOnline { s += " - 연결 안 됨" }
        return s
    }

    private func hostsText(_ b: PluginBundle) -> String {
        let hosts = model.visibleHosts(b)
        if hosts.isEmpty { return "없음" }
        var s = hosts.map(\.displayName).joined(separator: ", ")
        if b.isIntelOnly { s += " (Rosetta로 실행 시)" }
        return s
    }
}

struct SummaryView: View {
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PluginDeck").font(.largeTitle.bold())
            Text("번들 \(model.bundles.count)개 / 제품 \(ProductGrouper.group(model.bundles).count)개")
            Text("총 용량 \(ByteCountFormatter.string(fromByteCount: model.totalSize, countStyle: .file))")
            Text("Intel 전용 \(model.bundles.filter(\.isIntelOnly).count)개, 오프라인 \(model.bundles.filter { $0.status == .offline }.count)개")
            if let d = model.lastScan {
                Text("마지막 스캔: \(d.formatted(date: .abbreviated, time: .standard))").foregroundStyle(.secondary)
            }
            if !model.missingLocations.isEmpty {
                Text("없는 경로 (정상일 수 있음):").padding(.top, 8).foregroundStyle(.secondary)
                ForEach(model.missingLocations, id: \.self) { Text($0).font(.caption.monospaced()).foregroundStyle(.secondary) }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
