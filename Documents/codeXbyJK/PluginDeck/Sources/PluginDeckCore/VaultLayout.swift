import Foundation

/// Vault(비활성화 보관 폴더) 경로 규칙.
///
/// - 내장 디스크 번들: `/Users/Shared/PluginDeck Vault` + 원래 절대 경로
///   예) /Library/Audio/Plug-Ins/VST/Foo.vst
///    -> /Users/Shared/PluginDeck Vault/Library/Audio/Plug-Ins/VST/Foo.vst
/// - 외장 드라이브 번들: `/Volumes/<드라이브>/PluginDeck Vault` + 드라이브 안 상대 경로
///   예) /Volumes/SSD/Audio/VST3/Bar.vst3
///    -> /Volumes/SSD/PluginDeck Vault/Audio/VST3/Bar.vst3
///
/// 항상 같은 드라이브 안에서만 옮기므로 `mv`가 이름 변경으로 끝난다 (복사 없음).
/// 원래 경로를 Vault 안에 그대로 담으므로 별도 기록 없이 복구 위치를 계산할 수 있다.
/// 심볼릭 링크 번들은 링크 자체(DAW가 보는 위치)를 옮긴다.
public struct VaultLayout: Hashable, Sendable {
    public static let folderName = "PluginDeck Vault"

    public var internalVault: String
    public var volumesRoot: String

    public init(internalVault: String = "/Users/Shared/" + VaultLayout.folderName, volumesRoot: String = "/Volumes") {
        self.internalVault = internalVault
        self.volumesRoot = volumesRoot
    }

    /// 경로가 외장 드라이브 위면 그 드라이브의 마운트 경로 (`/Volumes/SSD`), 아니면 nil
    public func mountPoint(of path: String) -> String? {
        let prefix = volumesRoot + "/"
        guard path.hasPrefix(prefix) else { return nil }
        let rest = path.dropFirst(prefix.count)
        guard let name = rest.split(separator: "/", omittingEmptySubsequences: true).first else { return nil }
        return prefix + name
    }

    public func vaultRoot(forOriginal path: String) -> String {
        if let mount = mountPoint(of: path) { return mount + "/" + Self.folderName }
        return internalVault
    }

    public func vaultPath(forOriginal path: String) -> String {
        if let mount = mountPoint(of: path) {
            return mount + "/" + Self.folderName + String(path.dropFirst(mount.count))
        }
        return internalVault + path
    }

    /// Vault 안 번들 경로 -> 원래 경로
    public func originalPath(forVaultItem item: String, vaultRoot: String) -> String? {
        guard item.hasPrefix(vaultRoot + "/") else { return nil }
        let rel = String(item.dropFirst(vaultRoot.count)) // "/..." 로 시작
        if vaultRoot == internalVault { return rel }
        // 외장 Vault: <mount>/PluginDeck Vault -> <mount>
        let mount = (vaultRoot as NSString).deletingLastPathComponent
        return mount + rel
    }

    /// 실제로 존재하는 Vault 폴더 (내장 + 연결된 외장 드라이브)
    public func existingVaultRoots() -> [String] {
        let fm = FileManager.default
        var roots: [String] = []
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: internalVault, isDirectory: &isDir), isDir.boolValue { roots.append(internalVault) }
        let bootReal = ("/" as NSString).resolvingSymlinksInPath
        for name in ((try? fm.contentsOfDirectory(atPath: volumesRoot)) ?? []).sorted() where !name.hasPrefix(".") {
            let mount = volumesRoot + "/" + name
            if (mount as NSString).resolvingSymlinksInPath == bootReal { continue }
            let v = mount + "/" + Self.folderName
            if fm.fileExists(atPath: v, isDirectory: &isDir), isDir.boolValue { roots.append(v) }
        }
        return roots
    }

    /// Vault가 DAW 스캔 폴더 안에 들어가 있는지 (그러면 비활성화해도 DAW에 계속 보일 수 있음)
    public func conflicts(withScanFolders folders: [String], forOriginals originals: [String]) -> [String] {
        let roots = Set(originals.map { vaultRoot(forOriginal: $0) })
        return roots.filter { r in folders.contains { f in r == f || r.hasPrefix(f + "/") } }.sorted()
    }
}
