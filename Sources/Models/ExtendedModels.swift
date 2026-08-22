import Foundation

struct DiscoverDetail: Identifiable, Hashable {
    var id: Int
    var title: String
    var year: Int
    var overview: String
    var tagline: String?
    var genres: [String]
    var poster: String
    var backdrop: String
    var voteAvg: Double
    var runtime: Int?
    var status: String?
    var mediaType: SearchMediaType
    var trailerYouTubeKey: String?
}

struct MediaRequest: Identifiable, Hashable, Codable {
    var id: String
    var itemType: String
    var itemId: String
    var tmdbId: Int
    var musicbrainzId: String?
    var title: String
    var year: Int
    var poster: String
    var status: String
    var createdAt: String
    var updatedAt: String
}

struct LibraryRow: Identifiable, Hashable {
    var id: String
    var name: String?
    var title: String?
    var path: String?
    var year: Int?
    var posterURL: String?
}

struct LibraryListResponse {
    var items: [LibraryRow]
    var total: Int
    var page: Int
    var pageSize: Int
    var available: Bool
    var comingSoon: Bool
    var message: String?
}

struct TrackLyrics: Hashable {
    var found: Bool
    var text: String
    var title: String?
    var format: String?
}

struct MusicTrack: Identifiable, Hashable {
    var id: String
    var title: String
    var streamURL: String?
}

struct MusicAlbum: Identifiable, Hashable {
    var id: String
    var title: String
    var year: Int?
    var tracks: [MusicTrack]
}

struct MusicArtistDetail {
    var artist: LibraryRow
    var albums: [MusicAlbum]
}

struct BookFile: Identifiable, Hashable {
    var id: String
    var title: String
    var path: String
    var streamURL: String?
}

struct BookItem: Identifiable, Hashable {
    var id: String
    var title: String
    var year: Int?
    var files: [BookFile]
}

struct BookAuthorDetail {
    var author: LibraryRow
    var books: [BookItem]
}

struct LiveTVChannel: Identifiable, Hashable {
    var id: String
    var name: String
    var number: String
    var url: String?
    var category: String?
    var nowPlayingTitle: String?
}

struct LiveTVRecording: Identifiable, Hashable {
    var id: String
    var channelID: String
    var title: String
    var start: String
    var end: String
    var status: String
}

struct LiveTVTimer: Identifiable, Hashable {
    var id: String
    var channelID: String
    var title: String
    var start: String
    var end: String
    var series: Bool
}

struct LiveTVData {
    var channels: [LiveTVChannel]
    var recordings: [LiveTVRecording]
    var timers: [LiveTVTimer]
    var available: Bool
}

struct CollectionSummary: Identifiable, Hashable {
    var id: String
    var name: String
    var movieCount: Int
}

struct PlaybackSubtitleTrack: Identifiable, Hashable {
    var id: String
    var label: String
    var language: String?
    var src: String
    var isDefault: Bool
}
