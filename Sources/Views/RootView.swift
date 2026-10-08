import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task { await appState.bootstrap() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, appState.isAuthenticated {
                Task { await appState.userdata.synchronize() }
            }
        }
    }
}
