import Foundation

public struct FileMove: Hashable, Codable, Sendable {
    public var from: String
    public var to: String
    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }
    public var reversed: FileMove { FileMove(from: to, to: from) }
}

public struct ScriptPair: Hashable, Sendable {
    public var stamp: String
    public var disablePath: String?
    public var restorePath: String
    public var moves: [FileMove]
}

/// 앱은 파일을 직접 옮기지 않는다. 사용자가 터미널에서 실행할 bash 스크립트만 만든다.
public enum ScriptWriter {
    // MARK: - 이동 목록

    /// 활성 번들 -> Vault. 오프라인/이미 비활성화된 번들은 제외.
    public static func disableMoves(for bundles: [PluginBundle], layout: VaultLayout) -> [FileMove] {
        unique(bundles.filter { $0.status == .active }.map {
            FileMove(from: $0.path, to: layout.vaultPath(forOriginal: $0.path))
        })
    }

    /// Vault 번들 -> 원래 위치
    public static func restoreMoves(for bundles: [PluginBundle]) -> [FileMove] {
        unique(bundles.compactMap { b in
            guard b.status == .disabled, let original = b.originalPath else { return nil }
            return FileMove(from: b.path, to: original)
        })
    }

    private static func unique(_ moves: [FileMove]) -> [FileMove] {
        var seen = Set<String>()
        return moves.filter { seen.insert($0.from).inserted }
    }

    // MARK: - 스크립트 본문

    public static func script(title: String, moves: [FileMove], date: Date = Date(), selfPath: String? = nil) -> String {
        let iso = ISO8601DateFormatter().string(from: date)
        var s = """
        #!/bin/bash
        # PluginDeck: \(title)
        # generated: \(iso)
        # items: \(moves.count)

        """
        if let selfPath { s += "# 실행: bash \(quote(selfPath))\n" }
        s += """
        set -u

        # Logic Pro / Ableton Live 실행 중이면 중단 (무시하려면 PLUGINDECK_FORCE=1)
        if [ "${PLUGINDECK_FORCE:-0}" != "1" ]; then
          if pgrep -f 'Logic Pro[^/]*\\.app/Contents/MacOS/' >/dev/null 2>&1 || pgrep -f 'Ableton Live[^/]*\\.app/Contents/MacOS/' >/dev/null 2>&1; then
            echo "Logic Pro 또는 Ableton Live가 실행 중입니다. 종료한 뒤 다시 실행하세요."
            exit 2
          fi
        fi

        ok=0; skip=0; fail=0
        # 권한이 없으면 그때만 sudo (시스템 폴더 /Library 등). 비밀번호는 처음 한 번 물어봄
        try() { "$@" 2>/dev/null || sudo "$@"; }
        move() {
          local src="$1" dst="$2"
          if [ ! -e "$src" ] && [ ! -L "$src" ]; then echo "건너뜀 (원본 없음): $src"; skip=$((skip+1)); return; fi
          if [ -e "$dst" ] || [ -L "$dst" ]; then echo "건너뜀 (이미 있음): $dst"; skip=$((skip+1)); return; fi
          if try mkdir -p "$(dirname "$dst")" && try mv "$src" "$dst"; then
            echo "완료: $src"; ok=$((ok+1))
          else
            echo "실패: $src"; fail=$((fail+1))
          fi
        }


        """
        for m in moves {
            s += "move \(quote(m.from)) \(quote(m.to))\n"
        }
        s += """

        echo ""
        echo "완료 $ok / 건너뜀 $skip / 실패 $fail"
        echo "PluginDeck에서 다시 스캔하고, DAW에서 플러그인을 다시 스캔하세요."
        [ "$fail" -eq 0 ]

        """
        return s
    }

    /// bash 작은따옴표 인용: ' -> '\''
    static func quote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - 파일 저장

    public static func stamp(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: date)
    }

    /// 비활성화 + 복구 스크립트 쌍
    public static func writeDisablePair(moves: [FileMove], to directory: String, date: Date = Date()) throws -> ScriptPair {
        let st = stamp(date)
        let disable = directory + "/disable-\(st).sh"
        let restore = directory + "/restore-\(st).sh"
        try write(script(title: "비활성화 \(moves.count)개 (복구: restore-\(st).sh)", moves: moves, date: date, selfPath: disable), to: disable)
        try write(script(title: "복구 \(moves.count)개 (disable-\(st).sh 되돌리기)", moves: moves.map(\.reversed), date: date, selfPath: restore), to: restore)
        return ScriptPair(stamp: st, disablePath: disable, restorePath: restore, moves: moves)
    }

    /// Vault 번들을 골라 복구 스크립트만
    public static func writeRestore(moves: [FileMove], to directory: String, date: Date = Date()) throws -> ScriptPair {
        let st = stamp(date)
        let restore = directory + "/restore-\(st).sh"
        try write(script(title: "복구 \(moves.count)개", moves: moves, date: date, selfPath: restore), to: restore)
        return ScriptPair(stamp: st, disablePath: nil, restorePath: restore, moves: moves)
    }

    private static func write(_ text: String, to path: String) throws {
        try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                                withIntermediateDirectories: true)
        try Data(text.utf8).write(to: URL(fileURLWithPath: path))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    }
}

/// 생성된 스크립트 목록 (이력)
public struct ScriptRecord: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public var path: String
    public var kind: String      // "disable" | "restore"
    public var stamp: String
    public var title: String
    public var items: Int
}

public enum ScriptStore {
    public static var defaultDirectory: String {
        NSHomeDirectory() + "/Library/Application Support/PluginDeck/Scripts"
    }

    public static func list(directory: String = defaultDirectory) -> [ScriptRecord] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        return files.filter { $0.hasSuffix(".sh") }.compactMap { name in
            let path = directory + "/" + name
            let base = (name as NSString).deletingPathExtension
            guard let dash = base.firstIndex(of: "-") else { return nil }
            let kind = String(base[..<dash])
            let stamp = String(base[base.index(after: dash)...])
            var title = name, items = 0
            if let text = try? String(contentsOfFile: path, encoding: .utf8) {
                for line in text.split(separator: "\n").prefix(6) {
                    if line.hasPrefix("# PluginDeck: ") { title = String(line.dropFirst("# PluginDeck: ".count)) }
                    if line.hasPrefix("# items: ") { items = Int(line.dropFirst("# items: ".count)) ?? 0 }
                }
            }
            return ScriptRecord(path: path, kind: kind, stamp: stamp, title: title, items: items)
        }
        .sorted { $0.stamp != $1.stamp ? $0.stamp > $1.stamp : $0.kind < $1.kind }
    }
}
