import Foundation

enum MediaNormalizer {
    static func movie(from raw: [String: Any], serverBase: URL?) -> Movie {
        let id = JSONHelpers.string(raw, keys: ["id", "movieId"])
        let poster = JSONHelpers.string(raw, keys: ["poster_url", "posterUrl", "poster", "poster_path", "posterPath"])
        let stream = JSONHelpers.string(raw, keys: ["stream_url", "streamUrl"])
        let resolvedStream = stream.isEmpty && !id.isEmpty ? "/stream/movies/\(id)" : stream
        return Movie(
            id: id,
            title: JSONHelpers.string(raw, keys: ["title"]),
            year: JSONHelpers.int(raw, keys: ["year"]),
            overview: JSONHelpers.string(raw, keys: ["overview"]),
            runtime: JSONHelpers.int(raw, keys: ["runtime"]),
            voteAverage: JSONHelpers.double(raw, keys: ["vote_average", "voteAverage", "voteAvg"]),
            genres: JSONHelpers.genres(raw),
            posterURL: PosterURL.resolve(poster, kind: .movie, serverBase: serverBase),
            hasFile: JSONHelpers.bool(raw, keys: ["has_file", "hasFile"]),
            streamURL: resolvedStream,
            createdAt: JSONHelpers.string(raw, keys: ["created_at", "createdAt"]),
            tmdbID: JSONHelpers.optionalInt(raw, keys: ["tmdb_id", "tmdbId"]),
            backdropURL: PosterURL.resolve(
                JSONHelpers.string(raw, keys: ["backdrop_url", "backdropUrl", "backdrop_path"]),
                kind: .movie,
                serverBase: serverBase
            ),
            tagline: JSONHelpers.string(raw, keys: ["tagline"]).isEmpty ? nil : JSONHelpers.string(raw, keys: ["tagline"]),
            status: JSONHelpers.string(raw, keys: ["status"]).isEmpty ? nil : JSONHelpers.string(raw, keys: ["status"]),
            collectionID: JSONHelpers.optionalInt(raw, keys: ["collection_id", "collectionId"]),
            collectionName: JSONHelpers.string(raw, keys: ["collection_name", "collectionName"]).isEmpty
                ? nil
                : JSONHelpers.string(raw, keys: ["collection_name", "collectionName"])
        )
    }

    static func episode(from raw: [String: Any], serverBase: URL?) -> Episode {
        let id = JSONHelpers.string(raw, keys: ["id"])
        let hasFile = JSONHelpers.bool(raw, keys: ["has_file", "hasFile"])
        let stream = JSONHelpers.string(raw, keys: ["stream_url", "streamUrl"])
        let resolvedStream = stream.isEmpty && hasFile && !id.isEmpty ? "/stream/tv/\(id)" : stream
        let air = JSONHelpers.string(raw, keys: ["air_date", "airDate"])
        return Episode(
            id: id,
            seasonNumber: JSONHelpers.int(raw, keys: ["season_number", "seasonNumber"]),
            episodeNumber: JSONHelpers.int(raw, keys: ["episode_number", "episodeNumber"]),
            title: JSONHelpers.string(raw, keys: ["title", "name"]),
            overview: JSONHelpers.string(raw, keys: ["overview"]),
            runtime: JSONHelpers.int(raw, keys: ["runtime"]),
            hasFile: hasFile,
            streamURL: resolvedStream,
            airDate: air.isEmpty ? nil : air
        )
    }

    static func season(from raw: [String: Any], serverBase: URL?) -> Season {
        let episodes = JSONHelpers.dictArray(raw["episodes"]).map { episode(from: $0, serverBase: serverBase) }
        return Season(
            id: JSONHelpers.string(raw, keys: ["id"]),
            seasonNumber: JSONHelpers.int(raw, keys: ["season_number", "seasonNumber"]),
            name: JSONHelpers.string(raw, keys: ["name"]),
            episodeCount: JSONHelpers.int(raw, keys: ["episode_count", "episodeCount"]),
            posterURL: PosterURL.resolve(
                JSONHelpers.string(raw, keys: ["poster_url", "posterUrl", "poster_path"]),
                kind: .tv,
                serverBase: serverBase
            ),
            episodes: episodes
        )
    }

