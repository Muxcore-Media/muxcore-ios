import SwiftUI

@main
struct MuxCoreApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootShell(appState: appState)
                .environmentObject(appState)
        }
    }
}

private struct RootShell: View {
    @ObservedObject var appState: AppState
    @ObservedObject var userdata: UserDataStore

    init(appState: AppState) {
        self.appState = appState
        self.userdata = appState.userdata
    }

    var body: some View {
        RootView()
            .preferredColorScheme(ThemeResolver.colorScheme(for: userdata.preferences.display.theme))
    }
}
