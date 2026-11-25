# PluginDeck - 구성안 (v0.2, 디자인 제외)

macOS에 흩어져 있는 오디오 플러그인(AU / VST2 / VST3 / AAX / CLAP)을
한 화면에서 "어디 있는지 / 누가 만들었는지 / 지워도 되는지" 확인하고
안전하게 비활성화하는 개인용 앱.

> v0.2: 2026-11-25 질의응답으로 확정한 결정을 반영 (9장). 3-3, 3-5, 4, 6장이 바뀜.

---

## 0. 기술 스택

| 항목 | 선택 | 이유 |
|---|---|---|
| 언어/UI | Swift + SwiftUI (macOS 14+) | IdleFolder와 같은 스택, Xcode 재사용 |
| 배포 | 개인용 로컬 빌드, App Sandbox 없음 | 샌드박스 앱은 사용자가 고르지 않은 경로(`/Library/Audio/...`, `/Volumes/...`)를 자유롭게 읽을 수 없음 |
| 저장소 | SQLite (GRDB) 또는 SwiftData | 스캔 결과 캐시, 삭제 이력, 태그 |
| 관리자 권한 | 사용 안 함 | 앱은 읽기 전용. 파일 이동은 앱이 만든 쉘 스크립트를 사용자가 터미널에서 직접 실행 (9장 결정 5) |

---

## 1. 스캔 대상 (어디 있는지)

### 1-1. 표준 설치 경로

| 포맷 | 확장자 | 시스템 경로 | 사용자 경로 |
|---|---|---|---|
| Audio Unit | `.component` | `/Library/Audio/Plug-Ins/Components` | `~/Library/Audio/Plug-Ins/Components` |
| VST2 | `.vst` | `/Library/Audio/Plug-Ins/VST` | `~/Library/Audio/Plug-Ins/VST` |
| VST3 | `.vst3` | `/Library/Audio/Plug-Ins/VST3` | `~/Library/Audio/Plug-Ins/VST3` |
| CLAP | `.clap` | `/Library/Audio/Plug-Ins/CLAP` | `~/Library/Audio/Plug-Ins/CLAP` |
| AAX | `.aaxplugin` | `/Library/Application Support/Avid/Audio/Plug-Ins` | (없음) |

근거:
- VST3 경로: Steinberg VST3 Developer Portal, "Plug-in Locations" 문서
- CLAP 경로: CLAP 공식 헤더 `include/clap/entry.h` 주석 (free-audio/clap)
- AU / VST2: Apple 관례 경로(`/Library/Audio/Plug-Ins/...`), 대부분 설치 프로그램이 사용
- AAX: Avid Pro Tools 기본 설치 경로

### 1-2. 여러 볼륨(외장 드라이브) 대응
- 표준 경로 안의 **심볼릭 링크 / 에일리어스**를 따라가서 실제 위치(`/Volumes/<드라이브>/...`)를 기록
- 사용자가 추가하는 **커스텀 스캔 폴더** (DAW에 등록해 둔 VST 폴더 등)
- 볼륨 정보 기록: 볼륨 이름, UUID, 내장/외장, 현재 마운트 여부
  - 외장이 빠져 있으면 "오프라인(연결 안 됨)" 상태로 목록에 남김 → 삭제 대상과 구분
- 볼륨 마운트/언마운트 감지: `NSWorkspace.didMountNotification` / `didUnmountNotification`

### 1-3. 같이 찾아야 하는 "잔여물" (삭제 시 함께 정리 후보)
| 종류 | 경로 예시 |
|---|---|
| 벤더 데이터/프리셋 | `/Library/Application Support/<Vendor>`, `~/Library/Application Support/<Vendor>` |
| 환경설정 | `~/Library/Preferences/<bundle id>.plist` |
| 설치 영수증 | `pkgutil --pkgs`, `pkgutil --files <pkg-id>` (`/var/db/receipts`) |
| 샘플 라이브러리 | 벤더별 상이 (외장 드라이브에 있는 경우 많음) - 자동 확정 불가, "추정"으로만 표시 |
| AU 캐시 | `~/Library/Caches/AudioUnitCache` (AU 삭제 후 재스캔 유도용) |

> 잔여물은 벤더마다 규칙이 달라 **100% 자동 판별은 불가**. 매칭 근거(번들 ID, 벤더명, pkg 영수증)를 같이 보여주고 사용자가 체크해서 선택하게 함.

---

## 2. 데이터 모델