    static func tvShow(from raw: [String: Any], serverBase: URL?) -> TVShow {
        let id = JSONHelpers.string(raw, keys: ["id", "seriesId"])
        let poster = JSONHelpers.string(raw, keys: ["poster_url", "posterUrl", "poster", "poster_path", "posterPath"])
        let seasons = JSONHelpers.dictArray(raw["seasons"]).map { season(from: $0, serverBase: serverBase) }
        let hasFileFromSeasons = seasons.contains { season in
            season.episodes.contains { $0.hasFile }
        }
        let hasFile = JSONHelpers.bool(raw, keys: ["has_file", "hasFile"]) || hasFileFromSeasons
        var streamURL = JSONHelpers.string(raw, keys: ["stream_url", "streamUrl"])
        if streamURL.isEmpty {
            streamURL = seasons
                .flatMap(\.episodes)
                .first(where: { $0.hasFile })?
                .streamURL ?? ""
        }
        return TVShow(
            id: id,
            title: JSONHelpers.string(raw, keys: ["title", "name"]),
            year: JSONHelpers.int(raw, keys: ["year"]),
            overview: JSONHelpers.string(raw, keys: ["overview"]),
            voteAverage: JSONHelpers.double(raw, keys: ["vote_average", "voteAverage", "voteAvg"]),
            genres: JSONHelpers.genres(raw),
            posterURL: PosterURL.resolve(poster, kind: .tv, serverBase: serverBase),
            hasFile: hasFile,
            streamURL: streamURL,
            createdAt: JSONHelpers.string(raw, keys: ["created_at", "createdAt"]),
            tmdbID: JSONHelpers.optionalInt(raw, keys: ["tmdb_id", "tmdbId"]),
            backdropURL: PosterURL.resolve(
                JSONHelpers.string(raw, keys: ["backdrop_url", "backdropUrl", "backdrop_path"]),
                kind: .tv,
                serverBase: serverBase
            ),
            status: JSONHelpers.string(raw, keys: ["status"]).isEmpty ? nil : JSONHelpers.string(raw, keys: ["status"]),
            seasons: seasons.isEmpty ? nil : seasons
        )
    }

    static func listMovies(from data: Any, serverBase: URL?) -> ListResponse<Movie> {
        if let array = data as? [Any] {
            let items = array.compactMap { item -> Movie? in
                guard let dict = item as? [String: Any] else { return nil }
                return movie(from: dict, serverBase: serverBase)
            }
            return ListResponse(items: items, total: items.count, page: 1, pageSize: items.count)
        }
        let dict = JSONHelpers.asDict(data)
        let rows = JSONHelpers.dictArray(dict["items"] ?? dict["results"] ?? dict["movies"])
        let items = rows.map { movie(from: $0, serverBase: serverBase) }
        return ListResponse(
            items: items,
            total: JSONHelpers.int(dict, keys: ["total"]).nonzeroOr(items.count),
            page: JSONHelpers.int(dict, keys: ["page"]).nonzeroOr(1),
            pageSize: JSONHelpers.int(dict, keys: ["page_size", "pageSize"]).nonzeroOr(items.count)
        )
    }

    static func listTV(from data: Any, serverBase: URL?) -> ListResponse<TVShow> {
        if let array = data as? [Any] {
            let items = array.compactMap { item -> TVShow? in
                guard let dict = item as? [String: Any] else { return nil }
                return tvShow(from: dict, serverBase: serverBase)
            }
            return ListResponse(items: items, total: items.count, page: 1, pageSize: items.count)
        }
        let dict = JSONHelpers.asDict(data)
        let rows = JSONHelpers.dictArray(dict["items"] ?? dict["results"] ?? dict["shows"])
        let items = rows.map { tvShow(from: $0, serverBase: serverBase) }
        return ListResponse(
            items: items,
            total: JSONHelpers.int(dict, keys: ["total"]).nonzeroOr(items.count),
            page: JSONHelpers.int(dict, keys: ["page"]).nonzeroOr(1),
            pageSize: JSONHelpers.int(dict, keys: ["page_size", "pageSize"]).nonzeroOr(items.count)
        )
    }

