import Foundation

/// 실행 파일 헤더만 읽어서 CPU 아키텍처를 판별한다 (`lipo -archs`와 같은 정보).
/// 참고: <mach-o/fat.h>, <mach-o/loader.h>, <mach/machine.h>
public enum MachOArch {
    static let fatMagic: UInt32 = 0xCAFE_BABE    // FAT_MAGIC (빅엔디언으로 저장)
    static let fatMagic64: UInt32 = 0xCAFE_BABF  // FAT_MAGIC_64
    static let mhMagic64: UInt32 = 0xFEED_FACF   // MH_MAGIC_64
    static let mhCigam64: UInt32 = 0xCFFA_EDFE   // 바이트 순서 반대
    static let mhMagic: UInt32 = 0xFEED_FACE
    static let mhCigam: UInt32 = 0xCEFA_EDFE

    static let cpuTypeX86_64: UInt32 = 0x0100_0007 // CPU_TYPE_X86 | CPU_ARCH_ABI64
    static let cpuTypeARM64: UInt32 = 0x0100_000C  // CPU_TYPE_ARM | CPU_ARCH_ABI64

    public static func architectures(ofFileAt path: String) -> [CPUArch] {
        guard let handle = FileHandle(forReadingAtPath: path) else { return [] }
        defer { try? handle.close() }
        // fat 헤더 8바이트 + 아키텍처 최대 32개 * 32바이트(fat_arch_64)
        guard let data = try? handle.read(upToCount: 8 + 32 * 32) else { return [] }
        return architectures(fromHeader: data)
    }

    public static func architectures(fromHeader data: Data) -> [CPUArch] {
        let bytes = [UInt8](data)
        guard bytes.count >= 8 else { return [] }

        let magicBE = readBE(bytes, 0)
        if magicBE == fatMagic || magicBE == fatMagic64 {
            let count = Int(readBE(bytes, 4))
            let stride = magicBE == fatMagic64 ? 32 : 20
            var result: [CPUArch] = []
            for i in 0..<min(count, 32) {
                let offset = 8 + i * stride
                guard offset + 4 <= bytes.count else { break }
                result.append(map(readBE(bytes, offset)))
            }
            return Array(Set(result)).sorted()
        }

        // thin 바이너리: magic과 cputype이 같은 바이트 순서
        switch magicBE {
        case mhMagic64, mhMagic: return [map(readBE(bytes, 4))]
        case mhCigam64, mhCigam: return [map(readLE(bytes, 4))]
        default: return []
        }
    }

    static func map(_ cpuType: UInt32) -> CPUArch {
        switch cpuType {
        case cpuTypeARM64: return .arm64
        case cpuTypeX86_64: return .x86_64
        default: return .other
        }
    }

    static func readBE(_ b: [UInt8], _ o: Int) -> UInt32 {
        UInt32(b[o]) << 24 | UInt32(b[o + 1]) << 16 | UInt32(b[o + 2]) << 8 | UInt32(b[o + 3])
    }

    static func readLE(_ b: [UInt8], _ o: Int) -> UInt32 {
        UInt32(b[o + 3]) << 24 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 1]) << 8 | UInt32(b[o])
    }
}
