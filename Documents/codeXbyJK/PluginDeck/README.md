# PluginDeck

macOS 오디오 플러그인(AU / VST2 / VST3 / CLAP / AAX)이 어느 드라이브 어디에 있는지,
Logic Pro / Ableton Live 12에서 보이는지 한눈에 확인하는 앱. 현재 M6.

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

## M4 범위

- 파일 > 예전 맥 스냅샷과 비교 (Cmd+K): 예전 맥에서 내보낸 JSON을 열어 지금 맥과 비교
  - 빠진 제품 (다시 설치 필요), 포맷 일부 빠짐 (예: AU 없음 -> Logic에서 안 보임), 버전 다름, 지금 맥에만 있음
  - 예전 맥에서도 비활성화돼 있던 제품은 재설치 목록에서 제외
  - 지금 맥에서 비활성화(Vault)한 제품은 "있음"으로 봄 (일부러 끈 것)
- "다시 설치할 목록" Markdown 체크리스트 내보내기 (벤더별)

## M5 범위

상세 화면 > "잔여물 찾기 / 제품 전체 정리"

| 찾는 것 | 방법 | 기본 선택 |
|---|---|---|
| 설치 패키지가 깐 파일 | `pkgutil --file-info` 로 번들의 설치 패키지를 찾고 `pkgutil --files` 목록에서 번들 밖 파일 | 확실 (선택) |
| 환경설정 / 캐시 | `~/Library/Preferences/<번들 ID>.plist`, `~/Library/Caches/<번들 ID>` | 확실 (선택) |
| 벤더 데이터 / 프리셋 폴더 | `Application Support`, `Audio/Presets` 아래 벤더 이름 폴더 | 추정 (선택 안 함) |
| 같은 벤더 다른 제품도 쓰는 폴더 | 위와 같음 | 공용 (선택 안 함) |

- `/Library`, `Plug-Ins/VST3` 같은 공용 폴더는 후보에서 제외 (설치 기록의 "끝 항목"만 봄)
- 여러 제품을 한 번에 까는 설치 패키지면 경고
- 선택한 잔여물은 플러그인 번들과 같은 스크립트로 Vault에 옮김 (복구 스크립트 포함)
- 설치 기록 자체(`pkgutil --forget`)는 지우지 않음

## M6 범위 (레트로 스킨)

90년대 말 데스크톱 음악 플레이어 느낌의 자체 디자인. 특정 제품의 스킨 이미지·로고·이름은 쓰지 않음.

- 위: "플레이어" 패널 - 제품 수(LCD 숫자), 흐르는 제목(선택한 제품), 상태 배지(Intel 전용 / 오프라인 / 비활성화), 포맷별 막대
- 아래 왼쪽: "플레이리스트" - 번호, 이름 - 벤더, 포맷, 용량. 경고(Intel 전용/오프라인)는 주황, 비활성화는 흐리게
- 아래 오른쪽: "정보" 패널 - 포맷별 경로/드라이브/버전/아키텍처/DAW + Finder / Disable / Restore 버튼
- 설정 > 화면 > "레트로 스킨 사용"을 끄면 기본 macOS 화면
- 색/글꼴은 `Sources/PluginDeckSkin/RetroTheme.swift` 한 곳에서 관리
- 팝업(외장 찾기, 중복 정리, 스크립트 결과, 이력, 비교, 잔여물)도 같은 스킨. 레트로를 끄면 같은 부품을 macOS 기본 색(`RetroTheme.plain`)으로 그림
- 팝업 단축키: Esc 닫기, 스크립트 결과 화면은 Enter로 닫고 다시 스캔
- CI가 스킨을 PNG로 렌더링해 `skin-snapshots` 결과물로 올림

## 폴더 구조

```
Sources/PluginDeckCore/   UI 없는 로직 (스캔, 번들 분석, 묶기)
Sources/PluginDeckSkin/   레트로 스킨 (색/글꼴 토큰 + 화면 부품, 값만 받음)
Sources/PluginDeckApp/    앱 (상태, 시트, 스킨 연결)
Tests/PluginDeckCoreTests/
```
