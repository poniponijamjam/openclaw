import SwiftUI

@main
struct IdleFolderApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appState)
                .environment(\.locale, Locale(identifier: appState.selectedLanguage.localeIdentifier))
        }
    }
}