```
Volume
  id, name, uuid, isInternal, isOnline, mountPoint

PluginBundle            // 디스크 위의 파일 1개 (.vst3 하나 = 1행)
  id
  path                  // 표준 경로 기준
  resolvedPath          // 심볼릭 링크 따라간 실제 경로
  volumeId
  format                // au | vst2 | vst3 | clap | aax
  bundleId              // Info.plist CFBundleIdentifier
  name, version         // CFBundleName, CFBundleShortVersionString
  vendor                // AU: AudioComponents.manufacturer / 그 외: bundleId 도메인 추정
  architectures         // arm64, x86_64 (Mach-O 헤더 파싱 = lipo -archs 와 동일 정보)
  sizeBytes
  installedAt, modifiedAt
  codeSignTeam          // codesign 서명 팀 ID (벤더 확인 근거)
  scope                 // system | user | custom
  status                // active | disabled | trashed | offline

Product                 // 같은 플러그인의 여러 포맷 묶음 (예: Pro-Q 4 = AU+VST3+AAX+CLAP)
  id, displayName, vendor
  bundles: [PluginBundle]

Leftover                // 잔여물 후보
  path, kind, matchReason, confidence (high/medium/low)

Action (이력)
  id, date, type (disable | enable | trash | restore | delete)
  bundleIds, fromPath, toPath
```

### Product 묶는 규칙 (우선순위 순)
1. 같은 bundleId 접두사 + 같은 이름
2. 같은 코드서명 팀 ID + 이름 유사도
3. 사용자가 수동으로 합치기/분리

---

## 3. 기능 구성

### 3-1. 스캔
- 전체 스캔 / 증분 스캔(FSEvents로 플러그인 폴더 변경 감지)
- 스캔 결과는 DB 캐시 → 앱 시작 시 즉시 표시, 백그라운드에서 갱신

### 3-2. 보기 (어디 있는지 알아보기 쉽게)
- **그룹 기준 전환**: 벤더별 / 포맷별 / 볼륨(드라이브)별 / 제품별
- **필터**: Intel 전용(arm64 없음), 중복 포맷, 오프라인 볼륨, 최근 설치, 용량 큰 순
- **상세 패널**: 포맷별 경로, 실제 위치, 볼륨, 서명, 잔여물 후보
- "Finder에서 보기" (`NSWorkspace.activateFileViewerSelecting`)

### 3-3. 비활성화 (앱은 명령만 만들고, 실행은 사용자가)
- 앱은 파일을 직접 옮기지 않음. 선택한 번들에 대해 쉘 스크립트 2개를 생성:
  - `disable-<날짜>.sh`: 원위치 -> Vault 로 `mv` (시스템 경로는 `sudo mv`)
  - `restore-<날짜>.sh`: Vault -> 원위치 로 되돌리는 스크립트 (같이 생성, 함께 보관)
- 스크립트 실행 후 앱에서 재스캔으로 결과 확인
- 삭제(휴지통) 기능은 두지 않음. 영구 삭제가 필요하면 Vault 폴더에서 사용자가 직접

#### Vault 위치 (드라이브마다 따로, 같은 드라이브 안에서만 이동)
| 원래 위치 | Vault |
|---|---|
| 내장 (`/Library`, `~/Library`) | `/Users/Shared/PluginDeck Vault/<format>/` |
| 외장 (`/Volumes/<X>/...`) | `/Volumes/<X>/PluginDeck Vault/<format>/` |

- 이유: 같은 볼륨 안의 `mv`는 이름 변경이라 즉시 끝나고 추가 용량이 들지 않음. 볼륨 간 `mv`는 복사 후 삭제.
- 플러그인 폴더 **바깥**에 둠: Ableton이 VST 폴더 하위까지 스캔하므로 안에 두면 계속 보임
- 화면에서는 모든 Vault를 합쳐 "비활성화됨" 목록 하나로 표시. Vault도 스캔 대상에 포함 (status = disabled)

#### 일괄 규칙 (제안만, 실행은 스크립트)
- **중복 VST2 정리**: 같은 제품에 VST3이 있으면 VST2 비활성화 후보
- **AU는 건드리지 않음**: Logic이 AU만 읽음
- **Ableton AU 끄기 전 점검**: "AU만 있는 제품" 목록 = Ableton에서 AU 사용을 끄면 사라질 제품
- 실행 중인 DAW(Logic Pro, Ableton Live) 감지 시 스크립트 상단에 경고 주석 + 앱 화면 경고

### 3-4. 이력
- 생성한 스크립트 쌍(disable / restore)을 `~/Library/Application Support/PluginDeck/Scripts/` 에 보관
- 이력 화면 = 스크립트 목록 + 복원 스크립트 다시 열기

