import Foundation
import XCTest
@testable import PluginDeckCore

final class M2Tests: XCTestCase {
    var root: String!

    override func setUpWithError() throws {
        root = NSTemporaryDirectory() + "PluginDeckM2-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
    }

    func touchBundle(_ path: String) throws {
        try FileManager.default.createDirectory(atPath: path + "/Contents", withIntermediateDirectories: true)
    }

    func bundle(_ name: String, _ f: PluginFormat, status: PluginStatus = .active, vendor: String? = "V",
                volume: VolumeInfo? = nil, archs: [CPUArch] = [.arm64]) -> PluginBundle {
        PluginBundle(path: "/p/\(name).\(f.rawValue)", resolvedPath: "/p/\(name).\(f.rawValue)", isSymlink: false,
                     format: f, scope: .system, status: status, volume: volume, name: name, bundleID: nil,
                     version: "1.0", vendor: vendor, architectures: archs, sizeBytes: 10, modifiedAt: nil)
    }

    // MARK: - ExternalFolderFinder

    func testFinderFindsAndMergesNestedFolders() throws {
        let volumes = root + "/Volumes"
        // 드라이브 A: VST3 폴더 + 벤더 하위 폴더 (상위로 합쳐져야 함)
        try touchBundle(volumes + "/SSD-A/Audio/VST3/One.vst3")
        try touchBundle(volumes + "/SSD-A/Audio/VST3/Vendor/Two.vst3")
        try touchBundle(volumes + "/SSD-A/Audio/VST3/Vendor/Three.vst")
        // 드라이브 B: VST2 폴더
        try touchBundle(volumes + "/SSD-B/VST/Old.vst")
        // 건너뛰어야 하는 곳
        try touchBundle(volumes + "/SSD-B/PluginDeck Vault/vst/Hidden.vst")
        try touchBundle(volumes + "/SSD-B/Some.app/Contents/Inner.vst3")
        try touchBundle(volumes + "/SSD-B/.hidden/Secret.vst3")

        let result = ExternalFolderFinder().find(volumesRoot: volumes)
        XCTAssertFalse(result.truncated)
        XCTAssertEqual(result.candidates.map(\.path), [
            volumes + "/SSD-A/Audio/VST3",
            volumes + "/SSD-B/VST",
        ])
        let a = result.candidates[0]
        XCTAssertEqual(a.volumeName, "SSD-A")
        XCTAssertEqual(a.counts[.vst3], 2)
        XCTAssertEqual(a.counts[.vst2], 1)
        XCTAssertEqual(a.suggestedFormat, .vst3)
        XCTAssertEqual(result.candidates[1].suggestedFormat, .vst2)
    }

    func testFinderRespectsDepthAndBudget() throws {
        let volumes = root + "/Volumes"
        try touchBundle(volumes + "/D/1/2/3/4/5/6/Deep.vst3")
        XCTAssertTrue(ExternalFolderFinder(maxDepth: 3).find(volumesRoot: volumes).candidates.isEmpty)
        XCTAssertEqual(ExternalFolderFinder(maxDepth: 10).find(volumesRoot: volumes).candidates.count, 1)

        let limited = ExternalFolderFinder(maxDepth: 10, maxDirectories: 3).find(volumesRoot: volumes)
        XCTAssertTrue(limited.truncated)
    }

    func testFinderSkipsBootVolumeLink() throws {
        let volumes = root + "/Volumes"
        try FileManager.default.createDirectory(atPath: volumes, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: volumes + "/Macintosh HD", withDestinationPath: "/")
        let result = ExternalFolderFinder(maxDepth: 2, maxDirectories: 100).find(volumesRoot: volumes)
        XCTAssertEqual(result.visitedDirectories, 0)
    }

    // MARK: - CleanupRules

    func testCleanupPlan() {
        let products = ProductGrouper.group([
            bundle("Both", .au), bundle("Both", .vst2), bundle("Both", .vst3),   // VST2 중복
            bundle("AUOnly", .au),                                                  // AU 전용
            bundle("Legacy", .au), bundle("Legacy", .vst2),                         // VST2만 -> 유지
            bundle("GoneV3", .vst2), bundle("GoneV3", .vst3, status: .offline),     // VST3 오프라인 -> 중복 아님
        ])
        let plan = CleanupRules.plan(for: products)
        XCTAssertEqual(plan.redundantVST2.map(\.name), ["Both"])
        XCTAssertEqual(plan.auOnlyProducts.map(\.displayName), ["AUOnly"])
        XCTAssertEqual(plan.vst2OnlyProducts.map(\.displayName), ["GoneV3", "Legacy"])
    }

    // MARK: - Export

    func testSnapshotRoundTrip() throws {
        let snap = PluginSnapshot(createdAt: Date(timeIntervalSince1970: 1_700_000_000), machineName: "Test Mac",
                                  bundles: [bundle("A", .vst3)])
        let back = try PluginSnapshot.decode(snap.encoded())
        XCTAssertEqual(back.schemaVersion, 1)
        XCTAssertEqual(back.machineName, "Test Mac")
        XCTAssertEqual(back.bundles, snap.bundles)
        XCTAssertEqual(back.createdAt, snap.createdAt)
    }

    func testChecklistMarkdown() {
        let ext = VolumeInfo(name: "SSD", uuid: nil, isInternal: false, mountPoint: "/Volumes/SSD", isOnline: true)
        let products = ProductGrouper.group([
            bundle("Pro-Q 3", .au, vendor: "FabFilter"),
            bundle("Pro-Q 3", .vst3, vendor: "FabFilter"),
            bundle("OldSynth", .vst2, vendor: "Acme", volume: ext, archs: [.x86_64]),
        ])
        let md = ChecklistExporter.markdown(products: products, machineName: "Studio",
                                            date: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertTrue(md.hasPrefix("# 플러그인 체크리스트 - Studio"))
        XCTAssertTrue(md.contains("## Acme (1)"))
        XCTAssertTrue(md.contains("## FabFilter (1)"))
        XCTAssertTrue(md.contains("- [ ] Pro-Q 3 1.0 - AU, VST3"))
        XCTAssertTrue(md.contains("- [ ] OldSynth 1.0 - VST2 (Intel 전용, 외장: SSD)"))
        // 벤더 알파벳 순
        XCTAssertLessThan(md.range(of: "## Acme")!.lowerBound, md.range(of: "## FabFilter")!.lowerBound)
    }
}
