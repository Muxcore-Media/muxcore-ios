import Foundation

enum NextUpResolver {
    static func resolve(
        userdata: UserDataStore,
        fetchShow: (String) async throws -> TVShow,
        limit: Int = 12
    ) async -> [NextUpEntry] {
        let progress = userdata.listProgress()
        let continueIds = Set(userdata.continueWatching(limit: 100).map(\.id))
        var out: [NextUpEntry] = []
        var seen = Set<String>()
        var showCache: [String: TVShow?] = [:]

        for p in progress {
            if out.count >= limit { break }
            guard p.kind == .episode || p.kind == .tv else { continue }
            let watched = p.watched == true || (p.durationSec > 0 && p.positionSec / p.durationSec >= 0.92)
            guard watched else { continue }
            guard let showId = PlayHref.showIdFromHref(p.href) else { continue }

            let show: TVShow?
            if let cached = showCache[showId] {
                show = cached
            } else {
                do {
                    let fetched = try await fetchShow(showId)
                    showCache[showId] = fetched
                    show = fetched
                } catch {
                    showCache[showId] = nil
                    show = nil
                }
            }
            guard let show else { continue }

            let next: Episode?
            if p.kind == .episode {
                next = nextEpisodeAfter(show: show, episodeId: p.id)
            } else {
                next = flattenEpisodes(show).first { ep in
                    ep.hasFile && !progress.contains { $0.id == ep.id && $0.watched == true }
                }
            }
            guard let next, !seen.contains(next.id) else { continue }
            if continueIds.contains(next.id) { continue }
            seen.insert(next.id)

            let code = String(format: "S%02dE%02d", next.seasonNumber, next.episodeNumber)
            let title = next.title.isEmpty ? "\(show.title) \(code)" : "\(show.title) \(code) · \(next.title)"
            let href = PlayHref.episodePlayer(show: show, episode: next) ?? "/tv/\(show.id)"
            out.append(NextUpEntry(
                id: next.id,
                kind: .episode,
                title: title,
                posterURL: show.posterURL,
                href: href,
                streamURL: next.streamURL,
                subtitle: "Next up",
                showId: show.id
            ))
        }
        return Array(out.prefix(limit))
    }

    private static func flattenEpisodes(_ show: TVShow) -> [Episode] {
        guard let seasons = show.seasons else { return [] }
        return seasons.flatMap(\.episodes).sorted {
            if $0.seasonNumber != $1.seasonNumber { return $0.seasonNumber < $1.seasonNumber }
            return $0.episodeNumber < $1.episodeNumber
        }
    }

    private static func nextEpisodeAfter(show: TVShow, episodeId: String) -> Episode? {
        let eps = flattenEpisodes(show)
        guard let idx = eps.firstIndex(where: { $0.id == episodeId }) else { return nil }
        for i in (idx + 1)..<eps.count where eps[i].hasFile {
            return eps[i]
        }
        return nil
    }
}
