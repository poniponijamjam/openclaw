import AppKit
import PluginDeckCore
import PluginDeckSkin
import SwiftUI

/// 레트로 스킨 메인 화면. 데이터/동작은 기존 LibraryModel 그대로, 그리는 방식만 다름.
struct RetroLibraryView: View {
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        RetroMainLayout(
            player: RetroPlayerPanel(state: playerState, actions: mainActions, secondary: secondaryActions),
            playlistTitle: "Playlist - \(model.grouping.rawValue) / \(model.filter.rawValue)",
            rows: rows,
            selection: model.selection,
            onSelect: { model.selection = $0 },
            footer: footerActions,
            search: $model.searchText
        ) {
            if let p = model.selectedProduct {
                RetroInfoPanel(title: p.displayName, sections: sections(for: p), actions: [
                    RetroAction("Clean up...", highlight: true) {
                        model.leftoverProduct = p
                        model.sheet = .leftovers
                    },
                ])
            } else {
                RetroInfoPanel(title: "NO SELECTION", sections: summarySections)
            }
        }
    }

    // MARK: - 플레이어 패널

    private var playerState: PlayerPanelState {
        let products = ProductGrouper.group(model.bundles)
        let selected = model.selectedProduct
        let marquee: String
        if let p = selected {
            let where_ = p.bundles.first.map { $0.volume?.name ?? "?" } ?? "?"
            marquee = "\(p.displayName) - \(p.vendor ?? "UNKNOWN") - \(p.formats.map(\.displayName).joined(separator: "/")) - \(where_)"
        } else {
            marquee = "*** PLUGINDECK *** \(model.bundles.count) BUNDLES ON \(Set(model.bundles.compactMap { $0.volume?.name }).count) DRIVES ***"
        }
        let size = ByteCountFormatter.string(fromByteCount: model.totalSize, countStyle: .file)
        let status: String
        if model.isScanning {
            status = "SCANNING..."
        } else if let d = model.lastScan {
            status = "LAST SCAN " + d.formatted(date: .omitted, time: .shortened)
        } else {
            status = "READY"
        }
        let count = { (f: PluginFormat) in model.bundles.filter { $0.format == f && $0.status != .disabled }.count }
        return PlayerPanelState(
            marquee: marquee,
            products: products.count,
            bundles: model.bundles.count,
            totalSize: size,
            status: status,
            badges: [
                Badge("INTEL", model.bundles.filter(\.isIntelOnly).count),
                Badge("OFFLINE", model.bundles.filter { $0.status == .offline }.count),
                Badge("OFF", model.bundles.filter { $0.status == .disabled }.count),
            ],
            bars: PluginFormat.allCases.map { FormatBars.Bar($0.displayName, count($0)) }
        )
    }

    private var mainActions: [RetroAction] {
        [
            RetroAction(model.isScanning ? "Scan.." : "Scan", enabled: !model.isScanning) { model.rescan() },
            RetroAction("Drives") { model.sheet = .discovery },
            RetroAction("Dupes", highlight: !model.cleanupPlan.redundantVST2.isEmpty) { model.sheet = .cleanup },
            RetroAction("Compare") { model.sheet = .compare },
        ]
    }

    private var secondaryActions: [RetroAction] {
        [
            RetroAction("History") { model.sheet = .history },
            RetroAction("Export") { model.exportMarkdown() },
        ]
    }

    private var footerActions: [RetroAction] {
        [
            RetroAction("Group: \(model.grouping.rawValue)") { model.grouping = next(model.grouping) },
            RetroAction("Filter: \(model.filter.rawValue)", highlight: model.filter != .all) { model.filter = next(model.filter) },
        ]
    }

    private func next<T: CaseIterable & Equatable>(_ v: T) -> T {
        let all = Array(T.allCases)
        let i = all.firstIndex(of: v) ?? 0
        return all[(i + 1) % all.count]
    }

    // MARK: - 플레이리스트

    private var rows: [PlaylistRow] {
        var result: [PlaylistRow] = []
        var index = 0
        let sections = model.sections
        for section in sections {
            if sections.count > 1 {
                result.append(PlaylistRow(id: "header|" + section.title, kind: .header, title: section.title))
            }
            for p in section.products {
                index += 1
                let warn = p.bundles.contains { $0.isIntelOnly || $0.status == .offline }
                let allDisabled = p.bundles.allSatisfy { $0.status == .disabled }
                result.append(PlaylistRow(
                    id: p.id,
                    index: index,
                    title: p.displayName,
                    subtitle: p.vendor ?? "",
                    formats: p.formats.map(\.displayName).joined(separator: " "),
                    trailing: ByteCountFormatter.string(fromByteCount: p.totalSize, countStyle: .file),
                    warn: warn,
                    dimmed: allDisabled
                ))
            }
        }
        return result
    }

    // MARK: - 정보 패널

    private func sections(for p: Product) -> [InfoSection] {
        p.bundles.map { b in
            var lines = [
                InfoLine("Path", b.path),
                InfoLine("Drive", driveText(b), warn: b.status == .offline),
                InfoLine("Version", b.version ?? "-"),
                InfoLine("Arch", b.architectures.isEmpty ? "?" : b.architectures.map(\.rawValue).joined(separator: " "),
                         warn: b.isIntelOnly),
                InfoLine("DAW", hostsText(b)),
            ]
            if b.isSymlink { lines.insert(InfoLine("Real", b.resolvedPath), at: 1) }
            if b.status == .disabled { lines.append(InfoLine("Restore", b.originalPath ?? "?", warn: true)) }
            if let s = b.sizeBytes { lines.append(InfoLine("Size", ByteCountFormatter.string(fromByteCount: s, countStyle: .file))) }

            var actions = [RetroAction("Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: b.status == .offline ? b.path : b.resolvedPath)])
            }]
            if b.status == .active { actions.append(RetroAction("Disable") { model.makeDisableScripts([b]) }) }
            if b.status == .disabled { actions.append(RetroAction("Restore", highlight: true) { model.makeRestoreScript([b]) }) }

            let state = b.status == .active ? "" : " (\(b.status.rawValue.uppercased()))"
            return InfoSection(title: b.format.displayName + state, lines: lines, actions: actions)
        }
    }

    private var summarySections: [InfoSection] {
        var lines = [
            InfoLine("Bundles", "\(model.bundles.count)"),
            InfoLine("Size", ByteCountFormatter.string(fromByteCount: model.totalSize, countStyle: .file)),
        ]
        for name in Set(model.bundles.compactMap { $0.volume?.name }).sorted() {
            lines.append(InfoLine("Drive", "\(name): \(model.bundles.filter { $0.volume?.name == name }.count)"))
        }
        var sections = [InfoSection(title: "Library", lines: lines)]
        if !model.missingLocations.isEmpty {
            sections.append(InfoSection(title: "Not found (ok)", lines: model.missingLocations.map { InfoLine("-", $0) }))
        }
        return sections
    }

    private func driveText(_ b: PluginBundle) -> String {
        guard let v = b.volume else { return "?" }
        var s = v.name
        if let isInternal = v.isInternal { s += isInternal ? " (INT)" : " (EXT)" }
        if !v.isOnline { s += " - OFFLINE" }
        return s
    }

    private func hostsText(_ b: PluginBundle) -> String {
        let hosts = model.visibleHosts(b)
        if hosts.isEmpty { return "NONE" }
        return hosts.map(\.displayName).joined(separator: ", ") + (b.isIntelOnly ? " (ROSETTA)" : "")
    }
}
