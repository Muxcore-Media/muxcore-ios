import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var movies: [Movie] = []
    @State private var shows: [TVShow] = []
    @State private var loading = true
    @State private var error: String?
    @State private var progress: [ProgressEntry] = []
    @State private var nextUp: [NextUpEntry] = []
    @State private var favorites: [FavoriteEntry] = []
    @State private var inProgressCount = 0
    @State private var playerItem: PlayerItem?

    private var prefs: HomePrefs { appState.userdata.preferences.home }
    private var readyMovies: [Movie] { movies.filter(\.hasFile) }
    private var readyShows: [TVShow] { shows.filter(\.hasFile) }
    private var recommended: [Movie] {
        readyMovies.filter { $0.voteAverage > 0 }.sorted { $0.voteAverage > $1.voteAverage }.prefix(16).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let hero = readyMovies.first(where: { ($0.backdropURL ?? "").isEmpty == false }) ?? readyMovies.first {
                    HeroBanner(movie: hero)
                }

                if loading { LoadingStateView() }
                if let error { ErrorStateView(message: error) }

                if prefs.showContinueWatching && !progress.isEmpty {
                    ShelfSection(title: "Continue watching") {
                        ForEach(progress) { p in
                            ProgressShelfCard(entry: p) {
                                if let item = playerItemForProgress(p) { playerItem = item }
                            }
                        }
                    }
                }

                if prefs.showNextUp && !nextUp.isEmpty {
                    ShelfSection(title: "Next up") {
                        ForEach(nextUp) { n in
                            Button {
                                if let stream = n.streamURL {
                                    playerItem = PlayerItem(id: n.id, title: n.title, streamPath: stream, posterURL: n.posterURL, kind: n.kind.rawValue)
                                }
                            } label: {
                                MediaCard(title: n.title, posterURL: n.posterURL ?? "", subtitle: n.subtitle, ready: true)
                            }
                        }
                    }
                }

                if !recommended.isEmpty {
                    ShelfSection(title: "Recommended") {
                        ForEach(recommended) { movie in
                            NavigationLink(value: movie) {
                                MediaCard(title: movie.title, posterURL: movie.posterURL, subtitle: String(format: "%.1f", movie.voteAverage), ready: true)
                            }
                        }
                    }
                }

                if prefs.showFavorites && !favorites.isEmpty {
                    ShelfSection(title: "Favorites") {
                        ForEach(favorites) { f in
                            NavigationLink(value: f.kind == .tv ? AppRoute.tvShow(f.id) : AppRoute.movie(f.id)) {
                                MediaCard(title: f.title, posterURL: f.posterURL ?? "", subtitle: nil, ready: false)
                            }
                        }
                    }
                }

                if prefs.showNextUp && nextUp.isEmpty && (readyMovies.count + readyShows.count) > 0 {
                    ShelfSection(title: "Available now") {
                        ForEach(readyMovies.prefix(8)) { m in
                            NavigationLink(value: m) { MediaCard(title: m.title, posterURL: m.posterURL, subtitle: nil, ready: true) }
                        }
                        ForEach(readyShows.prefix(8)) { s in
                            NavigationLink(value: s) { MediaCard(title: s.title, posterURL: s.posterURL, subtitle: nil, ready: true) }
                        }
                    }
                }

                if prefs.showRecentRequests && inProgressCount > 0 {
                    NavigationLink(value: AppRoute.inProgress) {
                        Text("\(inProgressCount) titles in progress — view status")
                            .font(.subheadline)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Home")
        .fullScreenCover(item: $playerItem) { PlayerView(item: $0) }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        await appState.userdata.pullFromServer()
        progress = appState.userdata.continueWatching(16)
        favorites = Array(appState.userdata.listFavorites().prefix(16))
        nextUp = await NextUpResolver.resolve(userdata: appState.userdata, fetchShow: { try await appState.api.getTVShow(id: $0) }, limit: 16)
        do {
            let pageSize = appState.userdata.preferences.display.libraryPageSize
            async let movieList = appState.api.listMovies(page: 1, pageSize: pageSize)
            async let tvList = appState.api.listTVShows(page: 1, pageSize: pageSize)
            async let requests = appState.api.listRequests()
            let (m, t, r) = try await (movieList, tvList, requests)
            movies = m.items
            shows = t.items
            inProgressCount = AcquisitionHelpers.mergeInProgress(requests: r, movies: m.items, shows: t.items).count
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func playerItemForProgress(_ p: ProgressEntry) -> PlayerItem? {
        guard let stream = p.streamURL else { return nil }
        return PlayerItem(id: p.id, title: p.title, streamPath: stream, posterURL: p.posterURL, kind: p.kind.rawValue)
    }
}

private struct ProgressShelfCard: View {
    let entry: ProgressEntry
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 6) {
                PosterImage(urlString: entry.posterURL ?? "", cornerRadius: 8)
                    .frame(width: 120, height: 72)
                Text(entry.title).font(.caption.weight(.semibold)).lineLimit(2)
                if entry.durationSec > 0 {
                    Text("\(Int((entry.positionSec / entry.durationSec) * 100))%").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 120)
        }
    }
}

private struct HeroBanner: View {
    let movie: Movie

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let backdrop = movie.backdropURL, !backdrop.isEmpty {
                PosterImage(urlString: backdrop, cornerRadius: 16).frame(height: 200)
            } else {
                Color(.secondarySystemBackground).frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title).font(.title2.bold())
                if movie.year > 0 { Text(String(movie.year)).font(.subheadline).foregroundStyle(.secondary) }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(12)
        }
    }
}
