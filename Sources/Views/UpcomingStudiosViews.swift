import SwiftUI

struct UpcomingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var rows: [(show: TVShow, episode: Episode, air: String)] = []
    @State private var loading = true

    var body: some View {
        List {
            if loading {
                ProgressView()
            } else if rows.isEmpty {
                Text("No upcoming episodes in the next 120 days.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows, id: \.episode.id) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.show.title).font(.headline)
                        Text("S\(row.episode.seasonNumber)E\(row.episode.episodeNumber) · \(row.episode.title)")
                            .font(.subheadline)
                        Text(row.air).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Upcoming")
        .task { await load() }
    }

    private func load() async {
        loading = true
        do {
            let list = try await appState.api.listTVShows(page: 1, pageSize: 100)
            var detailed: [TVShow] = []
            for show in list.items.prefix(40) {
                if let full = try? await appState.api.getTVShow(id: show.id) {
                    detailed.append(full)
                } else {
                    detailed.append(show)
                }
            }
            let now = Date().timeIntervalSince1970
            let horizon = now + 86400 * 120
            var out: [(TVShow, Episode, String)] = []
            for show in detailed {
                for season in show.seasons ?? [] {
                    for ep in season.episodes {
                        guard let air = ep.airDate else { continue }
                        if let parsed = parseAirDate(air), parsed >= now - 86400 * 14 && parsed <= horizon {
                            out.append((show, ep, air))
                        }
                    }
                }
            }
            rows = out.sorted { $0.2 < $1.2 }
        } catch {}
        loading = false
    }

    private func parseAirDate(_ air: String) -> TimeInterval? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(air.prefix(10)))?.timeIntervalSince1970
    }
}

struct StudiosView: View {
    @EnvironmentObject private var appState: AppState
    @State private var movies: [Movie] = []
    @State private var selected: String?
    @State private var loading = true

    private var studios: [(String, Int)] {
        var counts: [String: Int] = [:]
        for m in movies {
            let keys = (m.collectionName?.isEmpty == false) ? [m.collectionName!] : (m.genres.isEmpty ? ["Unknown"] : m.genres)
            for k in keys { counts[k, default: 0] += 1 }
        }
        return counts.sorted { $0.key < $1.key }
    }

    private var filtered: [Movie] {
        guard let selected else { return [] }
        return movies.filter { $0.collectionName == selected || $0.genres.contains(selected) }
    }

    var body: some View {
        ScrollView {
            if loading { LoadingStateView() }
            else if let selected {
                VStack(alignment: .leading, spacing: 12) {
                    Button("← All studios") { self.selected = nil }
                    Text(selected).font(.headline)
                    PosterGrid {
                        ForEach(filtered) { movie in
                            NavigationLink(value: movie) {
                                PosterImage(urlString: movie.posterURL, cornerRadius: 8).frame(height: 140)
                            }
                        }
                    }
                }
                .padding()
            } else {
                List(studios, id: \.0) { name, count in
                    Button("\(name) (\(count))") { selected = name }
                }
            }
        }
        .navigationTitle("Studios")
        .task {
            do { movies = try await appState.api.listMovies(page: 1, pageSize: 500).items }
            catch {}
            loading = false
        }
    }
}
