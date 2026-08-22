import SwiftUI

struct MusicView: View {
    @EnvironmentObject private var appState: AppState
    @State private var items: [LibraryRow] = []
    @State private var loading = true
    @State private var error: String?
    @State private var available = true

    var body: some View {
        Group {
            if loading { LoadingStateView() }
            else if let error { ErrorStateView(message: error) }
            else if !available {
                ContentUnavailableView("Coming soon", systemImage: "music.note")
            } else {
                List(items) { artist in
                    NavigationLink(value: AppRoute.musicArtist(artist.id)) {
                        Text(artist.name ?? artist.title ?? artist.id)
                    }
                }
            }
        }
        .navigationTitle("Music")
        .task { await load() }
    }

    private func load() async {
        loading = true
        do {
            let list = try await appState.api.listMusic()
            items = list.items
            available = list.available
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct MusicArtistView: View {
    @EnvironmentObject private var appState: AppState
    let artistID: String
    @State private var detail: MusicArtistDetail?
    @State private var loading = true
    @State private var playerItem: PlayerItem?

    var body: some View {
        ScrollView {
            if loading { LoadingStateView() }
            else if let detail {
                VStack(alignment: .leading, spacing: 16) {
                    Text(detail.artist.name ?? "Artist").font(.title2.bold())
                    ForEach(detail.albums) { album in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(album.title).font(.headline)
                            ForEach(album.tracks) { track in
                                HStack {
                                    Text(track.title)
                                    Spacer()
                                    if let stream = track.streamURL {
                                        Button {
                                            playerItem = PlayerItem(id: track.id, title: track.title, streamPath: stream, posterURL: nil, kind: "music")
                                        } label: {
                                            Image(systemName: "play.circle")
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
        .navigationTitle(detail?.artist.name ?? "Music")
        .fullScreenCover(item: $playerItem) { PlayerView(item: $0) }
        .task {
            do { detail = try await appState.api.getMusicArtist(id: artistID) }
            catch {}
            loading = false
        }
    }
}

struct BookAuthorView: View {
    @EnvironmentObject private var appState: AppState
    let authorID: String
    @State private var detail: BookAuthorDetail?
    @State private var loading = true
    @State private var playerItem: PlayerItem?

    var body: some View {
        ScrollView {
            if loading { LoadingStateView() }
            else if let detail {
                VStack(alignment: .leading, spacing: 16) {
                    Text(detail.author.name ?? "Author").font(.title2.bold())
                    ForEach(detail.books) { book in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title).font(.headline)
                            ForEach(book.files) { file in
                                HStack {
                                    Text(file.title)
                                    Spacer()
                                    if let stream = file.streamURL {
                                        Button {
                                            playerItem = PlayerItem(id: file.id, title: file.title, streamPath: stream, posterURL: nil, kind: "book")
                                        } label: {
                                            Image(systemName: "play.circle")
                                        }
                                    }
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(detail?.author.name ?? "Books")
        .fullScreenCover(item: $playerItem) { PlayerView(item: $0) }
        .task {
            do { detail = try await appState.api.getBookAuthor(id: authorID) }
            catch {}
            loading = false
        }
    }
}
