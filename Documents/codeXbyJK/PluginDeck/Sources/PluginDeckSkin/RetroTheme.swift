import SwiftUI

/// 레트로 스킨 색/글꼴 토큰. 화면은 이 값만 참조한다 (스킨 교체 = 이 값 교체).
/// 90년대 말 데스크톱 음악 플레이어 "느낌"의 자체 팔레트. 특정 제품의 스킨 이미지/색표를 복제하지 않음.
public struct RetroTheme: Sendable {
    public var panel: Color
    public var panelLight: Color
    public var panelDark: Color
    public var titleBar: Color
    public var titleStripe: Color
    public var titleText: Color
    public var lcdBackground: Color
    public var lcdText: Color
    public var lcdDim: Color
    public var lcdGrid: Color
    public var accent: Color
    public var warning: Color
    public var selection: Color
    public var selectionText: Color
    public var buttonFace: Color
    public var buttonText: Color

    public static let classic = RetroTheme(
        panel: Color(hex: 0x2A2A35),
        panelLight: Color(hex: 0x5E5E72),
        panelDark: Color(hex: 0x101016),
        titleBar: Color(hex: 0x1A1A24),
        titleStripe: Color(hex: 0xB8963E),
        titleText: Color(hex: 0xE8D9A8),
        lcdBackground: Color(hex: 0x030603),
        lcdText: Color(hex: 0x39F25A),
        lcdDim: Color(hex: 0x1B6E2A),
        lcdGrid: Color(hex: 0x0B1A0D),
        accent: Color(hex: 0xF2B233),
        warning: Color(hex: 0xF2563C),
        selection: Color(hex: 0x1E3C9A),
        selectionText: Color(hex: 0xFFFFFF),
        buttonFace: Color(hex: 0x3A3A48),
        buttonText: Color(hex: 0xD8D8E4)
    )

    public func font(_ size: CGFloat, bold: Bool = false) -> Font {
        .system(size: size, weight: bold ? .bold : .regular, design: .monospaced)
    }
}

extension Color {
    public init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

private struct RetroThemeKey: EnvironmentKey {
    static let defaultValue = RetroTheme.classic
}

extension EnvironmentValues {
    public var retroTheme: RetroTheme {
        get { self[RetroThemeKey.self] }
        set { self[RetroThemeKey.self] = newValue }
    }
}
