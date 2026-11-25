import Foundation

public struct ScanResult: Sendable {
    public var bundles: [PluginBundle]
    /// 존재하지 않아 건너뛴 스캔 경로
    public var missingLocations: [String]
    public var scannedAt: Date
}

/// 읽기 전용 스캐너. 파일을 옮기거나 지우지 않는다.
public struct PluginScanner: Sendable {
    public var maxDepth: Int
    public var computeSizes: Bool

    public init(maxDepth: Int = 4, computeSizes: Bool = true) {
        self.maxDepth = maxDepth
        self.computeSizes = computeSizes
    }

    public func scan(_ locations: [ScanLocation]) -> ScanResult {
        var bundles: [PluginBundle] = []
        var missing: [String] = []
        var seenPaths = Set<String>()

        for location in locations {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: location.path, isDirectory: &isDir), isDir.boolValue else {
                missing.append(location.path)
                continue
            }
            var visitedDirs = Set<String>()
            walk(directory: location.path, location: location, depth: 0, visited: &visitedDirs) { bundle in
                if seenPaths.insert(bundle.path).inserted { bundles.append(bundle) }
            }
        }

        bundles.sort { ($0.name.lowercased(), $0.format.rawValue) < ($1.name.lowercased(), $1.format.rawValue) }
        return ScanResult(bundles: bundles, missingLocations: missing, scannedAt: Date())
    }

    private func walk(directory: String, location: ScanLocation, depth: Int,
                      visited: inout Set<String>, emit: (PluginBundle) -> Void) {
        let real = (directory as NSString).resolvingSymlinksInPath
        guard visited.insert(real).inserted else { return } // 링크 순환 방지
        guard let children = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return }

        for child in children.sorted() where !child.hasPrefix(".") {
            let path = (directory as NSString).appendingPathComponent(child)
            let ext = (child as NSString).pathExtension
            let link = Self.symlinkTarget(of: path)
            let format = PluginFormat(fileExtension: ext)

            if let format, location.format == nil || location.format == format {
                emit(makeBundle(path: path, format: format, location: location, symlinkTarget: link))
                continue
            }

            // 플러그인이 아니면 하위 폴더로 들어감 (벤더별 하위 폴더: VST/Waves/ 등)
            var isDir: ObjCBool = false
            if depth < maxDepth,
               FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                walk(directory: path, location: location, depth: depth + 1, visited: &visited, emit: emit)
            }
        }
    }

    private func makeBundle(path: String, format: PluginFormat, location: ScanLocation,
                            symlinkTarget: String?) -> PluginBundle {
        let resolved = symlinkTarget ?? path
        let exists = FileManager.default.fileExists(atPath: resolved)

        if !exists {
            // 링크 대상이 없음: 외장 드라이브가 빠졌을 가능성
            let name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
            return PluginBundle(
                path: path, resolvedPath: resolved, isSymlink: true, format: format, scope: location.scope,
                status: .offline, volume: VolumeResolver.offlineVolume(forMissingTarget: resolved),
                name: name, bundleID: nil, version: nil, vendor: nil, architectures: [],
                sizeBytes: nil, modifiedAt: nil
            )
        }

        let meta = BundleInspector.inspect(bundleAt: resolved)
        let attrs = try? FileManager.default.attributesOfItem(atPath: resolved)
        return PluginBundle(
            path: path, resolvedPath: resolved, isSymlink: symlinkTarget != nil, format: format,
            scope: location.scope, status: .active, volume: VolumeResolver.volume(for: resolved),
            name: meta.name, bundleID: meta.bundleID, version: meta.version, vendor: meta.vendor,
            architectures: meta.architectures,
            sizeBytes: computeSizes ? BundleInspector.directorySize(at: resolved) : nil,
            modifiedAt: attrs?[.modificationDate] as? Date
        )
    }

    /// 심볼릭 링크면 최종 대상의 절대 경로, 아니면 nil. 대상이 없어도 경로는 돌려준다.
    static func symlinkTarget(of path: String) -> String? {
        let fm = FileManager.default
        guard let type = (try? fm.attributesOfItem(atPath: path))?[.type] as? FileAttributeType,
              type == .typeSymbolicLink,
              let dest = try? fm.destinationOfSymbolicLink(atPath: path) else { return nil }
        let absolute = dest.hasPrefix("/")
            ? dest
            : ((path as NSString).deletingLastPathComponent as NSString).appendingPathComponent(dest)
        let standardized = (absolute as NSString).standardizingPath
        // 링크의 링크까지 따라감 (대상이 있을 때만 가능)
        return fm.fileExists(atPath: standardized) ? (standardized as NSString).resolvingSymlinksInPath : standardized
    }
}
