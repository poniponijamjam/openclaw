import Foundation

/// 번들 내부(Info.plist, 실행 파일)를 읽어서 메타데이터를 채운다.
public struct BundleMetadata: Equatable, Sendable {
    public var name: String
    public var bundleID: String?
    public var version: String?
    public var vendor: String?
    public var architectures: [CPUArch]
}

public enum BundleInspector {
    public static func inspect(bundleAt path: String) -> BundleMetadata {
        let fallbackName = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let plistPath = path + "/Contents/Info.plist"

        var plist: [String: Any] = [:]
        if let data = FileManager.default.contents(atPath: plistPath),
           let obj = try? PropertyListSerialization.propertyList(from: data, format: nil),
           let dict = obj as? [String: Any] {
            plist = dict
        }

        let bundleID = plist["CFBundleIdentifier"] as? String
        let version = (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String)
        let name = (plist["CFBundleName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName

        var architectures: [CPUArch] = []
        if let exe = plist["CFBundleExecutable"] as? String {
            architectures = MachOArch.architectures(ofFileAt: path + "/Contents/MacOS/" + exe)
        }

        return BundleMetadata(
            name: name,
            bundleID: bundleID,
            version: version,
            vendor: vendor(audioComponents: plist["AudioComponents"], bundleID: bundleID),
            architectures: architectures
        )
    }

    /// 벤더 추정 순서:
    /// 1. AU Info.plist의 AudioComponents[0].name ("Vendor: Plugin" 형식이 Apple 관례)
    /// 2. 번들 ID 두 번째 토큰 (com.fabfilter.Pro-Q.3 -> fabfilter)
    static func vendor(audioComponents: Any?, bundleID: String?) -> String? {
        if let comps = audioComponents as? [[String: Any]],
           let first = comps.first,
           let name = first["name"] as? String,
           let colon = name.firstIndex(of: ":") {
            let v = name[..<colon].trimmingCharacters(in: .whitespaces)
            if !v.isEmpty { return v }
        }
        if let bundleID {
            let parts = bundleID.split(separator: ".")
            if parts.count >= 2 { return String(parts[1]) }
        }
        return nil
    }

    /// 번들 디렉터리 전체 용량 (할당 크기 기준, Finder "디스크 사용량"과 유사)
    public static func directorySize(at path: String) -> Int64? {
        let url = URL(fileURLWithPath: path)
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        guard let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys) else { return nil }
        var total: Int64 = 0
        for case let file as URL in e {
            guard let v = try? file.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
            total += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
        }
        return total
    }
}
