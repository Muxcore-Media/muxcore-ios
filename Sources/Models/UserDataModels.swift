import Foundation

enum MediaKind: String, Codable, Hashable {
    case movie
    case tv
    case episode
    case music
    case book
    case other
}

struct ProgressEntry: Codable, Hashable, Identifiable {
    var id: String
    var kind: MediaKind
    var title: String
    var posterURL: String?
    var href: String
    var streamURL: String?
    var positionSec: Double
    var durationSec: Double
    var updatedAt: String
    var watched: Bool?

    enum CodingKeys: String, CodingKey {
        case id, kind, title, href, watched
        case posterURL = "poster_url"
        case streamURL = "stream_url"
        case positionSec
        case durationSec
        case updatedAt
    }
}

struct FavoriteEntry: Codable, Hashable, Identifiable {
    var id: String
    var kind: MediaKind
    var title: String
    var posterURL: String?
    var href: String
    var year: Int?

    enum CodingKeys: String, CodingKey {
        case id, kind, title, href, year
        case posterURL = "poster_url"
    }
}

struct UserPreferences: Codable, Hashable {
    var display: DisplayPrefs
    var home: HomePrefs
    var playback: PlaybackPrefs
    var subtitles: SubtitlePrefs
    var controls: ControlPrefs

    static let defaults = UserPreferences(
        display: DisplayPrefs(theme: .dark, libraryPageSize: 48, showWatchedIndicators: true),
        home: HomePrefs(showContinueWatching: true, showFavorites: true, showRecentRequests: true, showNextUp: true),
        playback: PlaybackPrefs(autoplayNext: false, rememberPosition: true, skipIntroSec: 0),
        subtitles: SubtitlePrefs(enabled: true, language: "eng", textSize: .md),
        controls: ControlPrefs(enableKeyboardShortcuts: true)
    )
}

struct DisplayPrefs: Codable, Hashable {
    enum Theme: String, Codable { case dark, light, system }
    var theme: Theme
    var libraryPageSize: Int
    var showWatchedIndicators: Bool
}

struct HomePrefs: Codable, Hashable {
    var showContinueWatching: Bool
    var showFavorites: Bool
    var showRecentRequests: Bool
    var showNextUp: Bool
}

struct PlaybackPrefs: Codable, Hashable {
    var autoplayNext: Bool
    var rememberPosition: Bool
    var skipIntroSec: Int
}

struct SubtitlePrefs: Codable, Hashable {
    enum TextSize: String, Codable { case sm, md, lg }
    var enabled: Bool
    var language: String
    var textSize: TextSize
}

struct ControlPrefs: Codable, Hashable {
    var enableKeyboardShortcuts: Bool
}

struct Playlist: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var itemIds: [String]
}

struct QueueItem: Codable, Hashable, Identifiable {
    var id: String
    var kind: MediaKind
    var title: String
    var href: String
    var streamURL: String?
    var posterURL: String?

    enum CodingKeys: String, CodingKey {
        case id, kind, title, href
        case streamURL = "stream_url"
        case posterURL = "poster_url"
    }
}

struct NextUpEntry: Identifiable, Hashable {
    var id: String
    var kind: MediaKind
    var title: String
    var posterURL: String?
    var href: String
    var streamURL: String?
    var subtitle: String?
    var showId: String?
}
