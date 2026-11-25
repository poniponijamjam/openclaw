import SwiftUI

// MARK: - 팝업 창 틀

/// 팝업(시트) 공통 틀: 타이틀 바 + 설명 + LCD 본문(스크롤) + 아래 버튼 줄
public struct RetroSheet<Content: View>: View {
    @Environment(\.retroTheme) private var t
    var title: String
    var subtitle: [String]
    var width: CGFloat
    var minBodyHeight: CGFloat
    var leadingFooter: [RetroAction]
    var footer: [RetroAction]
    var scrollable: Bool
    var content: Content

    public init(_ title: String, subtitle: [String] = [], width: CGFloat = 720, minBodyHeight: CGFloat = 320,
                leadingFooter: [RetroAction] = [], footer: [RetroAction], scrollable: Bool = true,
                @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.width = width
        self.minBodyHeight = minBodyHeight
        self.leadingFooter = leadingFooter
        self.footer = footer
        self.scrollable = scrollable
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            RetroTitleBar(title)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(subtitle.enumerated()), id: \.offset) { _, line in
                    RetroText(line, tone: .dim, size: 10)
                }
                VStack(spacing: 0) {
                    if scrollable {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) { content }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 0) { content }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: minBodyHeight, alignment: .topLeading)
                .retroLCD()
                HStack(spacing: 6) {
                    RetroActionRow(leadingFooter)
                    Spacer(minLength: 8)
                    RetroActionRow(footer)
                }
            }
            .padding(8)
        }
        .frame(width: width)
        .retroPanel()
        .background(t.panelDark)
    }
}

// MARK: - 본문 부품

/// 여러 줄 가능한 글자 (LCDLabel은 한 줄)
public struct RetroText: View {
    public enum Tone { case normal, dim, accent, warn, good }
    @Environment(\.retroTheme) private var t
    var text: String
    var tone: Tone
    var size: CGFloat
    var bold: Bool
    var selectable: Bool

    public init(_ text: String, tone: Tone = .normal, size: CGFloat = 11, bold: Bool = false, selectable: Bool = false) {
        self.text = text
        self.tone = tone
        self.size = size
        self.bold = bold
        self.selectable = selectable
    }

    public var body: some View {
        let base = Text(text)
            .font(t.font(size, bold: bold))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
        if selectable { base.textSelection(.enabled) } else { base }
    }

    var color: Color {
        switch tone {
        case .normal: return t.lcdText
        case .dim: return t.lcdDim
        case .accent: return t.accent
        case .warn: return t.warning
        case .good: return t.lcdText
        }
    }
}

/// "[ 제목 (3) ]" 구역 머리글
public struct RetroSectionHeader: View {
    @Environment(\.retroTheme) private var t
    var title: String
    var count: Int?

    public init(_ title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text("[" + title.uppercased() + (count.map { " (\($0))" } ?? "") + "]")
                .font(t.font(10, bold: true))
                .foregroundStyle(t.accent)
            Rectangle().fill(t.lcdDim.opacity(0.5)).frame(height: 1)
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

/// "[x]" / "[ ]" 체크 상자 + 내용
public struct RetroCheckRow<Content: View>: View {
    @Environment(\.retroTheme) private var t
    @Binding var isOn: Bool
    var content: Content

    public init(isOn: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isOn = isOn
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(isOn ? "[x]" : "[ ]")
                .font(t.font(11, bold: true))
                .foregroundStyle(isOn ? t.lcdText : t.lcdDim)
            content
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
    }
}

/// 한 줄 항목: 왼쪽 표시 / 제목 + 설명 / 오른쪽 값 / 버튼
public struct RetroRow: View {
    @Environment(\.retroTheme) private var t
    var tag: String?
    var title: String
    var detail: String?
    var trailing: String?
    var tone: RetroText.Tone
    var actions: [RetroAction]

    public init(tag: String? = nil, _ title: String, detail: String? = nil, trailing: String? = nil,
                tone: RetroText.Tone = .normal, actions: [RetroAction] = []) {
        self.tag = tag
        self.title = title
        self.detail = detail
        self.trailing = trailing
        self.tone = tone
        self.actions = actions
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let tag {
                Text(tag)
                    .font(t.font(9, bold: true))
                    .foregroundStyle(t.accent)
                    .frame(width: 58, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 1) {
                RetroText(title, tone: tone, selectable: true)
                if let detail, !detail.isEmpty { RetroText(detail, tone: .dim, size: 9, selectable: true) }
            }
            Spacer(minLength: 6)
            if let trailing { RetroText(trailing, tone: .dim, size: 10) }
            if !actions.isEmpty { RetroActionRow(actions) }
        }
        .padding(.vertical, 2)
    }
}

/// 터미널 명령 한 줄 (복사 버튼은 바깥에서 RetroAction으로)
public struct RetroCommandLine: View {
    @Environment(\.retroTheme) private var t
    var label: String
    var command: String
    var copy: RetroAction

    public init(label: String, command: String, copy: RetroAction) {
        self.label = label
        self.command = command
        self.copy = copy
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(label.uppercased())
                .font(t.font(9, bold: true))
                .foregroundStyle(t.accent)
                .frame(width: 110, alignment: .leading)
            Text("$ " + command)
                .font(t.font(10))
                .foregroundStyle(t.lcdText)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer(minLength: 6)
            RetroActionRow([copy])
        }
        .padding(.vertical, 3)
    }
}

/// 진행 중 표시 (LCD 점 깜빡임 대신 고정 글자: 이미지 렌더링에서도 같게)
public struct RetroBusy: View {
    var text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            RetroText(text + " ...", tone: .accent)
        }
        .padding(.vertical, 6)
    }
}