### 3-5. 내보내기 (맥 교체 / 재설치용)
- **Markdown 체크리스트**: 벤더별 묶음, `- [ ] Pro-Q 3 (FabFilter) 3.2.1 - AU, VST3` 형식
- **JSON**: 앱이 다시 읽을 수 있는 전체 데이터. 예전 맥 JSON과 현재 스캔을 비교해 "빠진 제품" 목록 생성
- 벤더 설치 관리자 / 다운로드 링크는 번들에 정보가 없어 자동으로 채울 수 없음 (벤더명까지만)

---

## 4. 모듈 구조

```
PluginDeck/
├─ PluginDeckApp/
│  ├─ PluginDeckApp.swift
│  ├─ Core/
│  │  ├─ Models/          Volume, PluginBundle, Product, Leftover, Action
│  │  ├─ Scanner/
│  │  │  ├─ ScanLocations.swift       표준 경로 + 커스텀 경로 정의
│  │  │  ├─ BundleInspector.swift     Info.plist / Mach-O arch / codesign 읽기
│  │  │  ├─ VolumeResolver.swift      심볼릭 링크 → 실제 볼륨
│  │  │  ├─ ProductGrouper.swift      포맷 묶기
│  │  │  └─ LeftoverFinder.swift      잔여물 후보 + pkgutil 영수증
│  │  ├─ Plans/
│  │  │  ├─ DuplicateRules.swift      중복 VST2 / AU 전용 제품 판정
│  │  │  ├─ VaultLayout.swift         볼륨별 Vault 경로 계산
│  │  │  ├─ ScriptWriter.swift        disable / restore 쉘 스크립트 생성
│  │  │  └─ DAWProcessGuard.swift     실행 중인 DAW 감지
│  │  ├─ Discovery/
│  │  │  └─ ExternalFolderFinder.swift 외장 드라이브에서 VST 폴더 후보 찾기
│  │  ├─ Export/
│  │  │  ├─ ChecklistExporter.swift   Markdown 체크리스트
│  │  │  └─ SnapshotDiff.swift        JSON 저장 / 비교
│  │  ├─ Storage/         DB, 이력
│  │  └─ Watch/           FSEvents, 볼륨 마운트 감지
│  ├─ Features/
│  │  ├─ Library/         목록 + 그룹/필터
│  │  ├─ Detail/          상세 패널
│  │  ├─ CleanupFlow/     중복 정리 제안 -> 스크립트 생성 화면
│  │  ├─ History/
│  │  └─ Settings/        커스텀 경로, Vault 위치
│  └─ Skin/               ← 디자인 레이어 분리 (아래 5장)
└─ PluginDeckTests/
   ├─ BundleInspectorTests    가짜 .vst3/.component 번들로 테스트
   ├─ ProductGrouperTests
   └─ ScriptWriterTests       생성된 스크립트를 임시 폴더에서 실행해 이동/복원 검증
```

원칙: `Core`는 UI를 모름 → 나중에 CLI(`plugindeck list`, `plugindeck plan-disable <id>`)도 같은 Core로 만들 수 있음.

참고: 실제 코드 위치는 Swift Package 구조(`Sources/PluginDeckCore`, `Sources/PluginDeckApp`)를 따름. 위 트리는 논리적 구분.

---

## 5. 디자인(나중) 대비 구조만 미리

윈앰프 클래식 계열의 레트로 스타일로 갈 예정이므로 지금은 구조만 맞춰 둠:
- `Skin/` 폴더에 색상·폰트·비트맵 토큰을 모아두고, 화면은 토큰만 참조
- 메인 창 = 작은 "플레이어" 형태(요약: 총 개수 / 용량 / 스캔 상태),
  목록 = "플레이리스트" 창, 상세 = "이퀄라이저" 자리 같은 **분리형 창 구성**을 염두
- 나중에 스킨 교체가 가능하도록 `SkinProvider` 프로토콜 하나로 추상화

> 참고: 레트로 "느낌"을 차용한 자체 디자인으로 진행. 실제 Winamp 스킨 이미지/로고/명칭은 저작권·상표 문제가 있으므로 그대로 쓰지 않음.

---

## 6. 개발 순서 (마일스톤)

| 단계 | 범위 | 완료 기준 |
|---|---|---|
| M1 (완료, CI 통과, 앱 화면 미확인) | 스캐너 + 목록 보기 (읽기 전용) | 표준 5개 포맷 + 커스텀 폴더 스캔, 제품/벤더/포맷/드라이브별 표시 |
| M2 (완료, CI 통과, 앱 화면 미확인) | 외장 VST 폴더 자동 찾기 + 중복 정리 제안 + AU 전용 목록 + 내보내기(MD, JSON) | 외장 Ableton 폴더를 직접 입력 없이 등록 가능 |
| M3 | disable / restore 스크립트 생성 + Vault 스캔 + 이력 | 임시 폴더에서 스크립트 실행 -> 이동 -> 복원 테스트 통과 |
| M4 | 예전 맥 JSON과 비교 ("다시 깔아야 할 목록") | - |
| M5 | 잔여물 탐지 (pkgutil 영수증, 벤더 데이터 폴더) | - |
| M6 | 레트로 스킨 적용 | - |

