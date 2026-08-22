import SwiftUI

struct TVShowDetailView: View {
    @EnvironmentObject private var appState: AppState
    let showID: String

    @State private var show: TVShow?
    @State private var loading = true
    @State private var error: String?
    @State private var isFav = false
    @State private var playerItem: PlayerItem?

    var body: some View {
        ScrollView {
            if loading {
                LoadingStateView()
            } else if let error {
                ErrorStateView(message: error)
            } else if let show {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        PosterImage(urlString: show.posterURL, cornerRadius: 12)
                            .frame(width: 140, height: 210)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(show.title)
                                .font(.title2.bold())
                            if show.year > 0 {
                                Text(String(show.year))
                                    .foregroundStyle(.secondary)
                            }
                            if !show.genres.isEmpty {
                                Text(show.genres.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !show.overview.isEmpty {
                        Text(show.overview)
                    }

                    HStack {
                        Button {
                            isFav = appState.userdata.toggleFavorite(FavoriteEntry(
                                id: show.id, kind: .tv, title: show.title,
                                posterURL: show.posterURL, href: "/tv/\(show.id)", year: show.year
                            ))
                        } label: {
                            Label(isFav ? "Favorited" : "Favorite", systemImage: isFav ? "star.fill" : "star")
                        }
                        .buttonStyle(.bordered)
                    }

                    if let seasons = show.seasons {
                        ForEach(seasons) { season in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(season.name.isEmpty ? "Season \(season.seasonNumber)" : season.name)
                                    .font(.headline)
                                ForEach(season.episodes) { episode in
                                    EpisodeRow(
                                        episode: episode,
                                        showTitle: show.title,
                                        onPlay: {
                                            guard episode.hasFile else { return }
                                            let code = String(format: "S%02dE%02d", episode.seasonNumber, episode.episodeNumber)
                                            let title = episode.title.isEmpty
                                                ? "\(show.title) \(code)"
                                                : "\(show.title) \(code) · \(episode.title)"
                                            playerItem = PlayerItem(
                                                id: episode.id,
                                                title: title,
                                                streamPath: episode.streamURL,
                                                posterURL: show.posterURL,
                                                kind: "episode"
                                            )
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(show?.title ?? "TV Show")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $playerItem) { item in
            PlayerView(item: item)
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            show = try await appState.api.getTVShow(id: showID)
            isFav = appState.userdata.isFavorite(id: showID)
        } catch {
            self.error = error.localizedDescription
            show = nil
        }
        loading = false
    }
}

private struct EpisodeRow: View {
    let episode: Episode
    let showTitle: String
    let onPlay: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    episode.title.isEmpty
                        ? "Episode \(episode.episodeNumber)"
                        : episode.title
                )
                .font(.subheadline.weight(.semibold))
                Text("S\(episode.seasonNumber) · E\(episode.episodeNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if episode.hasFile {
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