    static func searchResult(from raw: [String: Any]) -> SearchResult? {
        let mediaTypeRaw = JSONHelpers.string(raw, keys: ["mediaType", "media_type"])
        let mediaType = SearchMediaType(rawValue: mediaTypeRaw) ?? .movie
        return SearchResult(
            id: JSONHelpers.int(raw, keys: ["id"]),
            title: JSONHelpers.string(raw, keys: ["title"]),
            year: JSONHelpers.int(raw, keys: ["year"]),
            overview: JSONHelpers.string(raw, keys: ["overview"]),
            poster: JSONHelpers.string(raw, keys: ["poster"]),
            voteAvg: JSONHelpers.double(raw, keys: ["voteAvg", "vote_average", "voteAverage"]),
            mediaType: mediaType == .movie || mediaType == .tv ? mediaType : mediaType,
            musicbrainzID: JSONHelpers.string(raw, keys: ["musicbrainzId", "musicbrainz_id"]).isEmpty
                ? nil
                : JSONHelpers.string(raw, keys: ["musicbrainzId", "musicbrainz_id"]),
            releaseGroupID: JSONHelpers.string(raw, keys: ["releaseGroupId", "release_group_id"]).isEmpty
                ? nil
                : JSONHelpers.string(raw, keys: ["releaseGroupId", "release_group_id"]),
            recordingID: JSONHelpers.string(raw, keys: ["recordingId", "recording_id"]).isEmpty
                ? nil
                : JSONHelpers.string(raw, keys: ["recordingId", "recording_id"]),
            artistName: JSONHelpers.string(raw, keys: ["artistName", "artist_name"]).isEmpty
                ? nil
                : JSONHelpers.string(raw, keys: ["artistName", "artist_name"]),
            albumTitle: JSONHelpers.string(raw, keys: ["albumTitle", "album_title"]).isEmpty
                ? nil
                : JSONHelpers.string(raw, keys: ["albumTitle", "album_title"])
        )
    }

    static func capabilities(from raw: [String: Any]) -> Capabilities {
        var caps = Capabilities.defaults
        if let libraries = raw["libraries"] as? [String: Bool] {
            for (key, value) in libraries {
                caps.libraries[key] = value
            }
        }
        if let features = raw["features"] as? [String: Bool] {
            for (key, value) in features {
                caps.features[key] = value
            }
        }
        return caps
    }

    static func playbackResolve(from raw: [String: Any]) -> PlaybackResolve {
        PlaybackResolve(
            streamURL: JSONHelpers.string(raw, keys: ["stream_url", "streamUrl"]),
            mode: JSONHelpers.string(raw, keys: ["mode"]),
            resumeEnabled: JSONHelpers.bool(raw, keys: ["resume_enabled", "resumeEnabled"]),
            transcoderEnabled: JSONHelpers.bool(raw, keys: ["transcoder_enabled", "transcoderEnabled"]),
            preferDirectPlay: JSONHelpers.bool(raw, keys: ["prefer_direct_play", "preferDirectPlay"]),
            maxBitrateMbps: JSONHelpers.string(raw, keys: ["max_bitrate_mbps", "maxBitrateMbps"]),
            trickplayEnabled: JSONHelpers.bool(raw, keys: ["trickplay_enabled", "trickplayEnabled"]),
            transcoderAvailable: JSONHelpers.bool(raw, keys: ["transcoder_available", "transcoderAvailable"])
        )
    }

    static func discoverDetail(from raw: [String: Any]) -> DiscoverDetail {
        let mediaRaw = JSONHelpers.string(raw, keys: ["mediaType", "media_type"])
        let mediaType: SearchMediaType = mediaRaw == "tv" ? .tv : .movie
        var trailerKey: String? = nil
        if let trailer = raw["trailer"] as? [String: Any] {
            let key = JSONHelpers.string(trailer, keys: ["youtubeKey", "youtube_key"])
            trailerKey = key.isEmpty ? nil : key
        }
        return DiscoverDetail(
            id: JSONHelpers.int(raw, keys: ["id"]),
            title: JSONHelpers.string(raw, keys: ["title"]),
            year: JSONHelpers.int(raw, keys: ["year"]),
            overview: JSONHelpers.string(raw, keys: ["overview"]),
            tagline: JSONHelpers.string(raw, keys: ["tagline"]).isEmpty ? nil : JSONHelpers.string(raw, keys: ["tagline"]),
            genres: JSONHelpers.genres(raw),
            poster: JSONHelpers.string(raw, keys: ["poster"]),
            backdrop: JSONHelpers.string(raw, keys: ["backdrop"]),
            voteAvg: JSONHelpers.double(raw, keys: ["voteAvg", "vote_average", "voteAverage"]),
            runtime: JSONHelpers.optionalInt(raw, keys: ["runtime"]),
            status: JSONHelpers.string(raw, keys: ["status"]).isEmpty ? nil : JSONHelpers.string(raw, keys: ["status"]),
            mediaType: mediaType,
            trailerYouTubeKey: trailerKey
        )
    }

