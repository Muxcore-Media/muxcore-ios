import Foundation

struct Movie: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var year: Int
    var overview: String
    var runtime: Int
    var voteAverage: Double
    var genres: [String]
    var posterURL: String
    var hasFile: Bool
    var streamURL: String
    var createdAt: String
    var tmdbID: Int?
    var backdropURL: String?
    var tagline: String?
    var status: String?
    var collectionID: Int?
    var collectionName: String?
}

struct Episode: Identifiable, Hashable, Codable {
    var id: String
    var seasonNumber: Int
    var episodeNumber: Int
    var title: String
    var overview: String
    var runtime: Int
    var hasFile: Bool
    var streamURL: String
    var airDate: String?
}

struct Season: Identifiable, Hashable, Codable {
    var id: String
    var seasonNumber: Int
    var name: String
    var episodeCount: Int
    var posterURL: String
    var episodes: [Episode]
}

struct TVShow: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var year: Int
    var overview: String
    var voteAverage: Double
    var genres: [String]
    var posterURL: String
    var hasFile: Bool
    var streamURL: String
    var createdAt: String
    var tmdbID: Int?
    var backdropURL: String?
    var status: String?
    var seasons: [Season]?
}

struct ListResponse<T: Codable>: Codable {
    var items: [T]
    var total: Int
    var page: Int
    var pageSize: Int
}

struct SearchResult: Identifiable, Hashable, Codable {
    var id: Int
    var title: String
    var year: Int
    var overview: String
    var poster: String
    var voteAvg: Double
    var mediaType: SearchMediaType
    var musicbrainzID: String?
    var releaseGroupID: String?
    var recordingID: String?
    var artistName: String?
    var albumTitle: String?

    var stableKey: String {
        switch mediaType {
        case .musicTrack:
            return "music_track:\(recordingID ?? title.lowercased())"
        case .musicAlbum:
            return "music_album:\(releaseGroupID ?? title.lowercased())"
        case .music:
            return "music:\(musicbrainzID ?? title.lowercased())"
        case .movie, .tv:
            return "\(mediaType.rawValue):\(id)"
        }
    }
}

enum SearchMediaType: String, Codable, Hashable {
    case movie
    case tv
    case music
    case musicAlbum = "music_album"
    case musicTrack = "music_track"
}

struct Capabilities: Codable, Hashable {
    var libraries: [String: Bool]
    var features: [String: Bool]

    static let defaults = Capabilities(
        libraries: [
            "movies": true,
            "tv": true,
            "music": false,
            "books": false,
            "comics": false,
            "audiobooks": false,
            "homevideos": false,
            "musicvideos": false,
        ],
        features: [
            "search": true,
            "request": true,
            "collections": true,
            "studios": true,
            "upcoming": true,
            "mixed": true,
            "livetv": true,
            "quickconnect": true,
            "playlists": true,
            "queue": true,
            "favorites": true,
        ]
    )

    func featureEnabled(_ key: String) -> Bool {
        features[key] ?? Capabilities.defaults.features[key] ?? false
    }

    func libraryEnabled(_ key: String) -> Bool {
        libraries[key] ?? Capabilities.defaults.libraries[key] ?? false
    }
}

struct PlaybackResolve: Codable, Hashable {
    var streamURL: String
    var mode: String
    var resumeEnabled: Bool
    var transcoderEnabled: Bool
    var preferDirectPlay: Bool
    var maxBitrateMbps: String
    var trickplayEnabled: Bool
    var transcoderAvailable: Bool
}

struct PlayerItem: Identifiable, Hashable {
    let id: String
    let title: String
    let streamPath: String
    let posterURL: String?
    let kind: String
}
