import SwiftUI

struct DiscoverDetailView: View {
    @EnvironmentObject private var appState: AppState
    let mediaType: SearchMediaType
    let tmdbID: Int

    @State private var detail: DiscoverDetail?
    @State private var loading = true
    @State private var error: String?
    @State private var requested: String?

    var body: some View {
        ScrollView {
            if loading { LoadingStateView() }
            else if let error { ErrorStateView(message: error) }
            else if let detail {
                VStack(alignment: .leading, spacing: 16) {
                    if !detail.backdrop.isEmpty {
                        PosterImage(urlString: tmdbImage(detail.backdrop, size: "w780"), cornerRadius: 12)
                            .frame(height: 180)
                    }
                    Text(detail.title).font(.title2.bold())
                    if detail.year > 0 { Text(String(detail.year)).foregroundStyle(.secondary) }
                    if !detail.genres.isEmpty {
                        Text(detail.genres.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                    }
                    if !detail.overview.isEmpty { Text(detail.overview) }
                    Button("Request title") { Task { await request() } }
                        .buttonStyle(.borderedProminent)
                    if let requested {
                        Text("Status: \(requested)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(detail?.title ?? "Discover")
        .task { await load() }
    }

    private func load() async {
        loading = true
        do {
            detail = try await appState.api.getDiscoverDetail(type: mediaType, id: tmdbID)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func request() async {
        guard let detail else { return }
        do {
            let res = try await appState.api.requestTitle(
                tmdbId: detail.id,
                title: detail.title,
                year: detail.year,
                overview: detail.overview,
                poster: detail.poster,
                mediaType: detail.mediaType
            )
            requested = JSONHelpers.string(res, keys: ["status"])
        } catch {
            requested = (error as? LocalizedError)?.errorDescription ?? "Request failed"
        }
    }

    private func tmdbImage(_ path: String, size: String) -> String {
        if path.hasPrefix("http") { return path }
        if path.hasPrefix("/") { return "https://image.tmdb.org/t/p/\(size)\(path)" }
        return path
    }
}
