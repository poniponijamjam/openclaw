import Foundation
import XCTest
@testable import PluginDeckCore

struct FakeReceipts: ReceiptSource {
    var owners: [String: [String]]      // 경로 -> 패키지 ID
    var files: [String: [String]]       // 패키지 ID -> 설치 경로
    func packageIDs(forPath path: String) -> [String] { owners[path] ?? [] }
    func installedPaths(packageID: String) -> [String] { files[packageID] ?? [] }
}

final class M5Tests: XCTestCase {
    var root: String!
    var home: String!

    override func setUpWithError() throws {
        root = NSTemporaryDirectory() + "PluginDeckM5-" + UUID().uuidString
        home = root + "/Users/me"
        try FileManager.default.createDirectory(atPath: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
    }

    func mk(_ path: String, file: Bool = false) throws {
        if file {
            try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            try Data("12345".utf8).write(to: URL(fileURLWithPath: path))
        } else {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }

    func bundle(_ name: String, _ f: PluginFormat, path: String, vendor: String, bundleID: String) -> PluginBundle {
        PluginBundle(path: path, resolvedPath: path, isSymlink: false, format: f, scope: .system, status: .active,
                     volume: nil, name: name, bundleID: bundleID, version: "1", vendor: vendor,
                     architectures: [.arm64], sizeBytes: nil, modifiedAt: nil)
    }

    // MARK: - pkgutil 출력 파싱

    func testParsePkgutilOutput() {
        let fileInfo = """
        volume: /
        path: /Library/Audio/Plug-Ins/VST3/Synth.vst3

        pkgid: com.acme.synth.vst3
        pkg-version: 1.2
        install-time: 1700000000

        pkgid: com.acme.synth.common
        pkg-version: 1.2
        """
        XCTAssertEqual(PkgutilReceiptSource.parsePackageIDs(fileInfo: fileInfo), ["com.acme.synth.vst3", "com.acme.synth.common"])

        XCTAssertEqual(PkgutilReceiptSource.installBase(pkgInfo: "package-id: x\nvolume: /\nlocation: \ninstall-time: 1"), "/")
        XCTAssertEqual(PkgutilReceiptSource.installBase(pkgInfo: "volume: /\nlocation: Library/Audio/Plug-Ins/VST3"),
                       "/Library/Audio/Plug-Ins/VST3")
        XCTAssertEqual(PkgutilReceiptSource.join("/", "Library/X"), "/Library/X")
    }

    func testLeaves() {
        XCTAssertEqual(LeftoverFinder.leaves(["/a", "/a/b", "/a/b/c.txt", "/a b", "/a/d"]), ["/a b", "/a/b/c.txt", "/a/d"])
    }

    // MARK: - 영수증 기반

    func testReceiptLeftoversSkipStructuralFoldersAndOwnBundles() throws {
        let synth = root + "/Library/Audio/Plug-Ins/VST3/Synth.vst3"
        let other = root + "/Library/Audio/Plug-Ins/VST3/Other.vst3"
        let data = root + "/Library/Application Support/Acme/Synth/data.bin"
        try mk(synth + "/Contents")
        try mk(data, file: true)
        let receipts = FakeReceipts(
            owners: [synth: ["com.acme.synth"]],
            files: ["com.acme.synth": [
                root + "/Library", root + "/Library/Application Support",
                root + "/Library/Application Support/Acme", root + "/Library/Application Support/Acme/Synth", data,
                root + "/Library/Audio", root + "/Library/Audio/Plug-Ins", root + "/Library/Audio/Plug-Ins/VST3",
                synth, synth + "/Contents", synth + "/Contents/Info.plist",
                other, other + "/Contents/Info.plist",
            ]]
        )
        let product = ProductGrouper.group([bundle("Synth", .vst3, path: synth, vendor: "Acme", bundleID: "com.acme.synth")])[0]
        let finder = LeftoverFinder(home: home, root: root, receipts: receipts)
        let report = finder.find(for: product, among: [product])

        XCTAssertEqual(report.packageIDs, ["com.acme.synth"])
        XCTAssertEqual(report.otherPluginsInPackages, [other])
        let receiptItems = report.leftovers.filter { $0.kind == .receiptFile }
        XCTAssertEqual(receiptItems.map(\.path), [root + "/Library/Application Support/Acme"])
        XCTAssertEqual(receiptItems.first?.confidence, .high)
        XCTAssertEqual(receiptItems.first?.sizeBytes.map { $0 > 0 }, true)
        // /Library, Plug-Ins 폴더 같은 공용 폴더는 절대 후보가 아님
        XCTAssertFalse(report.leftovers.contains { $0.path == root + "/Library" || $0.path.hasSuffix("/Plug-Ins/VST3") })
    }

    func testReceiptLeftoverInSharedVendorFolderNarrowsToSubfolder() throws {
        let synth = root + "/Library/Audio/Plug-Ins/VST3/Synth.vst3"
        let data = root + "/Library/Application Support/Acme/Synth/data.bin"
        try mk(synth + "/Contents")
        try mk(data, file: true)
        let receipts = FakeReceipts(owners: [synth: ["p"]], files: ["p": [data, synth]])
        let all = ProductGrouper.group([
            bundle("Synth", .vst3, path: synth, vendor: "Acme", bundleID: "com.acme.synth"),
            bundle("Drum", .vst3, path: root + "/x/Drum.vst3", vendor: "Acme", bundleID: "com.acme.drum"),
        ])
        let product = all.first { $0.displayName == "Synth" }!
        let report = LeftoverFinder(home: home, root: root, receipts: receipts).find(for: product, among: all)
        let item = try XCTUnwrap(report.leftovers.first { $0.kind == .receiptFile })
        XCTAssertEqual(item.path, root + "/Library/Application Support/Acme/Synth")
        XCTAssertEqual(item.confidence, .medium)
        XCTAssertEqual(item.sharedWith, ["Drum"])
    }

    // MARK: - 이름 / 번들 ID 기반

    func testVendorFoldersPreferencesAndCaches() throws {
        try mk(home + "/Library/Application Support/Acme Audio")
        try mk(root + "/Library/Audio/Presets/Acme")
        try mk(root + "/Library/Application Support/Unrelated")
        try mk(home + "/Library/Preferences/com.acme.synth.plist", file: true)
        try mk(home + "/Library/Preferences/com.other.thing.plist", file: true)
        try mk(home + "/Library/Caches/com.acme.synth")

        let product = ProductGrouper.group([bundle("Synth", .au, path: root + "/x/Synth.component",
                                                   vendor: "Acme", bundleID: "com.acme.synth")])[0]
        let report = LeftoverFinder(home: home, root: root, receipts: nil).find(for: product, among: [product])
        let byPath = Dictionary(uniqueKeysWithValues: report.leftovers.map { ($0.path, $0) })

        XCTAssertEqual(byPath[home + "/Library/Preferences/com.acme.synth.plist"]?.confidence, .high)
        XCTAssertEqual(byPath[home + "/Library/Caches/com.acme.synth"]?.confidence, .high)
        XCTAssertEqual(byPath[home + "/Library/Application Support/Acme Audio"]?.confidence, .medium)
        XCTAssertEqual(byPath[root + "/Library/Audio/Presets/Acme"]?.kind, .presets)
        XCTAssertNil(byPath[root + "/Library/Application Support/Unrelated"])
        XCTAssertNil(byPath[home + "/Library/Preferences/com.other.thing.plist"])
        // 확신 높은 순 정렬
        XCTAssertEqual(report.leftovers.first?.confidence, .high)
    }

    func testVendorFolderSharedWithOtherProductIsLow() throws {
        try mk(root + "/Library/Application Support/Acme")
        let all = ProductGrouper.group([
            bundle("Synth", .vst3, path: "/x/Synth.vst3", vendor: "Acme", bundleID: "com.acme.synth"),
            bundle("Drum", .vst3, path: "/x/Drum.vst3", vendor: "Acme", bundleID: "com.acme.drum"),
        ])
        let synth = all.first { $0.displayName == "Synth" }!
        let report = LeftoverFinder(home: home, root: root, receipts: nil).find(for: synth, among: all)
        let item = try XCTUnwrap(report.leftovers.first)
        XCTAssertEqual(item.confidence, .low)
        XCTAssertEqual(item.sharedWith, ["Drum"])
    }

    // MARK: - 스크립트

    func testLeftoverPathsUseVaultLayout() {
        let layout = VaultLayout()
        let moves = ScriptWriter.disableMoves(
            for: [bundle("Synth", .vst3, path: "/Library/Audio/Plug-Ins/VST3/Synth.vst3", vendor: "Acme", bundleID: "x")],
            extraPaths: ["/Library/Application Support/Acme", "/Volumes/SSD/Acme Data"], layout: layout)
        XCTAssertEqual(moves.map(\.to), [
            "/Users/Shared/PluginDeck Vault/Library/Audio/Plug-Ins/VST3/Synth.vst3",
            "/Users/Shared/PluginDeck Vault/Library/Application Support/Acme",
            "/Volumes/SSD/PluginDeck Vault/Acme Data",
        ])
    }
}
