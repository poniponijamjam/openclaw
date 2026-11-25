import Foundation
import XCTest
@testable import PluginDeckCore

/// 임시 폴더에 가짜 플러그인 번들을 만들어 스캐너를 검증한다. 실제 /Library는 건드리지 않음.
final class PluginDeckCoreTests: XCTestCase {
    var root: String!

    override func setUpWithError() throws {
        root = NSTemporaryDirectory() + "PluginDeckTests-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
    }

    // MARK: - 헬퍼

    /// thin arm64 / x86_64 또는 fat 바이너리 헤더
    func machHeader(_ archs: [CPUArch]) -> Data {
        func be(_ v: UInt32) -> [UInt8] { [UInt8(v >> 24), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
        func le(_ v: UInt32) -> [UInt8] { be(v).reversed() }
        func cpu(_ a: CPUArch) -> UInt32 { a == .arm64 ? 0x0100_000C : 0x0100_0007 }
        if archs.count == 1 {
            return Data(le(0xFEED_FACF) + le(cpu(archs[0])) + [UInt8](repeating: 0, count: 24))
        }
        var bytes = be(0xCAFE_BABE) + be(UInt32(archs.count))
        for a in archs { bytes += be(cpu(a)) + [UInt8](repeating: 0, count: 16) }
        return Data(bytes)
    }

    @discardableResult
    func makeBundle(_ dir: String, _ file: String, name: String, bundleID: String,
                    archs: [CPUArch] = [.arm64, .x86_64], auName: String? = nil) throws -> String {
        let path = dir + "/" + file
        try FileManager.default.createDirectory(atPath: path + "/Contents/MacOS", withIntermediateDirectories: true)
        var plist: [String: Any] = [
            "CFBundleName": name,
            "CFBundleIdentifier": bundleID,
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleExecutable": name,
        ]
        if let auName { plist["AudioComponents"] = [["name": auName, "manufacturer": "Test"]] }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: URL(fileURLWithPath: path + "/Contents/Info.plist"))
        try machHeader(archs).write(to: URL(fileURLWithPath: path + "/Contents/MacOS/" + name))
        return path
    }

    func mkdir(_ p: String) throws -> String {
        try FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true)
        return p
    }

    // MARK: - 테스트

    func testMachOArchitectures() {
        XCTAssertEqual(MachOArch.architectures(fromHeader: machHeader([.arm64])), [.arm64])
        XCTAssertEqual(MachOArch.architectures(fromHeader: machHeader([.x86_64])), [.x86_64])
        XCTAssertEqual(MachOArch.architectures(fromHeader: machHeader([.x86_64, .arm64])), [.arm64, .x86_64])
        XCTAssertEqual(MachOArch.architectures(fromHeader: Data([0, 1, 2, 3, 4, 5, 6, 7])), [])
    }

    func testInspectorReadsPlistAndVendor() throws {
        let dir = try mkdir(root + "/Components")
        let p = try makeBundle(dir, "ProQ.component", name: "Pro-Q 3", bundleID: "com.fabfilter.Pro-Q.AU.3",
                               archs: [.x86_64], auName: "FabFilter: Pro-Q 3")
        let meta = BundleInspector.inspect(bundleAt: p)
        XCTAssertEqual(meta.name, "Pro-Q 3")
        XCTAssertEqual(meta.version, "1.2.3")
        XCTAssertEqual(meta.vendor, "FabFilter")
        XCTAssertEqual(meta.architectures, [.x86_64])
    }

    func testScannerFindsNestedAndFiltersByFormat() throws {
        let vst3 = try mkdir(root + "/Library/Audio/Plug-Ins/VST3")
        let nested = try mkdir(vst3 + "/VendorFolder")
        try makeBundle(nested, "Comp.vst3", name: "Comp", bundleID: "com.vendor.comp")
        // VST3 폴더에 잘못 들어간 .vst 는 무시해야 함
        try makeBundle(vst3, "Wrong.vst", name: "Wrong", bundleID: "com.vendor.wrong")

        let result = PluginScanner(computeSizes: false).scan([ScanLocation(path: vst3, scope: .system, format: .vst3)])
        XCTAssertEqual(result.bundles.map(\.name), ["Comp"])
        XCTAssertEqual(result.bundles.first?.format, .vst3)
        XCTAssertEqual(result.bundles.first?.status, .active)
    }

