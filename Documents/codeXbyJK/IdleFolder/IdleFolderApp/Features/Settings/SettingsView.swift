import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
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

                Section(appState.selectedLanguage.text(ko: "진행 방식", en: "Flow")) {
                    Text(
                        appState.selectedLanguage.text(
                            ko: "IdleFolder는 Screen Time 없이 규칙(30일/90일) + 사용자 선택(필수 앱 예외)으로 정리 대상을 계산합니다.",
                            en: "IdleFolder computes cleanup targets without Screen Time, using rules (30/90-day thresholds) + user selection (whitelist)."
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Section(appState.selectedLanguage.text(ko: "Idle 판별 기준", en: "Idle Rules")) {
                    Stepper(
                        appState.selectedLanguage.text(
                            ko: "30일 기준 분 임계값: \(confirmThreshold)",
                            en: "30-day threshold (min): \(confirmThreshold)"
                        ),
                        value: $confirmThreshold,
                        in: 0...30
                    )

                    Stepper(
                        appState.selectedLanguage.text(
                            ko: "90일 기준 분 임계값: \(candidateThreshold)",
                            en: "90-day threshold (min): \(candidateThreshold)"
                        ),
                        value: $candidateThreshold,
                        in: 1...60
                    )

                    Button(appState.selectedLanguage.text(ko: "기준 저장", en: "Save Rules")) {
                        appState.updateRule(
                            IdleRule(
                                confirmMinutesThreshold: confirmThreshold,
                                candidateMinutesThreshold: candidateThreshold
                            )
                        )
                    }
                }

                Section(appState.selectedLanguage.text(ko: "리마인더", en: "Reminder")) {
                    Toggle(
                        appState.selectedLanguage.text(ko: "2주마다 정리 알림", en: "Biweekly cleanup reminder"),
                        isOn: Binding(
                            get: { appState.reminderEnabled },
                            set: { enabled in
                                Task {
                                    await appState.setReminderEnabled(enabled)
                                }
                            }
                        )
                    )

                    Text(
                        appState.selectedLanguage.text(
                            ko: "활성화하면 14일마다 로컬 알림을 보냅니다.",
                            en: "When enabled, a local reminder is sent every 14 days."
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if let error = appState.reminderErrorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section(appState.selectedLanguage.text(ko: "개인정보 및 추적", en: "Privacy & Tracking")) {
                    Text(
                        appState.selectedLanguage.text(
                            ko: "앱 사용량/정리 기록은 기본적으로 기기 내부에만 저장되며 외부 서버로 전송하지 않습니다.",
                            en: "Usage and cleanup records are stored on-device by default and are not sent to external servers."
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text(
                        appState.selectedLanguage.text(
                            ko: "광고 식별자(IDFA)를 사용하지 않으며, 타사 앱/웹 간 추적을 수행하지 않습니다.",
                            en: "The app does not use IDFA and does not perform cross-app or cross-site tracking."
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text(
                        appState.selectedLanguage.text(
                            ko: "Screen Time 권한 없이 동작하며, 사용자가 직접 설정한 규칙과 예외 앱 선택만 사용합니다.",
                            en: "The app works without Screen Time permission, using only user-configured rules and whitelist selections."
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Section(appState.selectedLanguage.text(ko: "앱 내 결제", en: "In-App Purchase")) {
                    Button {
                        Task {
                            await appState.restorePurchases()
                        }
                    } label: {
                        if appState.restoreInProgress {
                            ProgressView(appState.selectedLanguage.text(ko: "복원 중...", en: "Restoring..."))
                        } else {
                            Text(appState.selectedLanguage.text(ko: "구매 복원", en: "Restore Purchases"))
                        }
                    }
                    .disabled(appState.restoreInProgress)

                    if let message = appState.restoreMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
}
