# PluginDeck

macOS 오디오 플러그인(AU / VST2 / VST3 / CLAP / AAX)이 어느 드라이브 어디에 있는지,
Logic Pro / Ableton Live 12에서 보이는지 한눈에 확인하는 앱. 현재 M1 (읽기 전용).

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

## 폴더 구조

```
Sources/PluginDeckCore/   UI 없는 로직 (스캔, 번들 분석, 묶기)
Sources/PluginDeckApp/    SwiftUI 화면 (임시 기본 디자인, M6에서 레트로 스킨)
Tests/PluginDeckCoreTests/
```
