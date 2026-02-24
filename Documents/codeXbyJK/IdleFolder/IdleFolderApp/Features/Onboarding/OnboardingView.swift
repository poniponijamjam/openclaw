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

                Section(appState.selectedLanguage.text(ko: "권한 및 데이터", en: "Permissions and Data")) {
                    Text(appState.selectedLanguage.text(
                        ko: "선택 권한(사용량 기반)이 없어도 수동 모드로 정리 기능을 사용할 수 있습니다.",
                        en: "You can still use cleanup features in manual mode without usage permission."
                    ))
                        .font(.subheadline)
                    Toggle(
                        appState.selectedLanguage.text(ko: "수동 모드로 시작", en: "Start in Manual Mode"),
                        isOn: $appState.useManualMode
                    )
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
