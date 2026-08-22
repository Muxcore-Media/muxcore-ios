import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var libraryMovies: [Movie] = []
    @State private var libraryTV: [TVShow] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Search…", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onSubmit { Task { await runSearch() } }
                Button("Go") { Task { await runSearch() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            if loading { LoadingStateView() }
            else if let error { ErrorStateView(message: error) }
            else {
                List {
                    if !libraryMovies.isEmpty {
                        Section("In your library — Movies") {
                            ForEach(libraryMovies) { m in
                                NavigationLink(value: m) { Text(m.title) }
                            }
                        }
                    }
                    if !libraryTV.isEmpty {
                        Section("In your library — TV") {
                            ForEach(libraryTV) { s in
                                NavigationLink(value: s) { Text(s.title) }
                            }
                        }
                    }
                    if !results.isEmpty {
                        Section("Add from catalog") {
                            ForEach(results, id: \.stableKey) { row in
                                NavigationLink(value: AppRoute.discover(row.mediaType, row.id)) {
                                    HStack {
                                        PosterImage(urlString: row.poster, cornerRadius: 4)
                                            .frame(width: 40, height: 60)
                                        VStack(alignment: .leading) {
                                            Text(row.title).font(.subheadline.weight(.semibold))
                                            Text("\(row.mediaType.rawValue) · \(row.year)").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search")
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        loading = true
        error = nil
        libraryMovies = []
        libraryTV = []
        do {
            results = try await appState.api.search(query: trimmed)
            let lower = trimmed.lowercased()
            if appState.capabilities.libraryEnabled("movies") {
                let movies = try await appState.api.listMovies(page: 1, pageSize: 200)
                libraryMovies = movies.items.filter { $0.title.lowercased().contains(lower) }.prefix(20).map { $0 }
            }
            if appState.capabilities.libraryEnabled("tv") {
                let shows = try await appState.api.listTVShows(page: 1, pageSize: 200)
                libraryTV = shows.items.filter { $0.title.lowercased().contains(lower) }.prefix(20).map { $0 }
            }
        } catch {
            self.error = error.localizedDescription
            results = []
        }
        loading = false
    }
}
