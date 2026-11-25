import AppKit
import PluginDeckCore
import PluginDeckSkin
import SwiftUI
import XCTest

/// 레트로 스킨을 가짜 데이터로 이미지 렌더링한다.
/// PLUGINDECK_SNAPSHOT_DIR 환경 변수가 있으면 PNG로 저장 (CI에서 결과물로 올려 확인).
final class SkinSnapshotTests: XCTestCase {
    static let sampleRows: [PlaylistRow] = {
        var rows: [PlaylistRow] = [PlaylistRow(id: "h1", kind: .header, title: "Ableton (2)")]
        rows.append(PlaylistRow(id: "op", index: 1, title: "Operator Bundle", subtitle: "Ableton", formats: "VST3", trailing: "48 MB"))
        rows.append(PlaylistRow(id: "wv", index: 2, title: "Wavetable Pack", subtitle: "Ableton", formats: "AU VST3", trailing: "112 MB"))
        rows.append(PlaylistRow(id: "h2", kind: .header, title: "FabFilter (3)"))
        rows.append(PlaylistRow(id: "proq3", index: 3, title: "Pro-Q 3", subtitle: "FabFilter", formats: "AU VST2 VST3", trailing: "61 MB"))
        rows.append(PlaylistRow(id: "prol2", index: 4, title: "Pro-L 2", subtitle: "FabFilter", formats: "AU VST3", trailing: "39 MB"))
        rows.append(PlaylistRow(id: "proc2", index: 5, title: "Pro-C 2", subtitle: "FabFilter", formats: "VST2", trailing: "28 MB", dimmed: true))
        rows.append(PlaylistRow(id: "h3", kind: .header, title: "Old Vendor (2)"))
        rows.append(PlaylistRow(id: "old1", index: 6, title: "Vintage Synth 1999", subtitle: "Old Vendor", formats: "VST2", trailing: "9 MB", warn: true))
        rows.append(PlaylistRow(id: "old2", index: 7, title: "Tape Echo (External SSD)", subtitle: "Old Vendor", formats: "VST3", trailing: "-", warn: true))
        return rows
    }()

