import Foundation

/// 플러그인을 지울 때 같이 남는 파일 후보.
public struct Leftover: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case receiptFile   // 설치 패키지 영수증에 기록된 파일
        case vendorData    // Application Support/<벤더>
        case presets       // Audio/Presets/<벤더>
        case preferences   // Preferences/<번들 ID>.plist
        case cache         // Caches/<번들 ID>
    }

    public enum Confidence: Int, Comparable, Sendable {
        case low = 0, medium = 1, high = 2
        public static func < (a: Confidence, b: Confidence) -> Bool { a.rawValue < b.rawValue }
    }

    public var id: String { path }
    public var path: String
    public var kind: Kind
    public var confidence: Confidence
    /// 왜 후보인지 (화면 표시용)
    public var reason: String
    /// 같은 폴더를 쓰는 다른 제품 (벤더 공용 폴더)
    public var sharedWith: [String]
    public var sizeBytes: Int64?
}

public struct LeftoverReport: Sendable {
    public var product: Product
    public var leftovers: [Leftover]
    /// 이 제품 번들이 들어 있던 설치 패키지 ID
    public var packageIDs: [String]
    /// 패키지에 같이 들어 있던 다른 플러그인 번들 (= 공용 설치 패키지)
    public var otherPluginsInPackages: [String]
}

// MARK: - 설치 영수증 (pkgutil)

/// 테스트에서 가짜로 바꿀 수 있게 분리
public protocol ReceiptSource: Sendable {
    /// 이 경로를 설치한 패키지 ID 목록
    func packageIDs(forPath path: String) -> [String]
    /// 패키지가 설치한 파일의 절대 경로
    func installedPaths(packageID: String) -> [String]
}

/// `/usr/sbin/pkgutil` 사용. 읽기 전용 명령만 쓴다 (--file-info, --pkg-info, --files).
public struct PkgutilReceiptSource: ReceiptSource {
    public var executable: String

    public init(executable: String = "/usr/sbin/pkgutil") {
        self.executable = executable
    }

    public func packageIDs(forPath path: String) -> [String] {
        guard let out = run(["--file-info", path]) else { return [] }
        return Self.parsePackageIDs(fileInfo: out)
    }

    public func installedPaths(packageID: String) -> [String] {
        guard let info = run(["--pkg-info", packageID]), let files = run(["--files", packageID]) else { return [] }
        let base = Self.installBase(pkgInfo: info)
        return files.split(separator: "\n").map { Self.join(base, String($0)) }
    }

    /// `pkgutil --file-info` 출력에서 `pkgid:` 줄들
    public static func parsePackageIDs(fileInfo: String) -> [String] {
        fileInfo.split(separator: "\n").compactMap { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("pkgid:") else { return nil }
            let id = t.dropFirst("pkgid:".count).trimmingCharacters(in: .whitespaces)
            return id.isEmpty ? nil : id
        }
    }

