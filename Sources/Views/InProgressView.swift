import SwiftUI

struct InProgressView: View {
    @EnvironmentObject private var appState: AppState
    @State private var entries: [AcquisitionHelpers.InProgressEntry] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            if loading { LoadingStateView() }
            else if let error { ErrorStateView(message: error) }
            else if entries.isEmpty {
                ContentUnavailableView("Nothing in progress", systemImage: "clock", description: Text("Search to add titles."))
            } else {
                let grouped = AcquisitionHelpers.groupByPhase(entries)
                VStack(alignment: .leading, spacing: 24) {
                    phaseSection("Downloading", entries: grouped.downloading)
                    phaseSection("Searching", entries: grouped.searching)
                    phaseSection("Requested", entries: grouped.requested)
                }
                .padding()
            }
        }
        .navigationTitle("In progress")
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func phaseSection(_ title: String, entries: [AcquisitionHelpers.InProgressEntry]) -> some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(title) (\(entries.count))")
                    .font(.headline)
                ForEach(entries) { entry in
                    NavigationLink(value: route(for: entry)) {
                        InProgressRow(entry: entry)
                    }
                }
            }
        }
    }

    private func route(for entry: AcquisitionHelpers.InProgressEntry) -> AppRoute {
        switch entry {
        case .request(let r):
            if r.itemType == "tv" { return .tvShow(r.itemId) }
            return .movie(r.itemId)
        case .libraryMovie(let m): return .movie(m.id)
        case .libraryTV(let s): return .tvShow(s.id)
        }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            async let requests = appState.api.listRequests()
            async let movies = appState.api.listMovies(page: 1, pageSize: 200)
            async let shows = appState.api.listTVShows(page: 1, pageSize: 200)
            let (r, m, t) = try await (requests, movies, shows)
            entries = AcquisitionHelpers.mergeInProgress(requests: r, movies: m.items, shows: t.items)
        } catch {
            self.error = error.localizedDescription
            entries = []
        }
        loading = false
    }
}

private struct InProgressRow: View {
    @EnvironmentObject private var appState: AppState
    let entry: AcquisitionHelpers.InProgressEntry

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(urlString: poster, cornerRadius: 6)
                .frame(width: 48, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var title: String {
        switch entry {
        case .request(let r): return r.title
        case .libraryMovie(let m): return m.title
        case .libraryTV(let s): return s.title
        }
    }

    private var status: String {
        switch entry {
        case .request(let r): return AcquisitionHelpers.requestStatusLabel(r.status)
        case .libraryMovie, .libraryTV: return "In library"
        }
    }

    private var poster: String {
        switch entry {
        case .request(let r):
            return AcquisitionHelpers.posterURLForRequest(r.poster, serverBase: appState.api.currentServerBase())
        case .libraryMovie(let m): return m.posterURL
        case .libraryTV(let s): return s.posterURL
        }
    }
}
