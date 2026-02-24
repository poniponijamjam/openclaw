import SwiftUI

private enum ScanFilter: String, CaseIterable {
    case all = "전체"
    case confirmed = "확정"
    case candidate = "후보"
    case excluded = "예외"
}

struct ScanResultView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filter: ScanFilter = .all

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                summaryCard

                if let info = appState.scanInfoMessage {
                    Text(info)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Picker("필터", selection: $filter) {
                    ForEach(ScanFilter.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                List(filteredUsages) { usage in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(usage.displayName)
                                .font(.headline)
                            Spacer()
                            Text(label(for: appState.idleClass(for: usage.bundleId)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("30일: \(usage.minutes30d)분, 90일: \(usage.minutes90d)분")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Toggle(
                            "필수 앱(예외)",
                            isOn: Binding(
                                get: { appState.whitelist.contains(usage.bundleId) },
                                set: { appState.setWhitelist(usage.bundleId, enabled: $0) }
                            )
                        )
                        .font(.caption)
                    }
                }
                .listStyle(.plain)

                Button("오늘 5개 정리 시작") {
                    appState.startSession(limit: 5)
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 8)
            }
            .padding(.horizontal)
            .navigationTitle("Idle 스캔")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("재스캔") {
                        Task { await appState.runScan() }
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("정리 대상 요약")
                .font(.headline)
            Text("확정 \(count(.idleConfirmed))개, 후보 \(count(.idleCandidate))개")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var filteredUsages: [AppUsage] {
        appState.usages.filter { usage in
            let idleClass = appState.idleClass(for: usage.bundleId)
            switch filter {
            case .all: return true
            case .confirmed: return idleClass == .idleConfirmed
            case .candidate: return idleClass == .idleCandidate
            case .excluded: return idleClass == .excluded
            }
        }
    }

    private func count(_ idleClass: IdleClass) -> Int {
        appState.decisions.values.filter { $0.idleClass == idleClass }.count
    }

    private func label(for idleClass: IdleClass) -> String {
        switch idleClass {
        case .idleConfirmed: return "Idle 확정"
        case .idleCandidate: return "Idle 후보"
        case .active: return "활성"
        case .excluded: return "예외"
        }
    }
}
