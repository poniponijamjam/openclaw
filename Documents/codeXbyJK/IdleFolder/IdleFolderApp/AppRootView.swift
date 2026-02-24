import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if !appState.hasSelectedLanguage {
                LanguageSelectionView()
            } else if appState.didCompleteOnboarding {
                MainTabView()
                    .task {
                        await appState.runScan()
                    }
            } else {
                OnboardingView()
            }
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            ScanResultView()
                .tabItem {
                    Label(appState.selectedLanguage.text(ko: "정리", en: "Scan"), systemImage: "sparkles")
                }

            SessionView()
                .tabItem {
                    Label(appState.selectedLanguage.text(ko: "세션", en: "Session"), systemImage: "checklist")
                }

            SettingsView()
                .tabItem {
                    Label(appState.selectedLanguage.text(ko: "설정", en: "Settings"), systemImage: "gearshape")
                }
        }
    }
}

private struct LanguageSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedLanguage: AppLanguage = .korean

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("언어 선택")
                        .font(.title2.bold())
                    Text("Language")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            selectedLanguage = language
                        } label: {
                            HStack {
                                Text(language.label)
                                    .font(.headline)
                                Spacer()
                                if selectedLanguage == language {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    appState.selectLanguage(selectedLanguage)
                } label: {
                    Text(selectedLanguage.text(ko: "계속", en: "Continue"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("IdleFolder")
        }
    }
}
