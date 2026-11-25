import SwiftUI

/// 화면 부품에 넘기는 버튼 하나
public struct RetroAction: Identifiable {
    public var id: String { title }
    public var title: String
    public var highlight: Bool
    public var enabled: Bool
    public var perform: () -> Void

    public init(_ title: String, highlight: Bool = false, enabled: Bool = true, perform: @escaping () -> Void) {
        self.title = title
        self.highlight = highlight
        self.enabled = enabled
        self.perform = perform
    }
}

public struct RetroActionRow: View {
    var actions: [RetroAction]
    public init(_ actions: [RetroAction]) { self.actions = actions }
    public var body: some View {
        HStack(spacing: 4) {
            ForEach(actions) { a in
                Button(a.title, action: a.perform)
                    .buttonStyle(RetroButtonStyle(highlight: a.highlight))
                    .disabled(!a.enabled)
            }
        }
    }
}

// MARK: - 상단 "플레이어" 패널: 요약 + 흐르는 제목 + 포맷 막대 + 버튼

public struct Badge: Hashable {
    public var label: String
    public var value: Int
    public init(_ label: String, _ value: Int) {
        self.label = label
        self.value = value
    }
}

public struct PlayerPanelState {
    public var marquee: String
    public var products: Int
    public var bundles: Int
    public var totalSize: String
    public var status: String
    public var badges: [Badge]
    public var bars: [FormatBars.Bar]

    public init(marquee: String, products: Int, bundles: Int, totalSize: String, status: String,
                badges: [Badge], bars: [FormatBars.Bar]) {
        self.marquee = marquee
        self.products = products
        self.bundles = bundles
        self.totalSize = totalSize
        self.status = status
        self.badges = badges
        self.bars = bars
    }
}

public struct RetroPlayerPanel: View {
    @Environment(\.retroTheme) private var t
    var state: PlayerPanelState
    var actions: [RetroAction]
    var secondary: [RetroAction]
    var animated: Bool

    public init(state: PlayerPanelState, actions: [RetroAction], secondary: [RetroAction] = [], animated: Bool = true) {
        self.state = state
        self.actions = actions
        self.secondary = secondary
        self.animated = animated
    }

    public var body: some View {
        VStack(spacing: 0) {
            RetroTitleBar("PluginDeck")
            VStack(spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    // 왼쪽: 큰 숫자
                    VStack(alignment: .leading, spacing: 2) {
                        LCDLabel(String(format: "%04d", min(state.products, 9999)), size: 28)
                        LCDLabel("PRODUCTS", size: 8, dim: true)
                        LCDLabel(state.totalSize, size: 11)
                    }
                    .padding(6)
                    .frame(width: 118, height: 74, alignment: .topLeading)
                    .retroLCD()

                    // 가운데: 흐르는 제목 + 상태
                    VStack(alignment: .leading, spacing: 3) {
                        Marquee(state.marquee, size: 11, animated: animated)
                        HStack(spacing: 10) {
                            LCDLabel("BNDL \(state.bundles)", size: 9)
                            ForEach(state.badges, id: \.self) { b in
                                LCDLabel("\(b.label) \(b.value)", size: 9, dim: b.value == 0,
                                         color: b.value > 0 ? t.accent : nil)
                            }
                        }
                        Spacer(minLength: 0)
                        LCDLabel(state.status, size: 9, dim: true)
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, minHeight: 74, maxHeight: 74, alignment: .topLeading)
                    .retroLCD()

                    // 오른쪽: 포맷 막대
                    FormatBars(state.bars)
                        .padding(6)
                        .frame(height: 74)
                        .retroLCD()
                }
                HStack {
                    RetroActionRow(actions)
                    Spacer(minLength: 8)
                    RetroActionRow(secondary)
                }
            }
            .padding(6)
        }
        .retroPanel()
    }
}

// MARK: - "플레이리스트" 패널

