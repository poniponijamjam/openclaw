import Foundation
import XCTest
@testable import PluginDeckCore

final class M4Tests: XCTestCase {
    func b(_ name: String, _ f: PluginFormat, _ version: String? = "1.0", status: PluginStatus = .active,
           vendor: String = "V") -> PluginBundle {
        PluginBundle(path: "/p/\(name).\(f.rawValue)", resolvedPath: "/p/\(name).\(f.rawValue)", isSymlink: false,
                     format: f, scope: .system, status: status, volume: nil, name: name, bundleID: nil,
                     version: version, vendor: vendor, architectures: [.arm64], sizeBytes: nil, modifiedAt: nil)
    }

    func snapshot(_ bundles: [PluginBundle]) -> PluginSnapshot {
        PluginSnapshot(createdAt: Date(timeIntervalSince1970: 1_700_000_000), machineName: "Old Mac", bundles: bundles)
    }

    func testCompare() {
        let old = snapshot([
            b("Pro-Q 3", .au, "3.20"), b("Pro-Q 3", .vst3, "3.20"),   // 있음, 버전 다름
            b("Gone Synth", .vst3, vendor: "Acme"),                   // 빠짐
            b("Comp", .au), b("Comp", .vst3),                          // AU 빠짐
            b("Shelved", .vst2, status: .disabled),                   // 예전에도 비활성화 -> 제외
            b("Kept Off", .vst2),                                      // 지금은 비활성화 상태로 있음 -> 빠짐 아님
        ])
        let current = [
            b("Pro-Q 3", .au, "3.9"), b("Pro-Q 3", .vst3, "3.21"),
            b("Comp", .vst3),
            b("Kept Off", .vst2, status: .disabled),
            b("Brand New", .vst3),
        ]
        let d = SnapshotComparer.compare(old: old, current: current)

        XCTAssertEqual(d.oldMachine, "Old Mac")
        XCTAssertEqual(d.missingProducts.map(\.displayName), ["Gone Synth"])
        XCTAssertEqual(d.missingFormats.map(\.displayName), ["Comp"])
        XCTAssertEqual(d.missingFormats.first?.missing, [.au])
        XCTAssertEqual(d.newProducts.map(\.displayName), ["Brand New"])
        XCTAssertEqual(d.ignoredDisabled.map(\.displayName), ["Shelved"])

        // 숫자 단위 비교: 3.9 < 3.20, 3.21 > 3.20
        let byFormat = Dictionary(uniqueKeysWithValues: d.versionChanges.map { ($0.format, $0.direction) })
        XCTAssertEqual(byFormat[.au], .older)
        XCTAssertEqual(byFormat[.vst3], .newer)
    }

    func testCompareThroughJSONRoundTrip() throws {
        let old = try PluginSnapshot.decode(snapshot([b("A", .vst3), b("B", .au)]).encoded())
        let d = SnapshotComparer.compare(old: old, current: [b("A", .vst3)])
        XCTAssertEqual(d.missingProducts.map(\.displayName), ["B"])
    }

    func testReinstallMarkdown() {
        let old = snapshot([b("Gone Synth", .vst3, vendor: "Acme"), b("Comp", .au), b("Comp", .vst3)])
        let d = SnapshotComparer.compare(old: old, current: [b("Comp", .vst3)])
        let md = SnapshotComparer.reinstallMarkdown(d, currentMachine: "New Mac", date: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertTrue(md.hasPrefix("# 다시 설치할 플러그인 - Old Mac -> New Mac"))
        XCTAssertTrue(md.contains("### Acme"))
        XCTAssertTrue(md.contains("- [ ] Gone Synth 1.0 - VST3"))
        XCTAssertTrue(md.contains("- [ ] Comp (V) - AU 없음 (Logic에서 안 보임)"))

        let none = SnapshotComparer.reinstallMarkdown(SnapshotComparer.compare(old: snapshot([b("A", .vst3)]), current: [b("A", .vst3)]),
                                                      currentMachine: "New Mac")
        XCTAssertTrue(none.contains("빠진 플러그인이 없습니다."))
    }
}
