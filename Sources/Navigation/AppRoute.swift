import SwiftUI

enum AppRoute: Hashable {
    case favorites
    case queue
    case inProgress
    case collections
    case playlists
    case livetv
    case quickConnect
    case forgotPassword
    case settingsMenu
    case tv
    case music
    case musicArtist(String)
    case books
    case bookAuthor(String)
    case comics
    case audiobooks
    case homeVideos
    case musicVideos
    case mixed
    case upcoming
    case studios
    case settings(SettingsTab)
    case discover(SearchMediaType, Int)
    case movie(String)
    case tvShow(String)
}

enum SettingsTab: String, Hashable, CaseIterable, Identifiable {
    case profile, display, home, playback, subtitles, controls
    var id: String { rawValue }
    var label: String {
        switch self {
        case .profile: return "Profile"
        case .display: return "Display"
        case .home: return "Home"
        case .playback: return "Playback"
        case .subtitles: return "Subtitles"
        case .controls: return "Controls"
        }
    }
}

struct RouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .favorites: FavoritesView()
        case .queue: QueueView()
        case .inProgress: InProgressView()
        case .collections: CollectionsView()
        case .playlists: PlaylistsView()
        case .livetv: LiveTVView()
        case .quickConnect: QuickConnectView()
        case .forgotPassword: ForgotPasswordView()
        case .settingsMenu: SettingsRootView()
        case .tv: TVShowsView()
        case .music: MusicView()
        case .musicArtist(let id): MusicArtistView(artistID: id)
        case .books: LibraryListView(title: "Books", path: "/api/books", detailRoute: { .bookAuthor($0.id) })
        case .bookAuthor(let id): BookAuthorView(authorID: id)
        case .comics: LibraryListView(title: "Comics", path: "/api/comics")
        case .audiobooks: LibraryListView(title: "Audiobooks", path: "/api/audiobooks")
        case .homeVideos: LibraryMoviesView(title: "Home Videos", library: "homevideos")
        case .musicVideos: LibraryMoviesView(title: "Music Videos", library: "musicvideos")
        case .mixed: MixedView()
        case .upcoming: UpcomingView()
        case .studios: StudiosView()
        case .settings(let tab): SettingsDetailView(tab: tab)
        case .discover(let type, let id): DiscoverDetailView(mediaType: type, tmdbID: id)
        case .movie(let id): MovieDetailView(movieID: id)
        case .tvShow(let id): TVShowDetailView(showID: id)
        }
    }
}
