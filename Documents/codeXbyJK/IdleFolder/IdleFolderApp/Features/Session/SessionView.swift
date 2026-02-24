import SwiftUI

struct SessionView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if appState.tasks.isEmpty {
                    ContentUnavailableView(
                        "진행 중인 세션이 없습니다",
                        systemImage: "checklist",
                        description: Text("정리 탭에서 '오늘 5개 정리 시작'을 눌러 세션을 시작하세요.")
                    )
                } else {
                    progressHeader

                    List(appState.tasks) { task in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(appState.appName(for: task.bundleId))
                                .font(.headline)

                            Text("추천 액션: \(task.recommendedAction.title)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack {
                                Button("이동 완료") {
                                    appState.markTask(task.id, status: .done)
                                }
                                .buttonStyle(.borderedProminent)

                                Button("건너뛰기") {
                                    appState.markTask(task.id, status: .skipped)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding(.horizontal)
            .navigationTitle("정리 세션")
        }
    }

    private var progressHeader: some View {
        let done = appState.tasks.filter { $0.status == .done }.count
        let total = appState.tasks.count

        return VStack(alignment: .leading, spacing: 6) {
            Text("진행률 \(done)/\(total)")
                .font(.headline)
            ProgressView(value: total == 0 ? 0 : Double(done), total: Double(max(total, 1)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
