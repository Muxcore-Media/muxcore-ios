import SwiftUI

struct TVShowsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var items: [TVShow] = []
    @State private var loading = true
    @State private var error: String?

    private var watchable: [TVShow] {
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
                    ForEach(watchable) { show in
                        NavigationLink(value: show) {
                            VStack(alignment: .leading, spacing: 6) {
                                PosterImage(urlString: show.posterURL, cornerRadius: 10)
                                    .frame(height: 160)
                                Text(show.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(2)
                                if show.year > 0 {
                                    Text(String(show.year))
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
        .navigationTitle("TV Shows")
        .navigationDestination(for: TVShow.self) { show in
            TVShowDetailView(showID: show.id)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            let list = try await appState.api.listTVShows(page: 1, pageSize: 96)
            items = list.items
        } catch {
            self.error = error.localizedDescription
            items = []
        }
        loading = false
    }
}
