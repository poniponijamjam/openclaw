# DeviceActivityReportExtension Scaffold

This folder contains a scaffold for Screen Time report extension integration.

## Implemented
- `ScreenTimeReportBridge.swift`: saves usage snapshots to app-group storage.
- `DeviceActivityAggregationService.swift`: aggregates usage samples and persists snapshots.

## Integration Steps
1. Create DeviceActivityReportExtension target in Xcode.
2. Extract per-app usage data from DeviceActivity report callbacks.
3. Convert to `[AppUsageSample]` and call `DeviceActivityAggregationService.persist(samples:)`.
4. Ensure App Group ID matches `group.com.example.IdleFolder` (or update code).
