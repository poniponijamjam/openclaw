# IdleFolder 실기기 E2E/QA 체크리스트

## 목표
- Screen Time 권한 승인 이후, DeviceActivityReportExtension이 스냅샷을 생성하는지 확인
- 실기기 테스트를 통과하여 QA 100%로 마감

## 사전 조건
- iPhone 실제 기기 연결
- Xcode `Apple Accounts` 로그인 완료
- `IdleFolder` 타깃 `Signing & Capabilities`에서 Team 설정 완료
- `Signing & Capabilities`에 `Family Controls` capability 추가 확인 (앱/확장 모두)
- 앱/확장 모두 App Group `group.com.example.IdleFolder` 활성화 확인

## E2E 검증 절차
1. 앱 실행 후 `설정 > Screen Time 연동 사용`을 켜고 권한 승인
2. `설정 > QA > Screen Time E2E 검증` 진입
3. `리포트 확장 열기 (스냅샷 생성 트리거)` 버튼 탭
4. 5~10초 대기 후 닫기
5. `스냅샷 상태 새로고침` 탭
6. 아래 기준 충족 확인

## 성공 기준
- 권한 상태가 `승인됨`
- `최근 스냅샷: <날짜/시간>, 앱 <N>개` 형태로 표시
- 이후 스캔 실행 시 수동 모드 폴백 문구 없이 결과 로딩

## 실패 시 점검
- 권한 거부 상태면 iOS 설정에서 Screen Time 권한 재승인
- App Group ID가 앱/확장에서 정확히 동일한지 확인
- 확장 번들 식별자/서명 팀 일치 여부 확인

## 실기기 테스트 실행
1. Xcode에서 기기 선택
2. `Product > Test`
3. 실패 테스트 재실행 후 로그 보관

## 완료 처리
- 위 항목 모두 충족 시 QA 상태를 100%로 업데이트
