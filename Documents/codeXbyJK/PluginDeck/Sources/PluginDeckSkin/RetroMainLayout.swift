import SwiftUI

/// 메인 창 배치: 위 "플레이어" 패널, 아래 왼쪽 "플레이리스트", 아래 오른쪽 "정보" 패널.
/// 값만 받으므로 앱과 테스트(이미지 렌더링)에서 같이 쓴다.
public struct RetroMainLayout<Info: View>: View {
    @Environment(\.retroTheme) private var t
    var player: RetroPlayerPanel
    var playlistTitle: String
    var rows: [PlaylistRow]
    var selection: String?
    var onSelect: (String) -> Void
    var footer: [RetroAction]
    var search: Binding<String>?
    /// false면 스크롤 없이 전부 그림 (이미지 렌더링용)
    var scrollable: Bool
    var info: Info

    public init(player: RetroPlayerPanel, playlistTitle: String, rows: [PlaylistRow], selection: String?,
                onSelect: @escaping (String) -> Void, footer: [RetroAction], search: Binding<String>?,
                scrollable: Bool = true, @ViewBuilder info: () -> Info) {
        self.player = player
        self.playlistTitle = playlistTitle
        self.rows = rows
        self.selection = selection
        self.onSelect = onSelect
        self.footer = footer
        self.search = search
        self.scrollable = scrollable
        self.info = info()
    }

    public var body: some View {
        VStack(spacing: 4) {
            player
            HStack(alignment: .top, spacing: 4) {
                VStack(spacing: 0) {
                    RetroTitleBar(playlistTitle)
                    VStack(spacing: 4) {
                        Group {
                            if scrollable {
                                ScrollView { playlist }
                            } else {
                                playlist
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .retroLCD()
                        HStack(spacing: 6) {
                            if let search {
                                HStack(spacing: 4) {
                                    LCDLabel("FIND", size: 9, dim: true)
                                    TextField("", text: search)
                                        .textFieldStyle(.plain)
                                        .font(t.font(11))
                                        .foregroundStyle(t.lcdText)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .frame(maxWidth: 240)
                                .retroLCD()
                            }
                            Spacer(minLength: 4)
                            RetroActionRow(footer)
                        }
                    }
                    .padding(6)
                }
                .retroPanel()

                VStack(spacing: 0) {
                    RetroTitleBar("Info")
                    Group {
                        if scrollable {
                            ScrollView { info }
                        } else {
                            VStack(spacing: 0) { info; Spacer(minLength: 0) }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .retroLCD()
                    .padding(6)
                }
                .frame(width: 360)
                .retroPanel()
            }
        }
        .padding(4)
        .background(t.panelDark)
    }

    private var playlist: some View {
        RetroPlaylist(rows: rows, selection: selection, onSelect: onSelect)
            .padding(.vertical, 4)
    }
}
