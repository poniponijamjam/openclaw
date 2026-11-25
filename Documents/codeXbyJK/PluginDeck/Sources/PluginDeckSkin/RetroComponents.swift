import SwiftUI

// MARK: - 입체 테두리 (튀어나옴 / 들어감)

struct Bevel: ViewModifier {
    @Environment(\.retroTheme) private var t
    var raised: Bool
    var width: CGFloat = 1

    func body(content: Content) -> some View {
        let topLeft = raised ? t.panelLight : t.panelDark
        let bottomRight = raised ? t.panelDark : t.panelLight
        content
            .overlay(alignment: .top) { Rectangle().fill(topLeft).frame(height: width) }
            .overlay(alignment: .leading) { Rectangle().fill(topLeft).frame(width: width) }
            .overlay(alignment: .bottom) { Rectangle().fill(bottomRight).frame(height: width) }
            .overlay(alignment: .trailing) { Rectangle().fill(bottomRight).frame(width: width) }
    }
}

extension View {
    public func retroBevel(raised: Bool = true, width: CGFloat = 1) -> some View {
        modifier(Bevel(raised: raised, width: width))
    }

    /// 금속 패널 배경 + 튀어나온 테두리
    public func retroPanel() -> some View {
        modifier(PanelBackground())
    }

    /// 검은 LCD 창 + 들어간 테두리
    public func retroLCD() -> some View {
        modifier(LCDBackground())
    }
}

struct PanelBackground: ViewModifier {
    @Environment(\.retroTheme) private var t
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(colors: [t.panel.opacity(0.92), t.panel, t.panelDark.opacity(0.9)],
                               startPoint: .top, endPoint: .bottom)
            )
            .retroBevel(raised: true, width: 2)
    }
}

struct LCDBackground: ViewModifier {
    @Environment(\.retroTheme) private var t
    func body(content: Content) -> some View {
        content
            .background(t.lcdBackground)
            .overlay(ScanLines(color: t.lcdGrid).allowsHitTesting(false))
            .retroBevel(raised: false, width: 2)
    }
}

/// LCD 가로 줄무늬
struct ScanLines: View {
    var color: Color
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(color.opacity(0.55)))
                y += 3
            }
        }
    }
}

// MARK: - 타이틀 바

public struct RetroTitleBar: View {
    @Environment(\.retroTheme) private var t
    var title: String

    public init(_ title: String) { self.title = title }

    public var body: some View {
        HStack(spacing: 6) {
            stripes
            Text(title.uppercased())
                .font(t.font(9, bold: true))
                .tracking(2)
                .foregroundStyle(t.titleText)
                .fixedSize()
            stripes
        }
        .padding(.horizontal, 4)
        .frame(height: 14)
        .background(t.titleBar)
    }

    private var stripes: some View {
        VStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { _ in
                Rectangle().fill(t.titleStripe.opacity(0.85)).frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 버튼

public struct RetroButtonStyle: ButtonStyle {
    @Environment(\.retroTheme) private var t
    @Environment(\.isEnabled) private var enabled
    var highlight: Bool

    public init(highlight: Bool = false) { self.highlight = highlight }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(t.font(10, bold: true))
            .textCase(.uppercase)
            .foregroundStyle(highlight ? t.accent : t.buttonText)
            .opacity(enabled ? 1 : 0.4)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(configuration.isPressed ? t.panelDark : t.buttonFace)
            .retroBevel(raised: !configuration.isPressed)
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}

// MARK: - LCD 글자 / 흐르는 제목

public struct LCDLabel: View {
    @Environment(\.retroTheme) private var t
    var text: String
    var size: CGFloat
    var dim: Bool
    var color: Color?

    public init(_ text: String, size: CGFloat = 11, dim: Bool = false, color: Color? = nil) {
        self.text = text
        self.size = size
        self.dim = dim
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(t.font(size, bold: !dim))
            .foregroundStyle(color ?? (dim ? t.lcdDim : t.lcdText))
            .shadow(color: (color ?? t.lcdText).opacity(dim ? 0 : 0.6), radius: 2)
            .lineLimit(1)
    }
}

/// 긴 글자를 옆으로 흘려 보여주는 줄. 짧으면 가만히 있음.
public struct Marquee: View {
    var text: String
    var size: CGFloat
    /// 초당 이동 픽셀
    var speed: Double
    /// false면 정지 화면 (이미지 렌더링 / 동작 줄이기 설정)
    var animated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0

    public init(_ text: String, size: CGFloat = 11, speed: Double = 28, animated: Bool = true) {
        self.text = text
        self.size = size
        self.speed = speed
        self.animated = animated
    }

    public var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 40
            let label = LCDLabel(text, size: size).fixedSize()
            Group {
                if animated && !reduceMotion && textWidth > geo.size.width {
                    TimelineView(.animation) { ctx in
                        let cycle = Double(textWidth + gap)
                        let x = -CGFloat((ctx.date.timeIntervalSinceReferenceDate * speed).truncatingRemainder(dividingBy: cycle))
                        HStack(spacing: gap) { label; label }
                            .offset(x: x)
                    }
                } else {
                    label
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            .clipped()
            .background(
                label.hidden().background(GeometryReader { g in
                    Color.clear.onAppear { textWidth = g.size.width }
                        .onChange(of: text) { textWidth = g.size.width }
                })
            )
        }
        .frame(height: size + 6)
    }
}

// MARK: - 포맷 막대 (스펙트럼 표시 느낌)

public struct FormatBars: View {
    @Environment(\.retroTheme) private var t
    public struct Bar: Identifiable, Hashable {
        public var id: String { label }
        public var label: String
        public var value: Int
        public init(_ label: String, _ value: Int) {
            self.label = label
            self.value = value
        }
    }

    var bars: [Bar]
    var segments: Int

    public init(_ bars: [Bar], segments: Int = 10) {
        self.bars = bars
        self.segments = segments
    }

    public var body: some View {
        let maxValue = max(bars.map(\.value).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(bars) { bar in
                let lit = bar.value == 0 ? 0 : max(1, Int((Double(bar.value) / Double(maxValue) * Double(segments)).rounded()))
                VStack(spacing: 2) {
                    LCDLabel("\(bar.value)", size: 8, dim: bar.value == 0)
                    VStack(spacing: 1) {
                        ForEach((0..<segments).reversed(), id: \.self) { i in
                            Rectangle()
                                .fill(i < lit ? segmentColor(i) : t.lcdGrid)
                                .frame(height: 3)
                        }
                    }
                    .frame(width: 18)
                    LCDLabel(bar.label, size: 7, dim: true)
                }
            }
        }
    }

    private func segmentColor(_ i: Int) -> Color {
        let ratio = Double(i) / Double(max(segments - 1, 1))
        if ratio > 0.85 { return t.warning }
        if ratio > 0.6 { return t.accent }
        return t.lcdText
    }
}
