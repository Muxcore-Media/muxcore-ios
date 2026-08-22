import AVKit
import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let item: PlayerItem

    @State private var player: AVPlayer?
    @State private var loading = true
    @State private var error: String?
    @State private var timeObserver: Any?

    var body: some View {
        NavigationStack {
            ZStack {
                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                } else if loading {
                    LoadingStateView()
                } else if let error {
                    ErrorStateView(message: error)
                }
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        saveProgress()
                        dismiss()
                    }
                }
            }
            .task { await preparePlayback() }
            .onDisappear {
                saveProgress()
                if let observer = timeObserver { player?.removeTimeObserver(observer) }
                player?.pause()
                player = nil
            }
        }
    }

    private func preparePlayback() async {
        loading = true
        error = nil
        do {
            let resolve = try await appState.api.resolvePlayback(src: item.streamPath)
            let streamPath = resolve.streamURL.isEmpty ? item.streamPath : resolve.streamURL
            guard let url = appState.api.absoluteURL(path: streamPath) else {
                throw APIError.badResponse("Invalid stream URL")
            }
            let avPlayer = AVPlayer(url: url)
            let prefs = await appState.userdata.preferences
            if prefs.playback.rememberPosition, let prog = await appState.userdata.getProgress(id: item.id) {
                let seek = prog.positionSec + Double(prefs.playback.skipIntroSec)
                if seek > 0 && prog.watched != true {
                    await avPlayer.seek(to: CMTime(seconds: seek, preferredTimescale: 600))
                }
            } else if prefs.playback.skipIntroSec > 0 {
                await avPlayer.seek(to: CMTime(seconds: Double(prefs.playback.skipIntroSec), preferredTimescale: 600))
            }
            player = avPlayer
            avPlayer.play()
            if prefs.playback.rememberPosition {
                timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 600), queue: .main) { _ in
                    saveProgress()
                }
            }
        } catch {
            self.error = error.localizedDescription
            player = nil
        }
        loading = false
    }

    private func saveProgress() {
        guard appState.userdata.preferences.playback.rememberPosition,
              let player,
              let current = player.currentItem
        else { return }
        let pos = player.currentTime().seconds
        let dur = current.duration.seconds
        guard pos.isFinite && dur.isFinite && dur > 0 else { return }
        appState.userdata.upsertProgress(ProgressEntry(
            id: item.id,
            kind: MediaKind(rawValue: item.kind) ?? .movie,
            title: item.title,
            posterURL: item.posterURL,
            href: backHref(),
            streamURL: item.streamPath,
            positionSec: pos,
            durationSec: dur,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        ))
    }

    private func backHref() -> String {
        switch item.kind {
        case "episode": return "/tv/"
        case "tv": return "/tv/\(item.id)"
        default: return "/movies/\(item.id)"
        }
    }
}
