import SwiftUI

struct SettingsDetailView: View {
    @EnvironmentObject private var appState: AppState
    let tab: SettingsTab

    var body: some View {
        Form {
            switch tab {
            case .profile:
                Section {
                    if let username = appState.username {
                        Text("Signed in as \(username)")
                    } else {
                        Text("Signed in")
                    }
                    Button("Sign out", role: .destructive) { appState.logout() }
                    NavigationLink(value: AppRoute.forgotPassword) { Text("Forgot password") }
                    NavigationLink(value: AppRoute.quickConnect) { Text("Quick Connect") }
                }
            case .display:
                Section {
                    Picker("Theme", selection: themeBinding) {
                        Text("Dark").tag(DisplayPrefs.Theme.dark)
                        Text("Light").tag(DisplayPrefs.Theme.light)
                        Text("System").tag(DisplayPrefs.Theme.system)
                    }
                    Stepper("Titles per page: \(appState.userdata.preferences.display.libraryPageSize)", value: pageSizeBinding, in: 12...200)
                    Toggle("Show watched indicators", isOn: watchedIndicatorsBinding)
                }
            case .home:
                Section {
                    Toggle("Continue watching", isOn: homeToggle(\.showContinueWatching))
                    Toggle("Favorites row", isOn: homeToggle(\.showFavorites))
                    Toggle("In progress on home", isOn: homeToggle(\.showRecentRequests))
                    Toggle("Next up", isOn: homeToggle(\.showNextUp))
                }
            case .playback:
                Section {
                    Toggle("Autoplay next episode", isOn: playbackToggle(\.autoplayNext))
                    Toggle("Remember playback position", isOn: playbackToggle(\.rememberPosition))
                    Stepper("Skip intro: \(appState.userdata.preferences.playback.skipIntroSec)s", value: skipIntroBinding, in: 0...300)
                }
            case .subtitles:
                Section {
                    Toggle("Prefer subtitles", isOn: subtitleToggle(\.enabled))
                    TextField("Language", text: subtitleLanguageBinding)
                    Picker("Text size", selection: subtitleSizeBinding) {
                        Text("Small").tag(SubtitlePrefs.TextSize.sm)
                        Text("Medium").tag(SubtitlePrefs.TextSize.md)
                        Text("Large").tag(SubtitlePrefs.TextSize.lg)
                    }
                }
            case .controls:
                Section {
                    Toggle("Keyboard shortcuts in player", isOn: controlsToggle(\.enableKeyboardShortcuts))
                }
            }
        }
        .navigationTitle(tab.label)
    }

    private var themeBinding: Binding<DisplayPrefs.Theme> {
        Binding(
            get: { appState.userdata.preferences.display.theme },
            set: { v in appState.userdata.updatePreferences { $0.display.theme = v } }
        )
    }

    private var pageSizeBinding: Binding<Int> {
        Binding(
            get: { appState.userdata.preferences.display.libraryPageSize },
            set: { v in appState.userdata.updatePreferences { $0.display.libraryPageSize = v } }
        )
    }

    private var watchedIndicatorsBinding: Binding<Bool> {
        Binding(
            get: { appState.userdata.preferences.display.showWatchedIndicators },
            set: { v in appState.userdata.updatePreferences { $0.display.showWatchedIndicators = v } }
        )
    }

    private var skipIntroBinding: Binding<Int> {
        Binding(
            get: { appState.userdata.preferences.playback.skipIntroSec },
            set: { v in appState.userdata.updatePreferences { $0.playback.skipIntroSec = v } }
        )
    }

    private var subtitleLanguageBinding: Binding<String> {
        Binding(
            get: { appState.userdata.preferences.subtitles.language },
            set: { v in appState.userdata.updatePreferences { $0.subtitles.language = v } }
        )
    }

    private var subtitleSizeBinding: Binding<SubtitlePrefs.TextSize> {
        Binding(
            get: { appState.userdata.preferences.subtitles.textSize },
            set: { v in appState.userdata.updatePreferences { $0.subtitles.textSize = v } }
        )
    }

    private func homeToggle(_ keyPath: WritableKeyPath<HomePrefs, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState.userdata.preferences.home[keyPath: keyPath] },
            set: { v in appState.userdata.updatePreferences { $0.home[keyPath: keyPath] = v } }
        )
    }

    private func playbackToggle(_ keyPath: WritableKeyPath<PlaybackPrefs, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState.userdata.preferences.playback[keyPath: keyPath] },
            set: { v in appState.userdata.updatePreferences { $0.playback[keyPath: keyPath] = v } }
        )
    }

    private func subtitleToggle(_ keyPath: WritableKeyPath<SubtitlePrefs, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState.userdata.preferences.subtitles[keyPath: keyPath] },
            set: { v in appState.userdata.updatePreferences { $0.subtitles[keyPath: keyPath] = v } }
        )
    }

    private func controlsToggle(_ keyPath: WritableKeyPath<ControlPrefs, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState.userdata.preferences.controls[keyPath: keyPath] },
            set: { v in appState.userdata.updatePreferences { $0.controls[keyPath: keyPath] = v } }
        )
    }
}
