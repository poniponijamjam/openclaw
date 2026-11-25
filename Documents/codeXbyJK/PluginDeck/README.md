# PluginDeck

macOS 오디오 플러그인(AU / VST2 / VST3 / CLAP / AAX)이 어느 드라이브 어디에 있는지,
Logic Pro / Ableton Live 12에서 보이는지 한눈에 확인하는 앱. 현재 M3.

설계: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## 실행 (맥에서)

```bash
cd Documents/codeXbyJK/PluginDeck
swift test      # Core 테스트 (임시 폴더에 가짜 번들 생성, /Library 건드리지 않음)
swift run       # 앱 실행
```

Xcode로 열기: `open Package.swift` 후 `PluginDeck` 스킴 실행.

요구 사항: macOS 14+, Xcode 15+ (Swift 5.9+)

## M1 범위

- 표준 경로 + Ableton 커스텀 VST 폴더 + 추가 폴더 스캔 (하위 폴더 4단계까지)
- 심볼릭 링크로 외장 드라이브에 둔 플러그인의 실제 위치 / 드라이브 표시
- 드라이브가 빠져 링크가 끊긴 플러그인은 "오프라인"으로 표시
- 제품 / 벤더 / 포맷 / 드라이브별로 묶어 보기, 검색
- 필터: Intel 전용, 오프라인, DAW에서 안 보임, 외장 드라이브
- Finder에서 보기
- 삭제 / 이동 기능 없음 (M3부터)

## M2 범위

- 외장 드라이브에서 플러그인 폴더 자동 찾기 (첫 실행 시 자동, 이후 툴바 버튼). 찾은 폴더를 Ableton VST2/VST3 커스텀 폴더로 등록
- 중복 정리 제안 (툴바 "중복 정리"): VST3가 있는 제품의 VST2 / Ableton에서 AU를 끄면 사라지는 제품 / VST2만 있는 제품
- 내보내기 (파일 메뉴): Markdown 체크리스트 (Cmd+E), JSON 스냅샷 (Shift+Cmd+E)

## M3 범위

앱은 여전히 파일을 직접 옮기지 않습니다. 터미널에서 실행할 bash 스크립트만 만듭니다.

- "중복 정리"에서 VST2 후보를 골라 **비활성화 스크립트 + 복구 스크립트** 쌍 생성. 상세 화면에서 번들 하나씩도 가능
- 옮기는 위치 (Vault, 항상 같은 드라이브 안):
  - 내장: `/Users/Shared/PluginDeck Vault/<원래 절대 경로>`
  - 외장: `/Volumes/<드라이브>/PluginDeck Vault/<드라이브 안 경로>`
- Vault도 스캔해서 "비활성화됨"으로 표시 (필터 제공). 원래 위치를 경로에서 계산하므로 Vault 번들에서 복구 스크립트를 다시 만들 수 있음
- 스크립트 동작: Logic / Ableton 실행 중이면 중단, 대상에 이미 있으면 덮어쓰지 않고 건너뜀, 권한이 필요할 때만 sudo
- 이력: `~/Library/Application Support/PluginDeck/Scripts/` 의 스크립트 목록, 터미널 명령 복사

```bash
bash ~/Library/Application\ Support/PluginDeck/Scripts/disable-YYYYMMDD-HHMMSS.sh
```

## 폴더 구조

```
Sources/PluginDeckCore/   UI 없는 로직 (스캔, 번들 분석, 묶기)
Sources/PluginDeckApp/    SwiftUI 화면 (임시 기본 디자인, M6에서 레트로 스킨)
Tests/PluginDeckCoreTests/
```
