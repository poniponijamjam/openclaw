import Foundation

/// 플러그인 포맷. rawValue는 번들 확장자.
public enum PluginFormat: String, CaseIterable, Codable, Sendable {
    case au = "component"
    case vst2 = "vst"
    case vst3 = "vst3"
    case clap = "clap"
    case aax = "aaxplugin"

    public var displayName: String {
        switch self {
        case .au: return "AU"
        case .vst2: return "VST2"
        case .vst3: return "VST3"
        case .clap: return "CLAP"
        case .aax: return "AAX"
        }
    }

    public init?(fileExtension: String) {
        self.init(rawValue: fileExtension.lowercased())
    }
}

/// 사용자가 쓰는 DAW. 포맷 지원 범위만 모델링한다.
public enum HostDAW: String, CaseIterable, Codable, Sendable {
    case logic
    case ableton12

    public var displayName: String {
        switch self {
        case .logic: return "Logic Pro"
        case .ableton12: return "Ableton Live 12"
        }
    }

    /// Logic Pro: Audio Unit만 지원.
    /// Ableton Live 12 (macOS): AU, VST2, VST3. CLAP / AAX 미지원.
    public var supportedFormats: Set<PluginFormat> {
        switch self {
        case .logic: return [.au]
        case .ableton12: return [.au, .vst2, .vst3]
        }
    }
}

public enum PluginScope: String, Codable, Sendable {
    case system   // /Library/...
    case user     // ~/Library/...
    case custom   // 사용자가 추가한 폴더 (예: Ableton VST 커스텀 폴더)
}

public enum PluginStatus: String, Codable, Sendable {
    case active
    /// 심볼릭 링크 대상이 없는 상태 (외장 드라이브 분리 등)
    case offline
}

public enum CPUArch: String, Codable, Sendable, Comparable {
    case arm64
    case x86_64
    case other

    public static func < (lhs: CPUArch, rhs: CPUArch) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct VolumeInfo: Hashable, Codable, Sendable {
    public var name: String
    public var uuid: String?
    public var isInternal: Bool?
    public var mountPoint: String
    public var isOnline: Bool

    public init(name: String, uuid: String?, isInternal: Bool?, mountPoint: String, isOnline: Bool) {
        self.name = name
        self.uuid = uuid
        self.isInternal = isInternal
        self.mountPoint = mountPoint
        self.isOnline = isOnline
    }

    public static func offline(mountPoint: String) -> VolumeInfo {
        let name = (mountPoint as NSString).lastPathComponent
        return VolumeInfo(name: name, uuid: nil, isInternal: false, mountPoint: mountPoint, isOnline: false)
    }
}

/// 디스크 위 플러그인 번들 1개.
public struct PluginBundle: Identifiable, Hashable, Codable, Sendable {
    /// 스캔 경로 기준 절대 경로 (DAW가 보는 위치)
    public var id: String { path }
    public var path: String
    /// 심볼릭 링크를 따라간 실제 경로
    public var resolvedPath: String
    public var isSymlink: Bool
    public var format: PluginFormat
    public var scope: PluginScope
    public var status: PluginStatus
    public var volume: VolumeInfo?

    public var name: String
    public var bundleID: String?
    public var version: String?
    public var vendor: String?
    public var architectures: [CPUArch]
    public var sizeBytes: Int64?
    public var modifiedAt: Date?

    public init(path: String, resolvedPath: String, isSymlink: Bool, format: PluginFormat, scope: PluginScope,
                status: PluginStatus, volume: VolumeInfo?, name: String, bundleID: String?, version: String?,
                vendor: String?, architectures: [CPUArch], sizeBytes: Int64?, modifiedAt: Date?) {
        self.path = path
        self.resolvedPath = resolvedPath
        self.isSymlink = isSymlink
        self.format = format
        self.scope = scope
        self.status = status
        self.volume = volume
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.vendor = vendor
        self.architectures = architectures
        self.sizeBytes = sizeBytes
        self.modifiedAt = modifiedAt
    }

    /// arm64 바이너리가 없으면 Apple Silicon 맥에서 DAW를 Rosetta로 실행해야 로드됨.
    /// 아키텍처를 읽지 못한 경우(빈 배열)는 false로 둔다.
    public var isIntelOnly: Bool {
        !architectures.isEmpty && !architectures.contains(.arm64)
    }

    public func isVisible(in host: HostDAW, settings: HostSettings) -> Bool {
        guard status == .active, host.supportedFormats.contains(format) else { return false }
        switch host {
        case .logic:
            // Logic은 표준 Components 폴더만 본다. 커스텀 폴더는 해당 없음.
            return scope != .custom
        case .ableton12:
            switch format {
            case .au: return settings.abletonUseAudioUnits && scope != .custom
            case .vst2:
                if scope == .custom { return settings.abletonVST2CustomFolder.map { path.hasPrefix($0) } ?? false }
                return settings.abletonUseVST2SystemFolders
            case .vst3:
                if scope == .custom { return settings.abletonVST3CustomFolder.map { path.hasPrefix($0) } ?? false }
                return settings.abletonUseVST3SystemFolders
            default: return false
            }
        }
    }
}

/// Ableton Live 환경설정 > Plug-Ins 탭의 토글을 사용자가 앱에 그대로 입력하는 값.
/// (Live 설정 파일을 직접 파싱하지 않는다: 파일 형식이 공개 문서화되어 있지 않음)
public struct HostSettings: Codable, Hashable, Sendable {
    public var abletonUseAudioUnits: Bool = true
    public var abletonUseVST2SystemFolders: Bool = true
    public var abletonUseVST3SystemFolders: Bool = true
    public var abletonVST2CustomFolder: String?
    public var abletonVST3CustomFolder: String?

    public init() {}

    public var customFolders: [String] {
        [abletonVST2CustomFolder, abletonVST3CustomFolder].compactMap { $0 }
    }
}

/// 같은 제품의 여러 포맷 묶음 (예: Pro-Q 3 = AU + VST3 + VST2)
public struct Product: Identifiable, Hashable, Sendable {
    public var id: String
    public var displayName: String
    public var vendor: String?
    public var bundles: [PluginBundle]

    public var formats: [PluginFormat] {
        PluginFormat.allCases.filter { f in bundles.contains { $0.format == f } }
    }

    public var totalSize: Int64 {
        bundles.compactMap(\.sizeBytes).reduce(0, +)
    }
}