    static func mediaRequest(from raw: [String: Any]) -> MediaRequest {
        MediaRequest(
            id: JSONHelpers.string(raw, keys: ["id"]),
            itemType: JSONHelpers.string(raw, keys: ["itemType", "item_type"]),
            itemId: JSONHelpers.string(raw, keys: ["itemId", "item_id"]),
            tmdbId: JSONHelpers.int(raw, keys: ["tmdbId", "tmdb_id"]),
            musicbrainzId: JSONHelpers.string(raw, keys: ["musicbrainzId", "musicbrainz_id"]).isEmpty
                ? nil
                : JSONHelpers.string(raw, keys: ["musicbrainzId", "musicbrainz_id"]),
            title: JSONHelpers.string(raw, keys: ["title"]),
            year: JSONHelpers.int(raw, keys: ["year"]),
            poster: JSONHelpers.string(raw, keys: ["poster"]),
            status: JSONHelpers.string(raw, keys: ["status"]),
            createdAt: JSONHelpers.string(raw, keys: ["createdAt", "created_at"]),
            updatedAt: JSONHelpers.string(raw, keys: ["updatedAt", "updated_at"])
        )
    }

    static func libraryList(from raw: [String: Any]) -> LibraryListResponse {
        let rows = JSONHelpers.dictArray(raw["items"])
        let items = rows.map { row -> LibraryRow in
            let poster = JSONHelpers.string(row, keys: ["poster_url", "posterURL", "poster"])
            LibraryRow(
                id: JSONHelpers.string(row, keys: ["id", "name", "title"]),
                name: JSONHelpers.string(row, keys: ["name"]).isEmpty ? nil : JSONHelpers.string(row, keys: ["name"]),
                title: JSONHelpers.string(row, keys: ["title"]).isEmpty ? nil : JSONHelpers.string(row, keys: ["title"]),
                path: JSONHelpers.string(row, keys: ["path"]).isEmpty ? nil : JSONHelpers.string(row, keys: ["path"]),
                year: JSONHelpers.optionalInt(row, keys: ["year"]),
                posterURL: poster.isEmpty ? nil : poster
            )
        }
        return LibraryListResponse(
            items: items,
            total: JSONHelpers.int(raw, keys: ["total"]).nonzeroOr(items.count),
            page: JSONHelpers.int(raw, keys: ["page"]).nonzeroOr(1),
            pageSize: JSONHelpers.int(raw, keys: ["page_size", "pageSize"]).nonzeroOr(items.count),
            available: raw["available"] as? Bool ?? true,
            comingSoon: JSONHelpers.bool(raw, keys: ["coming_soon", "comingSoon"]) || raw["available"] as? Bool == false,
            message: JSONHelpers.string(raw, keys: ["message"]).isEmpty ? nil : JSONHelpers.string(raw, keys: ["message"])
        )
    }

    static func musicArtist(from raw: [String: Any], serverBase: URL?) -> MusicArtistDetail {
        let artistRaw = JSONHelpers.asDict(raw["artist"] ?? raw)
        let artist = LibraryRow(
            id: JSONHelpers.string(artistRaw, keys: ["id"]),
            name: JSONHelpers.string(artistRaw, keys: ["name"]).isEmpty ? nil : JSONHelpers.string(artistRaw, keys: ["name"]),
            title: nil,
            path: JSONHelpers.string(artistRaw, keys: ["path"]).isEmpty ? nil : JSONHelpers.string(artistRaw, keys: ["path"]),
            year: nil,
            posterURL: nil
        )
        let albumRows = JSONHelpers.dictArray(raw["albums"])
        let albums = albumRows.map { albumRaw -> MusicAlbum in
            let tracks = JSONHelpers.dictArray(albumRaw["tracks"]).map { t in
                MusicTrack(
                    id: JSONHelpers.string(t, keys: ["id"]),
                    title: JSONHelpers.string(t, keys: ["title"]),
                    streamURL: JSONHelpers.string(t, keys: ["stream_url", "streamUrl"]).isEmpty
                        ? nil
                        : JSONHelpers.string(t, keys: ["stream_url", "streamUrl"])
                )
            }
            return MusicAlbum(
                id: JSONHelpers.string(albumRaw, keys: ["id"]),
                title: JSONHelpers.string(albumRaw, keys: ["title"]),
                year: JSONHelpers.optionalInt(albumRaw, keys: ["year"]),
                tracks: tracks
            )
        }
        return MusicArtistDetail(artist: artist, albums: albums)
    }

