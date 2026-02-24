import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    @State private var confirmThreshold = 0
    @State private var candidateThreshold = 5

    var body: some View {
        NavigationStack {
            Form {
                Section(appState.selectedLanguage.text(ko: "언어", en: "Language")) {
                    Picker(
                        appState.selectedLanguage.text(ko: "앱 언어", en: "App Language"),
                        selection: Binding(
                            get: { appState.selectedLanguage },
                            set: { appState.selectLanguage($0) }
                        )
                    ) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.label).tag(language)
                        }
                    }
                }

                Section("데이터 소스") {
                    Toggle(
                        "Screen Time 연동 사용",
                        isOn: Binding(
                            get: { appState.useScreenTime },
                            set: { enabled in
                                Task {
                                    await appState.setUseScreenTime(enabled)
                                }
                            }
                        )
                    )
                    .disabled(!AppState.screenTimeFeatureEnabled)

                    Text("권한 상태: \(authStatusLabel(appState.screenTimeAuthStatus))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !AppState.screenTimeFeatureEnabled {
                        Text("개인팀 제약으로 현재는 수동 모드만 지원됩니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text(appState.screenTimeSnapshotStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if appState.screenTimeAuthStatus == .denied {
                        Button("설정 앱에서 권한 열기") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }

                    if AppState.screenTimeFeatureEnabled {
                        Button("Screen Time 권한 다시 요청") {
                            Task {
                                await appState.requestScreenTimePermissionForQA()
                            }
                        }
                    }

                    if let info = appState.scanInfoMessage {
                        Text(info)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Idle 판별 기준") {
                    Stepper("30일 기준 분 임계값: \(confirmThreshold)", value: $confirmThreshold, in: 0...30)
                    Stepper("90일 기준 분 임계값: \(candidateThreshold)", value: $candidateThreshold, in: 1...60)

                    Button("기준 저장") {
                        appState.updateRule(
                            IdleRule(
                                confirmMinutesThreshold: confirmThreshold,
                                candidateMinutesThreshold: candidateThreshold
                            )
                        )
                    }
                }

                Section("리마인더") {
                    Toggle(
                        "2주마다 정리 알림",
                        isOn: Binding(
                            get: { appState.reminderEnabled },
                            set: { enabled in
                                Task {
                                    await appState.setReminderEnabled(enabled)
                                }
                            }
                        )
                    )

                    Text("활성화하면 14일마다 로컬 알림을 보냅니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let error = appState.reminderErrorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("개인정보") {
                    Text("사용량 데이터는 기본적으로 온디바이스 처리됩니다.")
                        .font(.subheadline)
                }

                if AppState.screenTimeFeatureEnabled {
                    Section("QA") {
                        NavigationLink("Screen Time E2E 검증") {
                            ScreenTimeQADebugView()
                        }
                    }
                }
            }
            .navigationTitle(appState.selectedLanguage.text(ko: "설정", en: "Settings"))
            .onAppear {
                confirmThreshold = appState.rule.confirmMinutesThreshold
                candidateThreshold = appState.rule.candidateMinutesThreshold
            }
        }
    }

    private func authStatusLabel(_ status: ScreenTimeAuthorizationStatus) -> String {
        switch status {
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
}
