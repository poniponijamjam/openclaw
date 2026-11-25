import Foundation
import XCTest
@testable import PluginDeckCore

/// Vault 경로 규칙 + 생성된 스크립트를 실제 bash로 실행해 이동/복구를 검증한다 (임시 폴더 안에서만).
final class M3Tests: XCTestCase {
    var root: String!
    var layout: VaultLayout!

    override func setUpWithError() throws {
        root = NSTemporaryDirectory() + "PluginDeckM3-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        layout = VaultLayout(internalVault: root + "/Shared/PluginDeck Vault", volumesRoot: root + "/Volumes")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
    }

    func makeBundle(_ path: String) throws {
        try FileManager.default.createDirectory(atPath: path + "/Contents", withIntermediateDirectories: true)
        try Data("x".utf8).write(to: URL(fileURLWithPath: path + "/Contents/marker"))
    }

    func exists(_ p: String) -> Bool { FileManager.default.fileExists(atPath: p) }

    @discardableResult
    func runBash(_ script: String) throws -> (status: Int32, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [script]
        var env = ProcessInfo.processInfo.environment
        env["PLUGINDECK_FORCE"] = "1"
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (p.terminationStatus, out)
    }

    func bundle(_ path: String, _ f: PluginFormat, status: PluginStatus = .active, original: String? = nil) -> PluginBundle {
        PluginBundle(path: path, resolvedPath: path, isSymlink: false, format: f, scope: .system, status: status,
                     volume: nil, name: (path as NSString).lastPathComponent, bundleID: nil, version: nil, vendor: nil,
                     architectures: [], sizeBytes: nil, modifiedAt: nil, originalPath: original)
    }

    // MARK: - VaultLayout

    func testVaultPathsInternalAndExternal() {
        let real = VaultLayout()
        XCTAssertEqual(real.vaultPath(forOriginal: "/Library/Audio/Plug-Ins/VST/Foo.vst"),
                       "/Users/Shared/PluginDeck Vault/Library/Audio/Plug-Ins/VST/Foo.vst")
        XCTAssertEqual(real.vaultPath(forOriginal: "/Volumes/SSD/Audio/VST3/Bar.vst3"),
                       "/Volumes/SSD/PluginDeck Vault/Audio/VST3/Bar.vst3")
        XCTAssertEqual(real.mountPoint(of: "/Volumes/My SSD/x"), "/Volumes/My SSD")
        XCTAssertNil(real.mountPoint(of: "/Library/x"))

        XCTAssertEqual(real.originalPath(forVaultItem: "/Users/Shared/PluginDeck Vault/Library/Audio/Plug-Ins/VST/Foo.vst",
                                         vaultRoot: "/Users/Shared/PluginDeck Vault"),
                       "/Library/Audio/Plug-Ins/VST/Foo.vst")
        XCTAssertEqual(real.originalPath(forVaultItem: "/Volumes/SSD/PluginDeck Vault/Audio/VST3/Bar.vst3",
                                         vaultRoot: "/Volumes/SSD/PluginDeck Vault"),
                       "/Volumes/SSD/Audio/VST3/Bar.vst3")
    }

    func testVaultConflictWithScanFolder() {
        let real = VaultLayout()
        // Ableton 커스텀 폴더를 드라이브 최상위로 지정하면 Vault가 그 안에 들어감
        XCTAssertEqual(real.conflicts(withScanFolders: ["/Volumes/SSD"], forOriginals: ["/Volumes/SSD/VST/A.vst"]),
                       ["/Volumes/SSD/PluginDeck Vault"])
        XCTAssertEqual(real.conflicts(withScanFolders: ["/Volumes/SSD/VST"], forOriginals: ["/Volumes/SSD/VST/A.vst"]), [])
    }

    // MARK: - 스크립트 실행 (이동 -> 스캔 -> 복구)

