import Foundation

public struct ScanLocation: Hashable, Sendable {
    public var path: String
    public var scope: PluginScope
    /// nil이면 폴더 안의 모든 포맷을 확장자로 판별 (커스텀 폴더용)
    public var format: PluginFormat?

    public init(path: String, scope: PluginScope, format: PluginFormat?) {
        self.path = path
        self.scope = scope
        self.format = format
    }
}

public enum ScanLocations {
    /// 포맷별 표준 설치 경로 (시스템 + 사용자).
    /// - VST3: Steinberg VST3 문서 "Plug-in Locations"
    /// - CLAP: free-audio/clap `include/clap/entry.h`
    /// - AU / VST2: macOS 관례 경로
    /// - AAX: Avid Pro Tools 기본 경로 (사용자 경로 없음)
    public static func standard(home: String = NSHomeDirectory(), root: String = "") -> [ScanLocation] {
        var result: [ScanLocation] = []
        let folders: [(PluginFormat, String)] = [
            (.au, "Components"),
            (.vst2, "VST"),
            (.vst3, "VST3"),
            (.clap, "CLAP"),
        ]
        for (format, folder) in folders {
            result.append(ScanLocation(path: root + "/Library/Audio/Plug-Ins/\(folder)", scope: .system, format: format))
            result.append(ScanLocation(path: home + "/Library/Audio/Plug-Ins/\(folder)", scope: .user, format: format))
        }
        result.append(ScanLocation(path: root + "/Library/Application Support/Avid/Audio/Plug-Ins", scope: .system, format: .aax))
        return result
    }

    public static func all(settings: HostSettings, extraFolders: [String] = [],
                           home: String = NSHomeDirectory(), root: String = "") -> [ScanLocation] {
        var result = standard(home: home, root: root)
        let known = Set(result.map(\.path))
        for folder in settings.customFolders + extraFolders where !known.contains(folder) {
            result.append(ScanLocation(path: folder, scope: .custom, format: nil))
        }
        return result
    }
}
