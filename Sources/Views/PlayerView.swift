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
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var subtitleTracks: [PlaybackSubtitleTrack] = []
    @State private var selectedSubtitleID: String?
    @State private var subtitleCues: [VTTCue] = []
    @State private var subtitleText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let player {
                    PlayerVideoLayer(player: player)
                        .ignoresSafeArea()
                        .onTapGesture { toggleControls() }
                    if let subtitleText, !subtitleText.isEmpty {
                        VStack {
                            Spacer()
                            SubtitleOverlayText(
                                text: subtitleText,
                                size: appState.userdata.preferences.subtitles.textSize
                            )
                        }
                        .allowsHitTesting(false)
                    }
                    if showControls {
                        PlayerOSDControls(
                            title: item.title,
                            isPlaying: isPlaying,
                            current: currentTime,
                            duration: duration,
                            skipIntroSec: appState.userdata.preferences.playback.skipIntroSec,
                            subtitleTracks: subtitleTracks,
                            selectedSubtitleID: selectedSubtitleID,
                            subtitleSize: appState.userdata.preferences.subtitles.textSize,
                            onPlayPause: togglePlayPause,
                            onSeek: seek,
                            onSkipIntro: skipIntro,
                            onSelectSubtitle: { track in Task { await selectSubtitle(track) } },
                            onDone: closePlayer
                        )
                    }
                } else if loading {
                    LoadingStateView()
                } else if let error {
                    ErrorStateView(message: error)
                }
            }
            .navigationBarHidden(true)
            .task { await preparePlayback() }
            .onDisappear { teardownPlayer() }
            .onKeyPress(.space) {
                guard appState.userdata.preferences.controls.enableKeyboardShortcuts else { return .ignored }
                togglePlayPause()
                return .handled
            }
        }
        .preferredColorScheme(ThemeResolver.colorScheme(for: appState.userdata.preferences.display.theme))
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
            isPlaying = true
            avPlayer.play()
            observePlayer(avPlayer, rememberPosition: prefs.playback.rememberPosition)
            subtitleTracks = (try? await appState.api.fetchPlaybackSubtitles(src: item.streamPath)) ?? []
            if prefs.subtitles.enabled {
                if let preferred = subtitleTracks.first(where: {
                    ($0.language ?? "").lowercased() == prefs.subtitles.language.lowercased()
                }) ?? subtitleTracks.first(where: \.isDefault) ?? subtitleTracks.first {
                    await selectSubtitle(preferred)
                }
            }
            scheduleHideControls()
        } catch {
            self.error = error.localizedDescription
            player = nil
        }
        loading = false
    }

    private func observePlayer(_ avPlayer: AVPlayer, rememberPosition: Bool) {
        if let observer = timeObserver {
            avPlayer.removeTimeObserver(observer)
            timeObserver = nil
        }
        timeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { time in
            currentTime = time.seconds
            if let item = avPlayer.currentItem {
                let dur = item.duration.seconds
                if dur.isFinite, dur > 0 {
                    duration = dur
                }
            }
            subtitleText = WebVTTParser.activeCue(at: currentTime, cues: subtitleCues)
            if rememberPosition {
                saveProgress()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
            showControls = true
        }
    }

    private func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        scheduleHideControls()
    }

    private func seek(_ seconds: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(seconds, duration > 0 ? duration : seconds))
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
        scheduleHideControls()
    }

    private func skipIntro() {
        let target = Double(appState.userdata.preferences.playback.skipIntroSec)
        seek(target)
    }

    private func selectSubtitle(_ track: PlaybackSubtitleTrack?) async {
        selectedSubtitleID = track?.id
        subtitleCues = []
        subtitleText = nil
        guard let track, let url = appState.api.absoluteURL(path: track.src) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let content = String(decoding: data, as: UTF8.self)
            subtitleCues = WebVTTParser.parse(content)
            subtitleText = WebVTTParser.activeCue(at: currentTime, cues: subtitleCues)
        } catch {
            subtitleCues = []
        }
    }

    private func toggleControls() {
        showControls.toggle()
        if showControls {
            scheduleHideControls()
        } else {
            hideControlsTask?.cancel()
        }
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled, isPlaying else { return }
            await MainActor.run { showControls = false }
        }
    }

    private func closePlayer() {
        saveProgress()
        dismiss()
    }

    private func teardownPlayer() {
        hideControlsTask?.cancel()
        saveProgress()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
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
