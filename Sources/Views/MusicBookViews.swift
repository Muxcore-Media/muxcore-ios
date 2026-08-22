import AVKit
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
    @State private var playingTrackID: String?
    @State private var lyrics: TrackLyrics?
    @State private var lyricsLoading = false

    var body: some View {
        ScrollView {
            if loading { LoadingStateView() }
            else if let detail {
                VStack(alignment: .leading, spacing: 16) {
                    Text(detail.artist.name ?? "Artist").font(.title2.bold())
                    ForEach(detail.albums) { album in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(album.title).font(.headline)
                                if let year = album.year {
                                    Text(String(year)).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            ForEach(album.tracks) { track in
                                trackRow(track, album: album)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(detail?.artist.name ?? "Music")
        .task {
            do { detail = try await appState.api.getMusicArtist(id: artistID) }
            catch {}
            loading = false
        }
        .onChange(of: playingTrackID) { _, newID in
            Task { await loadLyrics(for: newID) }
        }
    }

    @ViewBuilder
    private func trackRow(_ track: MusicTrack, album: MusicAlbum) -> some View {
        let isPlaying = playingTrackID == track.id
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(track.title)
                Spacer()
                if let stream = track.streamURL {
                    Button {
                        playingTrackID = isPlaying ? nil : track.id
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                    }
                } else {
                    Text("Unavailable").font(.caption).foregroundStyle(.secondary)
                }
            }
            if isPlaying {
                if let stream = track.streamURL, let url = appState.api.absoluteURL(path: stream) {
                    InlineAudioPlayer(url: url)
                } else {
                    Text("This track isn't available to play yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                lyricsPanel(for: track)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func lyricsPanel(for track: MusicTrack) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LYRICS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if lyricsLoading {
                ProgressView()
            } else if let lyrics, lyrics.found, !lyrics.text.isEmpty {
                ScrollView {
                    Text(lyrics.text)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            } else {
                Text("Lyrics aren't available for this track yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadLyrics(for trackID: String?) async {
        guard let trackID else {
            lyrics = nil
            lyricsLoading = false
            return
        }
        lyricsLoading = true
        lyrics = nil
        do {
            lyrics = try await appState.api.getTrackLyrics(trackId: trackID)
        } catch {
            lyrics = TrackLyrics(found: false, text: "", title: nil, format: nil)
        }
        lyricsLoading = false
    }
}

private struct InlineAudioPlayer: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onAppear {
                let avPlayer = AVPlayer(url: url)
                player = avPlayer
                avPlayer.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
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
