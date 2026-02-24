import Foundation

#if canImport(DeviceActivity) && canImport(SwiftUI)
import DeviceActivity
import SwiftUI

@main
struct IdleFolderDeviceActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        IdleFolderSnapshotReportScene()
    }
}

private struct IdleFolderSnapshotReport: Codable {
    let persisted: Bool
    let message: String
}

private struct IdleFolderSnapshotReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("com.example.IdleFolder.snapshot")
    let content: (IdleFolderSnapshotReport) -> IdleFolderSnapshotReportView = { report in
        IdleFolderSnapshotReportView(report: report)
    }

    private let aggregationService = DeviceActivityAggregationService()

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> IdleFolderSnapshotReport {
        let asOf = Date()

        do {
            let samples = await collectSamples(from: data)
            try aggregationService.persist(samples: samples, asOf: asOf)
            return IdleFolderSnapshotReport(
                persisted: true,
                message: "Usage snapshot saved."
            )
        } catch {
            return IdleFolderSnapshotReport(
                persisted: false,
                message: "Failed to save usage snapshot: \(error.localizedDescription)"
            )
        }
    }

    private func collectSamples(
        from data: DeviceActivityResults<DeviceActivityData>
    ) async -> [AppUsageSample] {
        var samples: [AppUsageSample] = []

        for await report in data {
            for await segment in report.activitySegments {
                for await category in segment.categories {
                    for await app in category.applications {
                        let duration = app.totalActivityDuration
                        guard duration > 0 else { continue }

                        let fallbackId = String(describing: app.application.token)
                        let bundleId = app.application.bundleIdentifier ?? fallbackId
                        let displayName = app.application.localizedDisplayName ?? bundleId

                        samples.append(
                            AppUsageSample(
                                bundleId: bundleId,
                                displayName: displayName,
                                usedAt: segment.dateInterval.end,
                                durationSeconds: duration
                            )
                        )
                    }
                }
            }
        }

        return samples
    }
}

private struct IdleFolderSnapshotReportView: View {
    let report: IdleFolderSnapshotReport

    var body: some View {
        Text(report.message)
    }
}
#endif
