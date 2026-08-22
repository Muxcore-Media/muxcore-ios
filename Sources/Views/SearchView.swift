import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var scope: SearchScope = .all
    @State private var libraryHits: [LibrarySearchHit] = []
    @State private var remoteResults: [SearchResult] = []
    @State private var loading = false
    @State private var error: String?

    private var scopeOptions: [SearchScope] {
        UnifiedSearch.scopes(for: appState.capabilities)
    }

    private var canSearch: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private var remoteOnly: [SearchResult] {
        UnifiedSearch.remoteNotInLibrary(library: libraryHits, remote: remoteResults)
    }

    private var groupedMovies: [Movie] {
        libraryHits.compactMap { hit in
            if case .movie(let m) = hit { return m }
            return nil
        }
    }

    private var groupedShows: [TVShow] {
        libraryHits.compactMap { hit in
            if case .tv(let s) = hit { return s }
            return nil
        }
    }

    private var groupedOther: [LibrarySearchHit] {
        libraryHits.filter {
            if case .other = $0 { return true }
            return false
        }
    }

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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(scopeOptions) { option in
                        Button {
                            scope = option
                            Task { await runSearch() }
                        } label: {
                            Text(option.label)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(scope == option ? Color.accentColor : Color(.secondarySystemBackground))
                                .foregroundStyle(scope == option ? Color.black : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            if !canSearch {
                Text("Enter at least two characters to search.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else if loading {
                LoadingStateView()
            } else if let error {
                ErrorStateView(message: error)
            } else {
                List {
                    if !groupedMovies.isEmpty {
                        Section("Movies (\(groupedMovies.count))") {
                            ForEach(groupedMovies) { movie in
                                NavigationLink(value: movie) {
                                    Text(movie.title)
                                }
                            }
                        }
                    }
                    if !groupedShows.isEmpty {
                        Section("TV Shows (\(groupedShows.count))") {
                            ForEach(groupedShows) { show in
                                NavigationLink(value: show) {
                                    Text(show.title)
                                }
                            }
                        }
                    }
                    if !groupedOther.isEmpty {
                        Section("Other libraries (\(groupedOther.count))") {
                            ForEach(groupedOther) { hit in
                                if case .other(_, let route, let title, let subtitle, let poster) = hit {
                                    NavigationLink(value: route) {
                                        HStack {
                                            if let poster, !poster.isEmpty {
                                                PosterImage(urlString: poster, cornerRadius: 4)
                                                    .frame(width: 40, height: 60)
                                            }
                                            VStack(alignment: .leading) {
                                                Text(title).font(.subheadline.weight(.semibold))
                                                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if !remoteOnly.isEmpty {
                        Section("Add to your library") {
                            ForEach(remoteOnly, id: \.stableKey) { row in
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
                    if canSearch && libraryHits.isEmpty && remoteOnly.isEmpty {
                        Text("No matches for “\(query)” in \(scope.label).")
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search")
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            libraryHits = []
            remoteResults = []
            error = nil
            return
        }
        loading = true
        error = nil
        do {
            let result = try await UnifiedSearch.run(
                api: appState.api,
                caps: appState.capabilities,
                query: trimmed,
                scope: scope
            )
            libraryHits = result.library
            remoteResults = result.remote
        } catch {
            self.error = error.localizedDescription
            libraryHits = []
            remoteResults = []
        }
        loading = false
    }
}
