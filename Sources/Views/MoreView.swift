import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section("Library") {
                ForEach(NavCatalog.mobileMoreItems(appState.capabilities)) { item in
                    NavigationLink(value: route(for: item.to)) {
                        Text(item.label)
                    }
                }
            }
            Section {
                NavigationLink(value: AppRoute.favorites) {
                    Label("Favorites", systemImage: "heart.fill")
                }
                NavigationLink(value: AppRoute.settingsMenu) {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
        }
        .navigationTitle("More")
    }

    private func route(for path: String) -> AppRoute {
        switch path {
        case "/tv": return .tv
        case "/music": return .music
        case "/books": return .books
        case "/comics": return .comics
        case "/audiobooks": return .audiobooks
        case "/homevideos": return .homeVideos
        case "/musicvideos": return .musicVideos
        case "/mixed": return .mixed
        case "/collections": return .collections
        case "/studios": return .studios
        case "/upcoming": return .upcoming
        case "/requests": return .inProgress
        case "/playlists": return .playlists
        case "/queue": return .queue
        case "/livetv": return .livetv
        case "/quickconnect": return .quickConnect
        case "/favorites": return .favorites
        default: return .settings(.profile)
        }
    }
}
