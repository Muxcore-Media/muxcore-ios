import Foundation

enum PlayHref {
    static func moviePlayer(movie: Movie) -> String? {
        guard movie.hasFile, !movie.streamURL.isEmpty else { return nil }
        return build(src: movie.streamURL, title: movie.title, id: movie.id, kind: "movie", poster: movie.posterURL, back: "/movies/\(movie.id)")
    }

    static func episodePlayer(show: TVShow, episode: Episode) -> String? {
        guard episode.hasFile, !episode.streamURL.isEmpty else { return nil }
        let code = String(format: "S%02dE%02d", episode.seasonNumber, episode.episodeNumber)
        let epTitle = episode.title.isEmpty ? "\(show.title) \(code)" : "\(show.title) \(code) · \(episode.title)"
        return build(
            src: episode.streamURL,
            title: epTitle,
            id: episode.id,
            kind: "episode",
            poster: show.posterURL,
            back: "/tv/\(show.id)",
            showId: show.id,
            season: episode.seasonNumber,
            episode: episode.episodeNumber
        )
    }

    static func progressPlayer(_ entry: ProgressEntry) -> String? {
        guard let stream = entry.streamURL, !stream.isEmpty else { return nil }
        let showId = showIdFromHref(entry.href)
        return build(
            src: stream,
            title: entry.title,
            id: entry.id,
            kind: entry.kind.rawValue,
            poster: entry.posterURL,
            back: entry.href,
            showId: showId
        )
    }

    static func showIdFromHref(_ href: String) -> String? {
        guard let range = href.range(of: #"/tv/([^/?#]+)"#, options: .regularExpression) else { return nil }
        let match = String(href[range])
        return match.replacingOccurrences(of: "/tv/", with: "").components(separatedBy: "/").first
    }

    private static func build(
        src: String,
        title: String,
        id: String,
        kind: String,
        poster: String? = nil,
        back: String? = nil,
        showId: String? = nil,
        season: Int? = nil,
        episode: Int? = nil
    ) -> String {
        var parts = [
            "src=\(src)",
            "title=\(title)",
            "id=\(id)",
            "kind=\(kind)",
        ]
        if let poster { parts.append("poster=\(poster)") }
        if let back { parts.append("back=\(back)") }
        if let showId { parts.append("showId=\(showId)") }
        if let season { parts.append("season=\(season)") }
        if let episode { parts.append("episode=\(episode)") }
        return "/player?\(parts.joined(separator: "&"))"
    }
}
