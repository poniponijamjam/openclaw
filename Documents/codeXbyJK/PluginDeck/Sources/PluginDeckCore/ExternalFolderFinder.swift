import Foundation

/// 외장 드라이브에서 플러그인이 모여 있는 폴더 후보.
public struct FolderCandidate: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public var path: String
    public var volumeName: String
    /// 이 폴더와 하위 폴더에 있는 번들 수 (포맷별)
    public var counts: [PluginFormat: Int]

    public var total: Int { counts.values.reduce(0, +) }

    /// Ableton 커스텀 폴더로 등록할 때 어느 칸에 넣을지 제안 (VST3가 더 많으면 VST3)
    public var suggestedFormat: PluginFormat? {
        let v2 = counts[.vst2] ?? 0, v3 = counts[.vst3] ?? 0
        if v2 == 0 && v3 == 0 { return nil }
        return v3 >= v2 ? .vst3 : .vst2
    }
}

public struct FolderSearchResult: Sendable {
    public var candidates: [FolderCandidate]
    /// 탐색 한도(maxDirectories)에 걸려 중간에 멈췄는지
    public var truncated: Bool
    public var visitedDirectories: Int
}

/// `/Volumes/*`를 정해진 깊이까지 훑어 플러그인 폴더를 찾는다. 읽기 전용.
public struct ExternalFolderFinder: Sendable {
    public var maxDepth: Int
    public var maxDirectories: Int
    /// 들어가지 않을 패키지/라이브러리 확장자 (내부 파일이 많아 탐색만 느려짐)
    public var skipExtensions: Set<String> = [
        "app", "bundle", "framework", "plugin", "kext", "photoslibrary", "musiclibrary",
        "logicx", "band", "xcodeproj", "git", "sparsebundle", "dmg",
    ]
    public var skipNames: Set<String> = [
        "PluginDeck Vault", "System", "private", "dev", "Volumes", "cores",
        ".Spotlight-V100", ".fseventsd", ".Trashes", ".DocumentRevisions-V100", ".TemporaryItems",
    ]

    public init(maxDepth: Int = 5, maxDirectories: Int = 50_000) {
        self.maxDepth = maxDepth
        self.maxDirectories = maxDirectories
    }

    public func find(volumesRoot: String = "/Volumes") -> FolderSearchResult {
        let fm = FileManager.default
        let bootReal = ("/" as NSString).resolvingSymlinksInPath
        var found: [String: (volume: String, counts: [PluginFormat: Int])] = [:]
        var visited = Set<String>()
        var budget = maxDirectories
        var truncated = false

        let volumes = (try? fm.contentsOfDirectory(atPath: volumesRoot)) ?? []
        for name in volumes.sorted() where !name.hasPrefix(".") {
            let root = (volumesRoot as NSString).appendingPathComponent(name)
            // 부팅 디스크는 /Volumes 안에 / 를 가리키는 링크로 나타남 -> 제외
            if (root as NSString).resolvingSymlinksInPath == bootReal { continue }
            walk(root, volume: name, depth: 0, found: &found, visited: &visited,
                 budget: &budget, truncated: &truncated)
            if truncated { break }
        }

        // 상위 폴더가 이미 후보면 하위 후보를 합친다 (VST/Vendor/ -> VST/)
        let paths = found.keys.sorted()
        var merged: [String: (volume: String, counts: [PluginFormat: Int])] = [:]
        for p in paths {
            if let parent = merged.keys.first(where: { p.hasPrefix($0 + "/") }) {
                for (f, c) in found[p]!.counts { merged[parent]!.counts[f, default: 0] += c }
            } else {
                merged[p] = found[p]!
            }
        }

        let candidates = merged.map { FolderCandidate(path: $0.key, volumeName: $0.value.volume, counts: $0.value.counts) }
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.path < $1.path }
        return FolderSearchResult(candidates: candidates, truncated: truncated,
                                  visitedDirectories: maxDirectories - budget)
    }

    private func walk(_ dir: String, volume: String, depth: Int,
                      found: inout [String: (volume: String, counts: [PluginFormat: Int])],
                      visited: inout Set<String>, budget: inout Int, truncated: inout Bool) {
        guard !truncated else { return }
        guard budget > 0 else { truncated = true; return }
        budget -= 1
        let real = (dir as NSString).resolvingSymlinksInPath
        guard visited.insert(real).inserted else { return }
        guard let children = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }

        var subdirs: [String] = []
        for child in children where !child.hasPrefix(".") && !skipNames.contains(child) {
            let path = (dir as NSString).appendingPathComponent(child)
            let ext = (child as NSString).pathExtension.lowercased()
            if let format = PluginFormat(fileExtension: ext) {
                found[dir, default: (volume: volume, counts: [:])].counts[format, default: 0] += 1
                continue
            }
            if skipExtensions.contains(ext) { continue }
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                subdirs.append(path)
            }
        }
        guard depth < maxDepth else { return }
        for sub in subdirs.sorted() {
            walk(sub, volume: volume, depth: depth + 1, found: &found, visited: &visited,
                 budget: &budget, truncated: &truncated)
        }
    }
}
