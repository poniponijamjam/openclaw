# IdleFolder MVP Scaffold

This folder contains a SwiftUI-first scaffold for the personal-use MVP of **IdleFolder**.

## Scope
- Detect idle app candidates with configurable rules.
- Run checklist-style cleanup sessions ("today 5 apps").
- Support a manual-only fallback path when Screen Time permission is unavailable.

## Suggested Xcode Setup
1. Create a new iOS SwiftUI app in Xcode named `IdleFolder`.
2. Copy the contents of `IdleFolder/IdleFolderApp` into your app target.
3. Ensure all files are in the same app target membership.
4. Set deployment target to iOS 17+ (recommended).

## Folder Layout
- `Core/Models`: Domain models and enums.
- `Core/Engine`: Idle classification logic.
- `Core/Storage`: Local settings + lightweight persistence wrappers.
- `Data`: Usage providers and Screen Time snapshot pipeline.
- `Features`: SwiftUI screens and feature view models.
- `Extensions/DeviceActivityReportExtension`: Report extension scaffold.

## Review-Safe Product Positioning
- The app does **not** move Home Screen icons automatically.
- Users complete icon moves manually with in-app checklist guidance.
- Core functionality remains available without optional usage-data permissions.

## Screen Time Pipeline
- App requests Screen Time authorization.
- App tries to load usage snapshot from app-group storage.
- If snapshot is missing/stale, app falls back to manual/mock mode.
- DeviceActivity report extension is responsible for persisting fresh snapshots.
- Note: current default scaffold is configured to run in manual-only mode for Personal Team compatibility.

## Next Steps
- Wire `DeviceActivityReportExtension` target in Xcode.
- Implement real usage aggregation inside the extension and save via `ScreenTimeReportBridge`.
- Add integration tests for app-group snapshot read/write flow.
- Run real-device E2E verification with `docs/QA_DEVICE_E2E_CHECKLIST.md`.
- Use `scripts/run_device_qa.sh <device_udid>` to run real-device build/test.
