import SwiftUI

struct MovieDetailView: View {
    @EnvironmentObject private var appState: AppState
    let movieID: String

    @State private var movie: Movie?
    @State private var loading = true
    @State private var error: String?
    @State private var jellyfinURL: String?
    @State private var isFav = false
    @State private var watched = false
    @State private var queued = false
    @State private var playerItem: PlayerItem?

    var body: some View {
        ScrollView {
            if loading { LoadingStateView() }
            else if let error { ErrorStateView(message: error) }
            else if let movie {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        PosterImage(urlString: movie.posterURL, cornerRadius: 12)
                            .frame(width: 140, height: 210)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(movie.title).font(.title2.bold())
                            if movie.year > 0 { Text(String(movie.year)).foregroundStyle(.secondary) }
                            if movie.voteAverage > 0 {
                                Label(String(format: "%.1f", movie.voteAverage), systemImage: "star.fill")
                            }
                            if !movie.genres.isEmpty {
                                Text(movie.genres.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack {
                        if movie.hasFile {
                            Button { openPlayer(movie) } label: {
                                Label("Play", systemImage: "play.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Button {
                            appState.userdata.enqueue(QueueItem(
                                id: movie.id, kind: .movie, title: movie.title,
                                href: "/movies/\(movie.id)", streamURL: movie.streamURL, posterURL: movie.posterURL
                            ))
                            queued = true
                        } label: {
                            Label(queued ? "Queued" : "Queue", systemImage: "list.bullet")
                        }
                        Button {
                            isFav = appState.userdata.toggleFavorite(FavoriteEntry(
                                id: movie.id, kind: .movie, title: movie.title,
                                posterURL: movie.posterURL, href: "/movies/\(movie.id)", year: movie.year
                            ))
                        } label: {
                            Label(isFav ? "Favorited" : "Favorite", systemImage: isFav ? "star.fill" : "star")
                        }
                        Button {
                            watched.toggle()
                            appState.userdata.upsertProgress(ProgressEntry(
                                id: movie.id, kind: .movie, title: movie.title,
                                posterURL: movie.posterURL, href: "/movies/\(movie.id)",
                                streamURL: movie.streamURL,
                                positionSec: watched ? 0 : appState.userdata.getProgress(id: movie.id)?.positionSec ?? 0,
                                durationSec: Double(movie.runtime * 60),
                                updatedAt: "", watched: watched
                            ))
                        } label: {
                            Label(watched ? "Unwatched" : "Watched", systemImage: "checkmark")
                        }
                    }
                    .buttonStyle(.bordered)

                    if let jellyfinURL, let url = URL(string: jellyfinURL) {
                        Link(destination: url) { Label("Open in linked app", systemImage: "arrow.up.right") }
                    }

                    if !movie.overview.isEmpty { Text(movie.overview) }

                    if let name = movie.collectionName {
                        NavigationLink(value: AppRoute.collections) {
                            Text("Part of \(name)").font(.subheadline)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(movie?.title ?? "Movie")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $playerItem) { PlayerView(item: $0) }
        .task { await load() }
    }

    private func openPlayer(_ movie: Movie) {
        playerItem = PlayerItem(id: movie.id, title: movie.title, streamPath: movie.streamURL, posterURL: movie.posterURL, kind: "movie")
    }

    private func load() async {
        loading = true
        do {
            let item = try await appState.api.getMovie(id: movieID)
            movie = item
            isFav = appState.userdata.isFavorite(id: item.id)
            watched = appState.userdata.getProgress(id: item.id)?.watched == true
            jellyfinURL = try? await appState.api.jellyfinPlayURL(muxId: item.id)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