    /// `pkgutil --pkg-info` 의 volume + location -> 파일 경로 기준 디렉터리
    public static func installBase(pkgInfo: String) -> String {
        var volume = "/", location = ""
        for line in pkgInfo.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("volume:") { volume = t.dropFirst("volume:".count).trimmingCharacters(in: .whitespaces) }
            if t.hasPrefix("location:") { location = t.dropFirst("location:".count).trimmingCharacters(in: .whitespaces) }
        }
        return join(volume.isEmpty ? "/" : volume, location)
    }

    static func join(_ a: String, _ b: String) -> String {
        if b.isEmpty { return a }
        let left = a.hasSuffix("/") ? String(a.dropLast()) : a
        let right = b.hasPrefix("/") ? String(b.dropFirst()) : b
        return left + "/" + right
    }

    private func run(_ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - 찾기

/// 읽기 전용. 후보만 계산하고 옮기지 않는다.
public struct LeftoverFinder: Sendable {
    public var home: String
    /// 시스템 루트 접두사 (테스트용. 실제는 "")
    public var root: String
    public var receipts: ReceiptSource?

    public init(home: String = NSHomeDirectory(), root: String = "", receipts: ReceiptSource? = PkgutilReceiptSource()) {
        self.home = home
        self.root = root
        self.receipts = receipts
    }

    /// 영수증 파일을 이 폴더 아래 "폴더 하나" 단위로 묶는다. 목록에 없는 위치는 후보로 올리지 않음 (/Library 자체 같은 공용 폴더 보호)
    var anchorRoots: [String] {
        [
            "/Library/Application Support/",
            "/Library/Audio/Presets/",
            "/Library/Audio/Sounds/",
            "/Library/Documentation/",
            "/Users/Shared/",
            "/Applications/",
        ].map { root + $0 }
    }

    public func find(for product: Product, among all: [Product]) -> LeftoverReport {
        let fm = FileManager.default
        let ownPaths = Set(product.bundles.flatMap { [$0.path, $0.resolvedPath, $0.originalPath].compactMap { $0 } })
        var result: [String: Leftover] = [:]
        func add(_ l: Leftover) {
            if let old = result[l.path], old.confidence >= l.confidence { return }
            result[l.path] = l
        }

        let keys = vendorKeys(product)
        let others = all.filter { $0.id != product.id }
        /// 폴더 이름이 다른 제품의 벤더와 맞으면 그 제품들 (= 공용 폴더)
        func sharedProducts(folderName: String) -> [String] {
            let n = Self.normalize(folderName)
            return others.filter { o in vendorKeys(o).contains { Self.nameMatches(n, $0) } }.map(\.displayName).sorted()
        }

        // 1) 설치 영수증
        var pkgIDs: [String] = []
        var otherPlugins = Set<String>()
        if let receipts {
            for path in product.bundles.map({ $0.originalPath ?? $0.path }) {
                pkgIDs += receipts.packageIDs(forPath: path)
            }
            pkgIDs = Array(Set(pkgIDs)).sorted()
            for id in pkgIDs {
                // 영수증에는 /Library, /Library/Application Support 같은 "구조용 폴더"도 들어 있다.
                // 다른 항목의 상위 폴더가 아닌 끝 항목(leaf)만 본다.
                for leaf in Self.leaves(receipts.installedPaths(packageID: id)) {
                    if ownPaths.contains(leaf) || ownPaths.contains(where: { leaf.hasPrefix($0 + "/") }) { continue }
                    if let bundle = Self.pluginBundlePath(containing: leaf) {
                        if !ownPaths.contains(bundle) { otherPlugins.insert(bundle) }
                        continue
                    }
                    guard let a1 = anchor(of: leaf, depth: 1), fm.fileExists(atPath: a1) else { continue }
                    let shared = sharedProducts(folderName: (a1 as NSString).lastPathComponent)
                    if shared.isEmpty {
                        add(Leftover(path: a1, kind: .receiptFile, confidence: .high,
                                     reason: "설치 패키지 \(id) 가 설치한 파일", sharedWith: [], sizeBytes: nil))
                    } else if let a2 = anchor(of: leaf, depth: 2), fm.fileExists(atPath: a2) {
                        // 벤더 공용 폴더면 그 안의 하위 항목만 (기본 선택 안 함)
                        add(Leftover(path: a2, kind: .receiptFile, confidence: .medium,
                                     reason: "설치 패키지 \(id) 가 설치한 파일 (벤더 공용 폴더 안)", sharedWith: shared, sizeBytes: nil))
                    }
                }
            }
        }

        // 2) 벤더 폴더 (Application Support, Presets) - 이름 비교
        let vendorFolders: [(String, Leftover.Kind)] = [
            (root + "/Library/Application Support", .vendorData),
            (home + "/Library/Application Support", .vendorData),
            (root + "/Library/Audio/Presets", .presets),
            (home + "/Library/Audio/Presets", .presets),
        ]
        for (parent, kind) in vendorFolders {
            for name in (try? fm.contentsOfDirectory(atPath: parent)) ?? [] where !name.hasPrefix(".") {
                let n = Self.normalize(name)
                guard keys.contains(where: { Self.nameMatches(n, $0) }) else { continue }
                let path = parent + "/" + name
                let shared = sharedProducts(folderName: name)
                add(Leftover(path: path, kind: kind, confidence: shared.isEmpty ? .medium : .low,
                             reason: "폴더 이름이 벤더(\(product.vendor ?? keys.sorted().first ?? "?"))와 같음",
                             sharedWith: shared, sizeBytes: nil))
            }
        }

        // 3) 환경설정 / 캐시 (번들 ID 정확히 일치)
        for id in Set(product.bundles.compactMap(\.bundleID)) {
            let plist = home + "/Library/Preferences/\(id).plist"
            if fm.fileExists(atPath: plist) {
                add(Leftover(path: plist, kind: .preferences, confidence: .high,
                             reason: "번들 ID \(id) 의 환경설정", sharedWith: [], sizeBytes: nil))
            }
            let cache = home + "/Library/Caches/\(id)"
            if fm.fileExists(atPath: cache) {
                add(Leftover(path: cache, kind: .cache, confidence: .high,
                             reason: "번들 ID \(id) 의 캐시", sharedWith: [], sizeBytes: nil))
            }
        }

        // 크기 + 정렬 (확신 높은 순)
        let list = result.values.map { l -> Leftover in
            var l = l
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: l.path, isDirectory: &isDir) {
                l.sizeBytes = isDir.boolValue
                    ? BundleInspector.directorySize(at: l.path)
                    : (try? fm.attributesOfItem(atPath: l.path)[.size] as? NSNumber)?.int64Value
            }
            return l
        }.sorted { $0.confidence != $1.confidence ? $0.confidence > $1.confidence : $0.path < $1.path }

        return LeftoverReport(product: product, leftovers: list, packageIDs: pkgIDs,
                              otherPluginsInPackages: otherPlugins.sorted())
    }

    /// 경로 안에 플러그인 번들(.vst3 등)이 있으면 그 번들 경로
    static func pluginBundlePath(containing path: String) -> String? {
        var acc = ""
        for comp in path.split(separator: "/") {
            acc += "/" + comp
            if PluginFormat(fileExtension: (String(comp) as NSString).pathExtension) != nil { return acc }
        }
        return nil
    }

    /// 다른 항목의 상위 폴더가 아닌 항목만 (영수증은 파일이 수만 개일 수 있어 O(n * 깊이)로)
    static func leaves(_ paths: [String]) -> [String] {
        let all = Set(paths)
        var parents = Set<String>()
        for p in all {
            var dir = (p as NSString).deletingLastPathComponent
            while dir.count > 1, parents.insert(dir).inserted {
                dir = (dir as NSString).deletingLastPathComponent
            }
        }
        return all.subtracting(parents).sorted()
    }

    /// /Library/Application Support/Vendor/x/y -> /Library/Application Support/Vendor
    /// depth 2 -> /Library/Application Support/Vendor/Product
    func anchor(of path: String, depth: Int = 1) -> String? {
        for r in anchorRoots where path.hasPrefix(r) {
            let comps = path.dropFirst(r.count).split(separator: "/")
            guard comps.count >= depth else { return nil }
            return r + comps.prefix(depth).joined(separator: "/")
        }
        return nil
    }

    /// 폴더 이름(정규화) vs 벤더 키: 같거나, 4글자 이상에서 한쪽이 다른 쪽으로 시작
    static func nameMatches(_ n: String, _ key: String) -> Bool {
        n == key || (n.count >= 4 && key.count >= 4 && (n.hasPrefix(key) || key.hasPrefix(n)))
    }

    func vendorKeys(_ p: Product) -> Set<String> {
        var keys = Set<String>()
        if let v = p.vendor { keys.insert(Self.normalize(v)) }
        for id in p.bundles.compactMap(\.bundleID) {
            let parts = id.split(separator: ".")
            if parts.count >= 2 { keys.insert(Self.normalize(String(parts[1]))) }
        }
        // 너무 짧거나 일반적인 이름은 오탐이 많음
        let generic: Set<String> = ["apple", "audio", "plugin", "plugins", "vst", "vst3", "au", "com", "music"]
        return keys.filter { $0.count >= 3 && !generic.contains($0) }
    }

    static func normalize(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
