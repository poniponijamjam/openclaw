import Foundation

/// 경로가 어느 드라이브(볼륨)에 있는지 알아낸다.
public enum VolumeResolver {
    public static func volume(for path: String) -> VolumeInfo? {
        let url = URL(fileURLWithPath: path)
        var keys: Set<URLResourceKey> = [.volumeNameKey, .volumeURLKey, .volumeUUIDStringKey]
        #if os(macOS)
        keys.insert(.volumeIsInternalKey)
        #endif
        guard let v = try? url.resourceValues(forKeys: keys) else { return nil }
        var isInternal: Bool?
        #if os(macOS)
        isInternal = v.volumeIsInternal
        #endif
        return VolumeInfo(
            name: v.volumeName ?? "Unknown",
            uuid: v.volumeUUIDString,
            isInternal: isInternal,
            mountPoint: v.volume?.path ?? "/",
            isOnline: true
        )
    }

    /// 대상이 사라진 링크에서 볼륨 마운트 지점을 추정한다. `/Volumes/<이름>/...` 형식만 판별.
    public static func offlineVolume(forMissingTarget target: String) -> VolumeInfo? {
        let comps = (target as NSString).pathComponents // ["/", "Volumes", "Name", ...]
        guard comps.count >= 3, comps[1] == "Volumes" else { return nil }
        return .offline(mountPoint: "/Volumes/" + comps[2])
    }
}
