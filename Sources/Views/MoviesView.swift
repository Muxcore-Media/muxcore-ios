import SwiftUI

struct MoviesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var items: [Movie] = []
    @State private var loading = true
    @State private var error: String?

    private var watchable: [Movie] {
        items.filter(\.hasFile)
    }

    var body: some View {
        ScrollView {
            if loading {
                LoadingStateView()
            } else if let error {
                ErrorStateView(message: error)
            } else {
                PosterGrid {
                    ForEach(watchable) { movie in
                        NavigationLink(value: movie) {
                            VStack(alignment: .leading, spacing: 6) {
                                PosterImage(urlString: movie.posterURL, cornerRadius: 10)
                                    .frame(height: 160)
                                Text(movie.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(2)
                                if movie.year > 0 {
                                    Text(String(movie.year))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Movies")
        .navigationDestination(for: Movie.self) { movie in
            MovieDetailView(movieID: movie.id)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            let list = try await appState.api.listMovies(page: 1, pageSize: 96)
            items = list.items
        } catch {
            self.error = error.localizedDescription
            items = []
        }
        loading = false
    }
}
