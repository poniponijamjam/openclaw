import SwiftUI

#if canImport(DeviceActivity)
import DeviceActivity
#endif

struct ScreenTimeQADebugView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showReport = false

    var body: some View {
        Form {
            Section("현재 상태") {
                Text("권한: \(authText)")
                    .font(.subheadline)
                Text(appState.screenTimeSnapshotStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("E2E 검증") {
                Button("리포트 확장 열기 (스냅샷 생성 트리거)") {
                    showReport = true
                }
                .disabled(appState.screenTimeAuthStatus != .approved)

                Button("스냅샷 상태 새로고침") {
                    appState.refreshSnapshotStatusForQA()
                }
            }

            Section("검증 기준") {
                Text("1) 권한이 승인 상태인지 확인")
                Text("2) 리포트 확장을 열고 5~10초 대기")
                Text("3) 스냅샷 상태에 시간/앱 개수가 표시되는지 확인")
            }
        }
        .navigationTitle("Screen Time QA")
        .sheet(isPresented: $showReport) {
            reportContent
        }
    }

    private var authText: String {
        switch appState.screenTimeAuthStatus {
        case .notDetermined:
            return "미결정"
        case .approved:
            return "승인됨"
        case .denied:
            return "거부됨"
        case .unavailable:
            return "사용 불가"
        }
    }

    @ViewBuilder
    private var reportContent: some View {
#if canImport(DeviceActivity)
        NavigationStack {
            DeviceActivityReport(
                .init("com.example.IdleFolder.snapshot"),
                filter: DeviceActivityFilter(segment: .hourly())
            )
            .navigationTitle("Snapshot Report")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        showReport = false
                        appState.refreshSnapshotStatusForQA()
                    }
                }
            }
        }
#else
        Text("이 빌드에서는 DeviceActivityReport를 사용할 수 없습니다.")
            .padding()
#endif
    }
}
