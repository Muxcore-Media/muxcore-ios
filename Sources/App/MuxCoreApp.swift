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
    @Environment(\.colorScheme) private var systemColorScheme

    init(appState: AppState) {
        self.appState = appState
        self.userdata = appState.userdata
    }

    var body: some View {
        let palette = AppTheme.palette(theme: userdata.preferences.display.theme, colorScheme: resolvedColorScheme)
        RootView()
            .preferredColorScheme(ThemeResolver.colorScheme(for: userdata.preferences.display.theme))
            .environment(\.muxTheme, palette)
            .tint(palette.accent)
    }

    private var resolvedColorScheme: ColorScheme {
        switch userdata.preferences.display.theme {
        case .dark: return .dark
        case .light: return .light
        case .system: return systemColorScheme
        }
    }
}
