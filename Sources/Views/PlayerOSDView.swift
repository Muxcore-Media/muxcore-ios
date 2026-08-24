import AVKit
import SwiftUI

struct PlayerVideoLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

final class PlayerUIView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct PlayerOSDControls: View {
    @Environment(\.muxTheme) private var theme

    let title: String
    let isPlaying: Bool
    let current: TimeInterval
    let duration: TimeInterval
    let skipIntroSec: Int
    let subtitleTracks: [PlaybackSubtitleTrack]
    let selectedSubtitleID: String?
    let subtitleSize: SubtitlePrefs.TextSize
    let onPlayPause: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onSkipIntro: () -> Void
    let onSelectSubtitle: (PlaybackSubtitleTrack?) -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Done", action: onDone)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Menu {
                    Button("Off") { onSelectSubtitle(nil) }
                    ForEach(subtitleTracks) { track in
                        Button(track.label) { onSelectSubtitle(track) }
                    }
                } label: {
                    Image(systemName: selectedSubtitleID == nil ? "captions.bubble" : "captions.bubble.fill")
                        .font(.title3)
                        .foregroundStyle(theme.textPrimary)
                }
                .accessibilityLabel("Subtitles")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            if skipIntroSec > 0, current < Double(skipIntroSec) {
                Button(action: onSkipIntro) {
                    Label("Skip intro", systemImage: "forward.end.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(theme.accent)
                        .foregroundStyle(Color(hex: 0x0b0c0f))
                        .clipShape(Capsule())
                }
                .padding(.bottom, 12)
            }

            HStack(spacing: 12) {
                Text(formatTime(current))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.textSecondary)
                Slider(
                    value: Binding(
                        get: { duration > 0 ? current / duration : 0 },
                        set: { onSeek($0 * duration) }
                    )
                )
                .tint(theme.accent)
                Text(formatTime(duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 28) {
                Spacer()
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(theme.textPrimary)
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
                Spacer()
            }
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [theme.playerScrim, .clear, theme.playerScrim],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    private func formatTime(_ sec: TimeInterval) -> String {
        guard sec.isFinite, sec >= 0 else { return "0:00" }
        let total = Int(sec.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

struct SubtitleOverlayText: View {
    let text: String
    let size: SubtitlePrefs.TextSize

    var body: some View {
        Text(text)
            .font(font)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 24)
            .padding(.bottom, 96)
            .accessibilityLabel(text)
    }

    private var font: Font {
        switch size {
        case .sm: return .caption
        case .md: return .body
        case .lg: return .title3
        }
    }
}
