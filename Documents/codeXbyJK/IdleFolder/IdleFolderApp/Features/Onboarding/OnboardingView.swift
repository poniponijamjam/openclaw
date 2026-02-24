import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedGoal: Goal = .cleanHome

    private enum Goal: String, CaseIterable, Identifiable {
        case cleanHome
        case saveStorage
        case reduceDistractions

        var id: String { rawValue }

        func title(language: AppLanguage) -> String {
            switch self {
            case .cleanHome:
                return language.text(ko: "홈 화면 깔끔", en: "Clean Home Screen")
            case .saveStorage:
                return language.text(ko: "저장공간 확보", en: "Save Storage")
            case .reduceDistractions:
                return language.text(ko: "방해 앱 줄이기", en: "Reduce Distractions")
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(appState.selectedLanguage.text(ko: "정리 목표", en: "Goal")) {
                    Picker(
                        appState.selectedLanguage.text(ko: "목표", en: "Goal"),
                        selection: $selectedGoal
                    ) {
                        ForEach(Goal.allCases) { goal in
                            Text(goal.title(language: appState.selectedLanguage)).tag(goal)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(appState.selectedLanguage.text(ko: "데이터 처리", en: "Data Handling")) {
                    Text(appState.selectedLanguage.text(
                        ko: "Screen Time 권한 없이 규칙(30일/90일)과 사용자 선택(예외 앱)으로 정리 기능을 사용합니다.",
                        en: "Cleanup runs without Screen Time permission, using rules (30/90-day) and user selection (whitelist)."
                    ))
                        .font(.subheadline)

                    Text(appState.selectedLanguage.text(
                        ko: "앱 데이터는 기본적으로 기기 내부에만 저장되며 외부 서버로 전송하지 않습니다.",
                        en: "App data is stored on-device by default and is not sent to external servers."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Section {
                    Button(appState.selectedLanguage.text(ko: "시작하기", en: "Get Started")) {
                        appState.didCompleteOnboarding = true
                    }
                }
            }
            .navigationTitle("IdleFolder")
        }
    }
}