public struct PlaylistRow: Identifiable, Hashable {
    public enum Kind: Hashable { case header, item }
    public var id: String
    public var kind: Kind
    public var index: Int
    public var title: String
    public var subtitle: String
    public var formats: String
    public var trailing: String
    public var warn: Bool
    public var dimmed: Bool

    public init(id: String, kind: Kind = .item, index: Int = 0, title: String, subtitle: String = "",
                formats: String = "", trailing: String = "", warn: Bool = false, dimmed: Bool = false) {
        self.id = id
        self.kind = kind
        self.index = index
        self.title = title
        self.subtitle = subtitle
        self.formats = formats
        self.trailing = trailing
        self.warn = warn
        self.dimmed = dimmed
    }
}

/// 행 목록만 그린다 (스크롤은 바깥에서). 이미지 렌더링에서도 그대로 보이게 List 대신 VStack.
public struct RetroPlaylist: View {
    @Environment(\.retroTheme) private var t
    var rows: [PlaylistRow]
    var selection: String?
    var onSelect: (String) -> Void

    public init(rows: [PlaylistRow], selection: String?, onSelect: @escaping (String) -> Void = { _ in }) {
        self.rows = rows
        self.selection = selection
        self.onSelect = onSelect
    }

    public var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                switch row.kind {
                case .header:
                    HStack {
                        LCDLabel("-- " + row.title.uppercased() + " --", size: 9, color: t.accent)
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                case .item:
                    item(row)
                }
            }
        }
    }

    private func item(_ row: PlaylistRow) -> some View {
        let selected = row.id == selection
        let color: Color = selected ? t.selectionText : row.warn ? t.accent : row.dimmed ? t.lcdDim : t.lcdText
        return HStack(spacing: 6) {
            Text("\(row.index).")
                .frame(width: 34, alignment: .trailing)
            Text(row.subtitle.isEmpty ? row.title : "\(row.title) - \(row.subtitle)")
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            Text(row.formats)
                .foregroundStyle(selected ? t.selectionText : t.lcdDim)
                .lineLimit(1)
            Text(row.trailing)
                .frame(width: 64, alignment: .trailing)
        }
        .font(t.font(11))
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(selected ? t.selection : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(row.id) }
    }
}

// MARK: - 정보 패널 (선택한 제품)

public struct InfoLine: Identifiable, Hashable {
    public var id: String { label + "|" + value }
    public var label: String
    public var value: String
    public var warn: Bool
    public init(_ label: String, _ value: String, warn: Bool = false) {
        self.label = label
        self.value = value
        self.warn = warn
    }
}

public struct InfoSection: Identifiable {
    public var id: String { title }
    public var title: String
    public var lines: [InfoLine]
    public var actions: [RetroAction]
    public init(title: String, lines: [InfoLine], actions: [RetroAction] = []) {
        self.title = title
        self.lines = lines
        self.actions = actions
    }
}

public struct RetroInfoPanel: View {
    @Environment(\.retroTheme) private var t
    var title: String
    var sections: [InfoSection]
    var actions: [RetroAction]

    public init(title: String, sections: [InfoSection], actions: [RetroAction] = []) {
        self.title = title
        self.sections = sections
        self.actions = actions
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LCDLabel(title, size: 13)
            if !actions.isEmpty { RetroActionRow(actions) }
            ForEach(sections) { s in
                VStack(alignment: .leading, spacing: 2) {
                    LCDLabel("[" + s.title + "]", size: 9, color: t.accent)
                    ForEach(s.lines) { line in
                        HStack(alignment: .top, spacing: 6) {
                            Text(line.label.uppercased())
                                .font(t.font(9, bold: true))
                                .foregroundStyle(t.lcdDim)
                                .frame(width: 64, alignment: .leading)
                            Text(line.value)
                                .font(t.font(10))
                                .foregroundStyle(line.warn ? t.accent : t.lcdText)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if !s.actions.isEmpty { RetroActionRow(s.actions).padding(.top, 2) }
                }
                .padding(.top, 4)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
