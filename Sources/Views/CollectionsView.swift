import SwiftUI

struct CollectionsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var movies: [Movie] = []
    @State private var serverCols: [CollectionSummary] = []
    @State private var detail: (name: String, movies: [Movie])?
    @State private var loading = true
    @State private var error: String?

    private var genreCollections: [(String, [Movie])] {
        var map: [String: [Movie]] = [:]
        for m in movies {
            let keys = m.genres.isEmpty ? ["Uncategorized"] : m.genres
            for g in keys {
                map[g, default: []].append(m)
            }
        }
        return map.filter { $0.value.count >= 2 }.sorted { $0.key < $1.key }
    }

    var body: some View {
        ScrollView {
            if loading { LoadingStateView() }
            else if let error { ErrorStateView(message: error) }
            else {
                VStack(alignment: .leading, spacing: 24) {
                    if let detail {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(detail.name).font(.headline)
                                Spacer()
                                Button("Close") { self.detail = nil }
                            }
                            PosterGrid {
                                ForEach(detail.movies) { movie in
                                    NavigationLink(value: movie) {
                                        PosterImage(urlString: movie.posterURL, cornerRadius: 8)
                                            .frame(height: 140)
                                    }
                                }
                            }
                        }
                    }
                    if !serverCols.isEmpty {
                        Text("Box sets").font(.headline)
                        ForEach(serverCols) { col in
                            Button {
                                Task { await openCollection(id: col.id) }
                            } label: {
                                HStack {
                                    Text(col.name)
                                    Spacer()
                                    Text("\(col.movieCount) titles")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    ForEach(genreCollections, id: \.0) { name, items in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(name) (genre)").font(.headline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(items) { movie in
                                        NavigationLink(value: movie) {
                                            MediaCard(title: movie.title, posterURL: movie.posterURL, subtitle: nil, ready: movie.hasFile)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Collections")
        .task { await load() }
    }

    private func load() async {
        loading = true
        do {
            let list = try await appState.api.listMovies(page: 1, pageSize: 200)
            movies = list.items
            serverCols = (try? await appState.api.listCollections()) ?? []
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func openCollection(id: String) async {
        do {
            let d = try await appState.api.getCollection(id: id)
            detail = (d.name, d.movies)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