    @MainActor
    func render<V: View>(_ view: V, name: String, size: CGSize) throws -> Data {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage, "ImageRenderer returned nil")
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        if let dir = ProcessInfo.processInfo.environment["PLUGINDECK_SNAPSHOT_DIR"] {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try png.write(to: URL(fileURLWithPath: dir + "/" + name + ".png"))
        }
        return png
    }

    @MainActor
    func player(marquee: String) -> RetroPlayerPanel {
        RetroPlayerPanel(
            state: PlayerPanelState(
                marquee: marquee, products: 7, bundles: 15, totalSize: "297 MB", status: "LAST SCAN 14:32",
                badges: [Badge("INTEL", 1), Badge("OFFLINE", 1), Badge("OFF", 1)],
                bars: [FormatBars.Bar("AU", 5), FormatBars.Bar("VST2", 3), FormatBars.Bar("VST3", 6),
                       FormatBars.Bar("CLAP", 0), FormatBars.Bar("AAX", 1)]
            ),
            actions: [RetroAction("Scan") {}, RetroAction("Drives") {}, RetroAction("Dupes", highlight: true) {},
                      RetroAction("Compare") {}],
            secondary: [RetroAction("History") {}, RetroAction("Export") {}],
            animated: false
        )
    }

    @MainActor
    func testRenderMainWindowWithSelection() throws {
        let view = RetroMainLayout(
            player: player(marquee: "Pro-Q 3 - FabFilter - AU/VST2/VST3 - Macintosh HD"),
            playlistTitle: "Playlist - 벤더 / 전체",
            rows: Self.sampleRows, selection: "proq3", onSelect: { _ in },
            footer: [RetroAction("Group: 벤더") {}, RetroAction("Filter: 전체") {}],
            search: nil, scrollable: false
        ) {
            RetroInfoPanel(title: "Pro-Q 3", sections: [
                InfoSection(title: "AU", lines: [
                    InfoLine("Path", "/Library/Audio/Plug-Ins/Components/FabFilter Pro-Q 3.component"),
                    InfoLine("Drive", "Macintosh HD (INT)"),
                    InfoLine("Version", "3.21"),
                    InfoLine("Arch", "arm64 x86_64"),
                    InfoLine("DAW", "Logic Pro"),
                ], actions: [RetroAction("Finder") {}, RetroAction("Disable") {}]),
                InfoSection(title: "VST2", lines: [
                    InfoLine("Path", "/Library/Audio/Plug-Ins/VST/FabFilter Pro-Q 3.vst"),
                    InfoLine("DAW", "Ableton Live 12"),
                ], actions: [RetroAction("Finder") {}, RetroAction("Disable") {}]),
            ], actions: [RetroAction("Clean up...", highlight: true) {}])
        }
        let png = try render(view, name: "main-selected", size: CGSize(width: 1040, height: 640))
        XCTAssertGreaterThan(png.count, 20_000)
    }

    @MainActor
    func testRenderPlayerPanelAlone() throws {
        let png = try render(player(marquee: "*** PLUGINDECK *** 15 BUNDLES ON 2 DRIVES ***"),
                             name: "player", size: CGSize(width: 900, height: 140))
        XCTAssertGreaterThan(png.count, 5_000)
    }

    @MainActor
    func sampleSheet() -> some View {
        RetroSheet(
            "Duplicate cleanup",
            subtitle: ["규칙: Logic은 AU, Ableton은 VST3. VST3가 있는 제품의 VST2만 비활성화 후보로 봅니다.",
                       "스크립트만 만듭니다. 파일은 터미널에서 직접 실행해야 옮겨집니다."],
            minBodyHeight: 300,
            leadingFooter: [RetroAction("All") {}, RetroAction("None") {}],
            footer: [RetroAction("Make script (2)", highlight: true) {}, RetroAction("Close") {}],
            scrollable: false
        ) {
            RetroSectionHeader("VST2 to disable - VST3 exists", count: 3)
            RetroCheckRow(isOn: .constant(true)) {
                VStack(alignment: .leading, spacing: 1) {
                    RetroText("Pro-Q 3")
                    RetroText("/Library/Audio/Plug-Ins/VST/FabFilter Pro-Q 3.vst", tone: .dim, size: 9)
                }
            }
            RetroCheckRow(isOn: .constant(true)) {
                VStack(alignment: .leading, spacing: 1) {
                    RetroText("Pro-L 2")
                    RetroText("/Library/Audio/Plug-Ins/VST/FabFilter Pro-L 2.vst", tone: .dim, size: 9)
                }
            }
            RetroCheckRow(isOn: .constant(false)) {
                VStack(alignment: .leading, spacing: 1) {
                    RetroText("Wavetable Pack")
                    RetroText("/Volumes/SSD/Ableton VST/Wavetable Pack.vst", tone: .dim, size: 9)
                }
            }
            RetroSectionHeader("Gone from Ableton if AU is off", count: 1)
            RetroRow("Vintage Synth 1999", trailing: "Old Vendor", tone: .accent)
            RetroSectionHeader("Run in Terminal")
            RetroCommandLine(label: "1. Disable", command: "bash '~/Library/Application Support/PluginDeck/Scripts/disable-20261125-150000.sh'",
                             copy: RetroAction("Copy") {})
            RetroRow(tag: "DISABLE", "비활성화 2개 (복구: restore-20261125-150000.sh)", detail: "20261125-150000  /  2개", tone: .accent,
                     actions: [RetroAction("Copy") {}, RetroAction("Show") {}])
        }
    }

    @MainActor
    func testRenderSheetClassic() throws {
        let png = try render(sampleSheet(), name: "sheet-classic", size: CGSize(width: 720, height: 520))
        XCTAssertGreaterThan(png.count, 10_000)
    }

    @MainActor
    func testRenderSheetPlainTheme() throws {
        let png = try render(sampleSheet().environment(\.retroTheme, .plain), name: "sheet-plain", size: CGSize(width: 720, height: 520))
        XCTAssertGreaterThan(png.count, 5_000)
    }
}