    func testSymlinkToOtherDriveAndOfflineDrive() throws {
        let components = try mkdir(root + "/Components")
        let external = try mkdir(root + "/ExternalSSD/Plugins")
        let real = try makeBundle(external, "Synth.component", name: "Synth", bundleID: "com.vendor.synth")
        try FileManager.default.createSymbolicLink(atPath: components + "/Synth.component", withDestinationPath: real)
        // 존재하지 않는 외장 드라이브로 향하는 링크
        try FileManager.default.createSymbolicLink(atPath: components + "/Gone.component",
                                                   withDestinationPath: "/Volumes/NoSuchDrive-\(UUID().uuidString)/Gone.component")

        let result = PluginScanner(computeSizes: false).scan([ScanLocation(path: components, scope: .user, format: .au)])
        let synth = try XCTUnwrap(result.bundles.first { $0.name == "Synth" })
        XCTAssertTrue(synth.isSymlink)
        XCTAssertEqual(synth.resolvedPath, (real as NSString).resolvingSymlinksInPath)
        XCTAssertEqual(synth.status, .active)

        let gone = try XCTUnwrap(result.bundles.first { $0.name == "Gone" })
        XCTAssertEqual(gone.status, .offline)
        XCTAssertEqual(gone.volume?.isOnline, false)
        XCTAssertTrue(gone.volume?.mountPoint.hasPrefix("/Volumes/NoSuchDrive-") ?? false)
    }

    func testMissingLocationReported() {
        let result = PluginScanner().scan([ScanLocation(path: root + "/nope", scope: .system, format: .clap)])
        XCTAssertEqual(result.missingLocations, [root + "/nope"])
        XCTAssertTrue(result.bundles.isEmpty)
    }

    func testGrouperMergesFormats() throws {
        let au = try mkdir(root + "/Components")
        let v3 = try mkdir(root + "/VST3")
        try makeBundle(au, "ProQ3.component", name: "Pro-Q 3", bundleID: "com.fabfilter.Pro-Q.AU.3", auName: "FabFilter: Pro-Q 3")
        try makeBundle(v3, "ProQ3.vst3", name: "Pro-Q 3", bundleID: "com.fabfilter.Pro-Q.3")
        let result = PluginScanner(computeSizes: false).scan([
            ScanLocation(path: au, scope: .system, format: .au),
            ScanLocation(path: v3, scope: .system, format: .vst3),
        ])
        let products = ProductGrouper.group(result.bundles)
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products[0].formats, [.au, .vst3])
    }

    func testHostVisibility() {
        func bundle(_ f: PluginFormat, _ scope: PluginScope = .system, path: String = "/x") -> PluginBundle {
            PluginBundle(path: path, resolvedPath: path, isSymlink: false, format: f, scope: scope, status: .active,
                         volume: nil, name: "X", bundleID: nil, version: nil, vendor: nil,
                         architectures: [.arm64], sizeBytes: nil, modifiedAt: nil)
        }
        var s = HostSettings()
        XCTAssertTrue(bundle(.au).isVisible(in: .logic, settings: s))
        XCTAssertFalse(bundle(.vst3).isVisible(in: .logic, settings: s))
        XCTAssertTrue(bundle(.vst3).isVisible(in: .ableton12, settings: s))
        XCTAssertFalse(bundle(.clap).isVisible(in: .ableton12, settings: s))
        XCTAssertFalse(bundle(.aax).isVisible(in: .ableton12, settings: s))

        s.abletonUseVST2SystemFolders = false
        XCTAssertFalse(bundle(.vst2).isVisible(in: .ableton12, settings: s))

        s.abletonVST2CustomFolder = "/Volumes/SSD/VST"
        XCTAssertTrue(bundle(.vst2, .custom, path: "/Volumes/SSD/VST/A.vst").isVisible(in: .ableton12, settings: s))
        XCTAssertFalse(bundle(.vst2, .custom, path: "/Volumes/Other/A.vst").isVisible(in: .ableton12, settings: s))
    }
}
