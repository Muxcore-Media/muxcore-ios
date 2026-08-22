import SwiftUI

struct LibraryListView: View {
    @EnvironmentObject private var appState: AppState
    let title: String
    let path: String
    var detailRoute: ((LibraryRow) -> AppRoute)? = nil

    @State private var response: LibraryListResponse?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading { LoadingStateView() }
            else if let error { ErrorStateView(message: error) }
            else if let response {
                if response.comingSoon || !response.available {
                    ContentUnavailableView("Coming soon", systemImage: "clock", description: Text(response.message ?? "\(title) isn't available yet."))
                } else if response.items.isEmpty {
                    ContentUnavailableView("Empty library", systemImage: "books.vertical")
                } else {
                    List(response.items) { row in
                        if let route = detailRoute?(row) {
                            NavigationLink(value: route) {
                                rowLabel(row)
                            }
                        } else {
                            rowLabel(row)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .task { await load() }
    }

    private func rowLabel(_ row: LibraryRow) -> some View {
        HStack {
            Text(row.name ?? row.title ?? row.id)
            Spacer()
            if let year = row.year { Text(String(year)).foregroundStyle(.secondary) }
        }
    }

    private func load() async {
        loading = true
        do {
            response = try await appState.api.listLibrary(path: path)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct LibraryMoviesView: View {
    @EnvironmentObject private var appState: AppState
    let title: String
    let library: String
    @State private var items: [Movie] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            if loading { LoadingStateView() }
            else if let error { ErrorStateView(message: error) }
            else {
                PosterGrid {
                    ForEach(items.filter(\.hasFile)) { movie in
                        NavigationLink(value: movie) {
                            PosterImage(urlString: movie.posterURL, cornerRadius: 8)
                                .frame(height: 160)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(title)
        .task { await load() }
    }

    private func load() async {
        loading = true
        do {
            let list = try await appState.api.listMoviesLibrary(library: library, pageSize: 96)
            items = list.items
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct MixedView: View {
    @EnvironmentObject private var appState: AppState
    @State private var movies: [Movie] = []
    @State private var shows: [TVShow] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            if loading { LoadingStateView() }
            else {
                VStack(alignment: .leading, spacing: 16) {
                    if !movies.isEmpty {
                        Text("Movies").font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(movies.filter(\.hasFile)) { m in
                                    NavigationLink(value: m) {
                                        MediaCard(title: m.title, posterURL: m.posterURL, subtitle: nil, ready: true)
                                    }
                                }
                            }
                        }
                    }
                    if !shows.isEmpty {
                        Text("TV").font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(shows.filter(\.hasFile)) { s in
                                    NavigationLink(value: s) {
                                        MediaCard(title: s.title, posterURL: s.posterURL, subtitle: nil, ready: true)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Mixed")
        .task {
            do {
                async let m = appState.api.listMovies(page: 1, pageSize: 48)
                async let t = appState.api.listTVShows(page: 1, pageSize: 48)
                let (ml, tl) = try await (m, t)
                movies = ml.items
                shows = tl.items
            } catch {}
            loading = false
        }
    }
}