---

## 7. 확정된 사용 환경 (2026-11-25)

- 하드웨어 = **여러 드라이브** (내장 + 외장)
- DAW = **Logic Pro**, **Ableton Live 12**

### DAW별 포맷 지원 (앱의 "보이는 DAW" 판정 기준)

| DAW | 읽는 포맷 | 읽는 위치 | 근거 / 확실성 |
|---|---|---|---|
| Logic Pro | AU만 | 표준 Components 폴더 (`/Library`, `~/Library`) | Apple Logic Pro 사용 설명서: Logic은 Audio Units 포맷 사용. 확실 |
| Ableton Live 12 | AU, VST2, VST3 | AU: 표준 폴더 / VST2·VST3: 시스템 폴더 + 커스텀 폴더 각 1개 | Ableton Live 12 매뉴얼 Plug-Ins 환경설정 항목. 확실 |
| Ableton Live 12 | CLAP | - | 제가 아는 범위(Live 12)에서는 미지원. 최신 12.x에서 바뀌었는지는 확인 못 함 |

### 외장 드라이브에 플러그인을 두는 방법별 처리
- **Ableton VST 커스텀 폴더를 외장 드라이브로 지정**: 설정 화면에 같은 경로를 입력하면 스캔 + "Ableton에서 보임" 판정
- **표준 폴더에 심볼릭 링크 → 외장 드라이브**: 실제 위치와 드라이브를 표시. Logic AU를 외장에 두려면 이 방법뿐 (Logic에는 커스텀 폴더 설정이 없음)
- **드라이브 분리 시**: 링크가 끊긴 번들 = "오프라인". 삭제 대상에서 자동 제외 예정 (M3)

### Apple Silicon 주의
- arm64 바이너리가 없는(Intel 전용) 플러그인은 DAW를 Rosetta로 실행해야 로드됨 → "Intel 전용" 필터 제공

## 8. 아직 모르는 부분

- Ableton Live 12의 플러그인 설정 파일(`~/Library/Preferences/Ableton/Live 12.x/`) 형식은 공개 문서가 없어 직접 읽지 않음. 대신 외장 드라이브 자동 찾기 + 사용자 확인으로 등록
- Ableton이 VST 폴더 하위를 몇 단계까지 스캔하는지 확인 못 함 (Vault를 플러그인 폴더 밖에 두는 이유)
- Live 12가 VST2로 저장된 프로젝트를 같은 제품의 VST3으로 자동 대체하는지 확인 못 함 -> VST2는 삭제 대신 비활성화
- Logic Pro 플러그인 관리자에서 꺼둔 AU 목록의 저장 위치 확인 못 함
- Native Access / Waves Central 등이 비활성화한 플러그인을 다시 설치하는지 - 테스트 필요
- 외장 드라이브 자동 찾기 소요 시간 - 드라이브 크기/파일 수에 따라 다름, 실측 필요

## 9. 결정 기록 (2026-11-25 질의응답)

| # | 질문 | 결정 | 영향 |
|---|---|---|---|
| 1 | 외장 드라이브 플러그인 연결 방식 | Ableton VST 커스텀 폴더를 외장에 지정 | 외장 VST는 Ableton에서만 보임. 스캔 경로 등록 필수 |
| 2 | 정리 목적 | 중복 정리 + 맥 교체 대비 목록 파악 | 용량 확보는 목표 아님. 중복 정리 / 내보내기를 M2로 |
| 3 | 중복 포맷 처리 | VST3 있는 제품의 VST2는 삭제 대신 비활성화 | 예전 Ableton 프로젝트 대비, 언제든 복구 |
| 4 | Ableton AU 사용 | 끄기로 함 (Logic=AU, Ableton=VST3) | 끄기 전 "AU 전용 제품" 목록 제공. 설정 변경은 사용자가 Ableton에서 직접 |
| 5 | 관리자 권한 | 앱은 읽기 전용. 이동 스크립트 생성만 | privileged helper / 개발자 계정 불필요 |
| 6 | Vault 위치 | 드라이브마다 같은 드라이브 안 | 이동 즉시 완료, 용량 증가 없음 |
| 7 | 외장 플러그인 폴더 찾기 | 자동 찾기 + 사용자 확인 (첫 실행 / 버튼) | 매 스캔마다 외장 전체를 훑지 않음 |
| 8 | 내보내기 형식 | Markdown 체크리스트 + JSON | JSON으로 예전 맥과 비교 |