    static func bookAuthor(from raw: [String: Any], serverBase: URL?) -> BookAuthorDetail {
        let authorRaw = JSONHelpers.asDict(raw["author"] ?? raw)
        let author = LibraryRow(
            id: JSONHelpers.string(authorRaw, keys: ["id"]),
            name: JSONHelpers.string(authorRaw, keys: ["name"]).isEmpty ? nil : JSONHelpers.string(authorRaw, keys: ["name"]),
            title: nil,
            path: JSONHelpers.string(authorRaw, keys: ["path"]).isEmpty ? nil : JSONHelpers.string(authorRaw, keys: ["path"]),
            year: nil,
            posterURL: nil
        )
        let bookRows = JSONHelpers.dictArray(raw["books"])
        let books = bookRows.map { b -> BookItem in
            let files = JSONHelpers.dictArray(b["files"]).map { f in
                BookFile(
                    id: JSONHelpers.string(f, keys: ["id"]),
                    title: JSONHelpers.string(f, keys: ["title"]),
                    path: JSONHelpers.string(f, keys: ["path"]),
                    streamURL: JSONHelpers.string(f, keys: ["stream_url", "streamUrl"]).isEmpty
                        ? nil
                        : JSONHelpers.string(f, keys: ["stream_url", "streamUrl"])
                )
            }
            return BookItem(
                id: JSONHelpers.string(b, keys: ["id"]),
                title: JSONHelpers.string(b, keys: ["title"]),
                year: JSONHelpers.optionalInt(b, keys: ["year"]),
                files: files
            )
        }
        return BookAuthorDetail(author: author, books: books)
    }

    static func liveTV(from raw: [String: Any]) -> LiveTVData {
        let channelRows = JSONHelpers.dictArray(raw["channels"])
        let channels = channelRows.map { c -> LiveTVChannel in
            var nowTitle: String? = nil
            if let np = c["now_playing"] as? [String: Any] {
                nowTitle = JSONHelpers.string(np, keys: ["title"]).isEmpty ? nil : JSONHelpers.string(np, keys: ["title"])
            }
            return LiveTVChannel(
                id: JSONHelpers.string(c, keys: ["id"]),
                name: JSONHelpers.string(c, keys: ["name"]),
                number: JSONHelpers.string(c, keys: ["number"]),
                url: JSONHelpers.string(c, keys: ["url"]).isEmpty ? nil : JSONHelpers.string(c, keys: ["url"]),
                category: JSONHelpers.string(c, keys: ["category"]).isEmpty ? nil : JSONHelpers.string(c, keys: ["category"]),
                nowPlayingTitle: nowTitle
            )
        }
        let recRows = JSONHelpers.dictArray(raw["recordings"])
        let recordings = recRows.map { r in
            LiveTVRecording(
                id: JSONHelpers.string(r, keys: ["id"]),
                channelID: JSONHelpers.string(r, keys: ["channel_id", "channelId"]),
                title: JSONHelpers.string(r, keys: ["title"]),
                start: JSONHelpers.string(r, keys: ["start"]),
                end: JSONHelpers.string(r, keys: ["end"]),
                status: JSONHelpers.string(r, keys: ["status"])
            )
        }
        let timerRows = JSONHelpers.dictArray(raw["timers"])
        let timers = timerRows.map { t in
            LiveTVTimer(
                id: JSONHelpers.string(t, keys: ["id"]),
                channelID: JSONHelpers.string(t, keys: ["channel_id", "channelId"]),
                title: JSONHelpers.string(t, keys: ["title"]),
                start: JSONHelpers.string(t, keys: ["start"]),
                end: JSONHelpers.string(t, keys: ["end"]),
                series: JSONHelpers.bool(t, keys: ["series"])
            )
        }
        return LiveTVData(
            channels: channels,
            recordings: recordings,
            timers: timers,
            available: raw["available"] as? Bool ?? true
        )
    }
}