    func testDisableThenRestoreRoundTrip() throws {
        let internalVST = root + "/Library/Audio/Plug-Ins/VST"
        let extVST = root + "/Volumes/SSD/Ableton VST"
        let a = internalVST + "/Vendor/Old's Comp.vst"   // 작은따옴표 + 공백 경로
        let b = extVST + "/Synth.vst"
        try makeBundle(a)
        try makeBundle(b)

        let moves = ScriptWriter.disableMoves(for: [bundle(a, .vst2), bundle(b, .vst2),
                                                    bundle(root + "/gone.vst", .vst2, status: .offline)], layout: layout)
        XCTAssertEqual(moves.count, 2) // 오프라인 제외

        let scripts = root + "/Scripts"
        let pair = try ScriptWriter.writeDisablePair(moves: moves, to: scripts)
        XCTAssertNotNil(pair.disablePath)

        // 1) 비활성화
        let r1 = try runBash(pair.disablePath!)
        XCTAssertEqual(r1.status, 0, r1.output)
        XCTAssertFalse(exists(a))
        XCTAssertFalse(exists(b))
        let aVault = layout.internalVault + a
        let bVault = root + "/Volumes/SSD/PluginDeck Vault/Ableton VST/Synth.vst"
        XCTAssertTrue(exists(aVault + "/Contents/marker"))
        XCTAssertTrue(exists(bVault + "/Contents/marker"))

        // 2) Vault 스캔 -> disabled + 원래 위치
        let locations = layout.existingVaultRoots().map { ScanLocation(path: $0, scope: .vault, format: nil, maxDepth: 30) }
        XCTAssertEqual(locations.count, 2)
        let scanned = PluginScanner(computeSizes: false, vaultLayout: layout).scan(locations).bundles
        XCTAssertEqual(Set(scanned.map(\.status)), [.disabled])
        XCTAssertEqual(Set(scanned.compactMap(\.originalPath)), [a, b])

        // 3) 같은 스크립트를 다시 실행하면 원본이 없으므로 건너뜀 (실패 아님)
        let again = try runBash(pair.disablePath!)
        XCTAssertEqual(again.status, 0, again.output)
        XCTAssertTrue(again.output.contains("건너뜀 2"), again.output)

        // 4) 복구
        let r2 = try runBash(pair.restorePath)
        XCTAssertEqual(r2.status, 0, r2.output)
        XCTAssertTrue(exists(a + "/Contents/marker"))
        XCTAssertTrue(exists(b + "/Contents/marker"))
        XCTAssertFalse(exists(aVault))

        // 5) 스캔 결과로 만든 복구 스크립트도 같은 이동을 만든다
        XCTAssertEqual(Set(ScriptWriter.restoreMoves(for: scanned)), Set(moves.map(\.reversed)))

        // 6) 이력
        let records = ScriptStore.list(directory: scripts)
        XCTAssertEqual(records.map(\.kind).sorted(), ["disable", "restore"])
        XCTAssertEqual(records.first?.items, 2)
    }

    func testScriptRefusesToOverwrite() throws {
        let src = root + "/VST/A.vst"
        try makeBundle(src)
        try makeBundle(layout.vaultPath(forOriginal: src)) // Vault에 같은 이름이 이미 있음
        let pair = try ScriptWriter.writeDisablePair(moves: ScriptWriter.disableMoves(for: [bundle(src, .vst2)], layout: layout),
                                                     to: root + "/Scripts")
        let r = try runBash(pair.disablePath!)
        XCTAssertEqual(r.status, 0, r.output)
        XCTAssertTrue(exists(src + "/Contents/marker")) // 원본 그대로
        XCTAssertTrue(r.output.contains("이미 있음"), r.output)
    }

    func testDisabledBundlesAreNotVisibleOrCleanupCandidates() {
        let disabled = bundle("/v/A.vst", .vst2, status: .disabled, original: "/Library/Audio/Plug-Ins/VST/A.vst")
        XCTAssertFalse(disabled.isVisible(in: .ableton12, settings: HostSettings()))
        let plan = CleanupRules.plan(for: ProductGrouper.group([disabled, bundle("/x/A.vst3", .vst3)]))
        XCTAssertTrue(plan.redundantVST2.isEmpty)
    }
}
