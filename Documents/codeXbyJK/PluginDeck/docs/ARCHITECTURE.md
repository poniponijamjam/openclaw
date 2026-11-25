# PluginDeck - 구성안 (v0.1, 디자인 제외)

macOS에 흩어져 있는 오디오 플러그인(AU / VST2 / VST3 / AAX / CLAP)을
한 화면에서 "어디 있는지 / 누가 만들었는지 / 지워도 되는지" 확인하고
안전하게 비활성화·삭제하는 개인용 앱.

> 전제(확인 필요): "플러그인" = 오디오 플러그인, "다양한 하드웨어" = 내장 SSD + 외장 드라이브 등
> 여러 볼륨에 나뉘어 설치된 상태로 해석함. 다르면 1장(스캔 대상)만 바꾸면 됨.

---

## 0. 기술 스택

| 항목 | 선택 | 이유 |
|---|---|---|
| 언어/UI | Swift + SwiftUI (macOS 14+) | IdleFolder와 같은 스택, Xcode 재사용 |
| 배포 | App Store 밖 (Developer ID + 공증) | App Sandbox 앱은 `/Library` 같은 시스템 경로에 임의 쓰기/삭제 불가. 플러그인 삭제가 핵심 기능이라 샌드박스 불가 |
| 저장소 | SQLite (GRDB) 또는 SwiftData | 스캔 결과 캐시, 삭제 이력, 태그 |
| 관리자 권한 | 1단계: `osascript ... with administrator privileges` / 2단계: `SMAppService` 기반 privileged helper | `/Library/...` 는 root 소유라 삭제 시 권한 상승 필요 |

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

### 3-3. 삭제 (지우기 쉽게, 하지만 되돌릴 수 있게)
3단계로 분리해서 실수 방지:

| 단계 | 동작 | 되돌리기 |
|---|---|---|
| 비활성화 | 번들을 `~/Library/Application Support/PluginDeck/Vault/<format>/` 로 이동 | 원위치 복귀 |
| 휴지통 | `FileManager.trashItem` | Finder 휴지통에서 복구 / 앱에서 복구 |
| 영구 삭제 | 휴지통 비우기는 사용자가 직접 | 불가 |

- 제품 단위 일괄 처리: "Pro-Q 4 전부(AU+VST3+AAX) 비활성화"
- 포맷 단위 일괄 처리: "VST2 전부 비활성화" (VST3 있는 제품만 골라서 등)
- 삭제 전 확인 화면: 대상 파일 목록 + 잔여물 체크박스 + 총 용량
- 실행 중인 DAW 감지 시 경고 (Logic Pro, Ableton Live, Pro Tools, Cubase, FL Studio, Reaper 등 프로세스 확인)
- AU 변경 후: AU 캐시 갱신 안내 (DAW 재시작 또는 `auval -a` 재스캔)

### 3-4. 이력 / 복원
- 모든 이동·삭제는 Action 로그로 남김
- 이력 화면에서 "되돌리기"

### 3-5. 내보내기
- 플러그인 목록 CSV / JSON 내보내기 (새 맥 세팅, 재설치 체크리스트 용도)

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
│  │  ├─ Actions/
│  │  │  ├─ VaultService.swift        비활성화/복원
│  │  │  ├─ TrashService.swift        휴지통 이동
│  │  │  ├─ PrivilegedRunner.swift    관리자 권한 실행
│  │  │  └─ DAWProcessGuard.swift     실행 중인 DAW 감지
│  │  ├─ Storage/         DB, 이력
│  │  └─ Watch/           FSEvents, 볼륨 마운트 감지
│  ├─ Features/
│  │  ├─ Library/         목록 + 그룹/필터
│  │  ├─ Detail/          상세 패널
│  │  ├─ RemoveFlow/      삭제 확인 화면
│  │  ├─ History/
│  │  └─ Settings/        커스텀 경로, Vault 위치
│  └─ Skin/               ← 디자인 레이어 분리 (아래 5장)
├─ PluginDeckHelper/      (2단계) privileged helper
└─ PluginDeckTests/
   ├─ BundleInspectorTests    가짜 .vst3/.component 번들로 테스트
   ├─ ProductGrouperTests
   └─ VaultServiceTests       임시 폴더에서 이동/복원 검증
```

원칙: `Core`는 UI를 모름 → 나중에 CLI(`plugindeck list`, `plugindeck disable <id>`)도 같은 Core로 만들 수 있음.

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
| M1 | 스캐너 + 목록 보기 (읽기 전용) | 표준 5개 포맷 경로를 스캔해서 벤더/포맷/볼륨별로 표시 |
| M2 | 상세 패널 + Finder 열기 + 아키텍처/서명 표시 | Intel 전용 플러그인 필터 동작 |
| M3 | 비활성화(Vault) / 복원 + 이력 | 사용자 경로 플러그인 이동·복원 테스트 통과 |
| M4 | 시스템 경로 삭제 (관리자 권한) + 휴지통 | `/Library` 플러그인 휴지통 이동 |
| M5 | 잔여물 탐지 + 외장 볼륨 오프라인 처리 | pkgutil 영수증 매칭 |
| M6 | 레트로 스킨 적용 | - |

---

## 7. 확인 필요 / 모르는 부분

- "다양한 하드웨어"의 정확한 의미: (a) 여러 드라이브, (b) 여러 대의 맥, (c) UAD 같은 하드웨어 의존 플러그인 - 이 중 어느 것인지
  - (b)라면 맥별 목록을 비교하는 동기화 기능이 추가로 필요
  - (c)라면 "하드웨어 필요" 태그 + 장치 연결 여부 표시가 필요
- 사용하는 DAW 목록 (DAW별 플러그인 DB/블랙리스트 위치가 달라서, 그 정리까지 할지 결정 필요)
- AAX 비활성화 시 Pro Tools가 쓰는 `Plug-Ins (Unused)` 폴더 관례를 따를지 여부 - Pro Tools 버전별 동작은 직접 확인하지 못함
- iLok / Native Access / Waves Central 등 벤더 설치 관리자와 충돌 여부 - 벤더 관리자가 삭제된 플러그인을 다시 설치할 수 있음(확인 안 됨, 테스트 필요)
