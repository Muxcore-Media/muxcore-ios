import Foundation

enum SearchScope: String, CaseIterable, Hashable, Identifiable {
    case all
    case movies
    case tv
    case music
    case books
    case comics
    case audiobooks
    case homevideos
    case musicvideos
    case add

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .movies: return "Movies"
        case .tv: return "TV"
        case .music: return "Music"
        case .books: return "Books"
        case .comics: return "Comics"
        case .audiobooks: return "Audiobooks"
        case .homevideos: return "Home Videos"
        case .musicvideos: return "Music Videos"
        case .add: return "Add new"
        }
    }

    static func parse(_ raw: String?) -> SearchScope {
        guard let raw else { return .all }
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if v == "add" || v == "request" { return .add }
        return SearchScope(rawValue: v) ?? .all
    }
}

enum LibrarySearchHit: Identifiable, Hashable {
    case movie(Movie)
    case tv(TVShow)
    case other(id: String, route: AppRoute, title: String, subtitle: String, posterURL: String?)

    var id: String {
        switch self {
        case .movie(let m): return "movie:\(m.id)"
        case .tv(let s): return "tv:\(s.id)"
        case .other(let id, _, let title, let subtitle, _): return "other:\(subtitle):\(id):\(title)"
        }
    }
}

enum UnifiedSearch {
    static func scopes(for caps: Capabilities) -> [SearchScope] {
        var scopes: [SearchScope] = [.all]
        let libs: [SearchScope] = [.movies, .tv, .music, .books, .comics, .audiobooks, .homevideos, .musicvideos]
        for lib in libs where caps.libraryEnabled(lib.rawValue) {
            scopes.append(lib)
        }
        if caps.featureEnabled("search") || caps.featureEnabled("request")
            || caps.libraryEnabled("movies") || caps.libraryEnabled("tv") || caps.libraryEnabled("music") {
            scopes.append(.add)
        }
        return scopes
    }

    static func run(
        api: APIClient,
        caps: Capabilities,
        query: String,
        scope: SearchScope
    ) async throws -> (library: [LibrarySearchHit], remote: [SearchResult]) {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard needle.count >= 2 else { return ([], []) }

        let emptyLib = LibraryListResponse(items: [], total: 0, page: 1, pageSize: 0, available: true, comingSoon: false, message: nil)

        async let moviesTask: ListResponse<Movie> = {
            if scopeIncludesLibrary(scope, "movies") && caps.libraryEnabled("movies") {
                return try await api.listMovies(page: 1, pageSize: 200)
            }
            return ListResponse(items: [], total: 0, page: 1, pageSize: 0)
        }()

        async let showsTask: ListResponse<TVShow> = {
            if scopeIncludesLibrary(scope, "tv") && caps.libraryEnabled("tv") {
                return try await api.listTVShows(page: 1, pageSize: 200)
            }
            return ListResponse(items: [], total: 0, page: 1, pageSize: 0)
        }()

        async let musicTask: LibraryListResponse = {
            if scopeIncludesLibrary(scope, "music") && caps.libraryEnabled("music") {
                return (try? await api.listMusic()) ?? emptyLib
            }
            return emptyLib
        }()

        async let booksTask: LibraryListResponse = {
            if scopeIncludesLibrary(scope, "books") && caps.libraryEnabled("books") {
                return (try? await api.listBooks()) ?? emptyLib
            }
            return emptyLib
        }()

        async let comicsTask: LibraryListResponse = {
            if scopeIncludesLibrary(scope, "comics") && caps.libraryEnabled("comics") {
                return (try? await api.listComics()) ?? emptyLib
            }
            return emptyLib
        }()

        async let audiobooksTask: LibraryListResponse = {
            if scopeIncludesLibrary(scope, "audiobooks") && caps.libraryEnabled("audiobooks") {
                return (try? await api.listAudiobooks()) ?? emptyLib
            }
            return emptyLib
        }()

        async let remoteTask: [SearchResult] = {
            var remote: [SearchResult] = []
            if scopeIncludesMovieTVRemote(scope) {
                if let rows = try? await api.search(query: query) {
                    remote.append(contentsOf: rows)
                }
            }
            if scopeIncludesMusicRemote(scope, caps) {
                for type in [SearchMediaType.music, .musicAlbum, .musicTrack] {
                    if let rows = try? await api.search(query: query, type: type) {
                        remote.append(contentsOf: rows)
                    }
                }
            }
            return remote
        }()

        let movies = try await moviesTask
        let shows = try await showsTask
        let music = await musicTask
        let books = await booksTask
        let comics = await comicsTask
        let audiobooks = await audiobooksTask
        let remote = await remoteTask

        var library: [LibrarySearchHit] = []
        if scope != .add {
            if scopeIncludesLibrary(scope, "movies") {
                library.append(contentsOf: movies.items
                    .filter { AcquisitionHelpers.isWatchable($0.hasFile) && $0.title.lowercased().contains(needle) }
                    .map { .movie($0) })
            }
            if scopeIncludesLibrary(scope, "tv") {
                library.append(contentsOf: shows.items
                    .filter { AcquisitionHelpers.isWatchable($0.hasFile) && $0.title.lowercased().contains(needle) }
                    .map { .tv($0) })
            }
            if scopeIncludesLibrary(scope, "music") {
                library.append(contentsOf: music.items
                    .filter { rowTitle($0).contains(needle) }
                    .map {
                        .other(
                            id: $0.id,
                            route: .musicArtist($0.id),
                            title: rowLabel($0),
                            subtitle: "Music",
                            posterURL: $0.posterURL
                        )
                    })
            }
            if scopeIncludesLibrary(scope, "books") {
                library.append(contentsOf: books.items
                    .filter { rowTitle($0).contains(needle) }
                    .map {
                        .other(
                            id: $0.id,
                            route: .bookAuthor($0.id),
                            title: rowLabel($0),
                            subtitle: "Books",
                            posterURL: $0.posterURL
                        )
                    })
            }
            if scopeIncludesLibrary(scope, "comics") {
                library.append(contentsOf: comics.items
                    .filter { rowTitle($0).contains(needle) }
                    .map {
                        .other(
                            id: $0.id,
                            route: .comics,
                            title: rowLabel($0),
                            subtitle: "Comics",
                            posterURL: $0.posterURL
                        )
                    })
            }
            if scopeIncludesLibrary(scope, "audiobooks") {
                library.append(contentsOf: audiobooks.items
                    .filter { rowTitle($0).contains(needle) }
                    .map {
                        .other(
                            id: $0.id,
                            route: .audiobooks,
                            title: rowLabel($0),
                            subtitle: "Audiobooks",
                            posterURL: $0.posterURL
                        )
                    })
            }
        }

        var filteredRemote = remote
        switch scope {
        case .movies: filteredRemote = filteredRemote.filter { $0.mediaType == .movie }
        case .tv: filteredRemote = filteredRemote.filter { $0.mediaType == .tv }
        case .music:
            filteredRemote = filteredRemote.filter {
                $0.mediaType == .music || $0.mediaType == .musicAlbum || $0.mediaType == .musicTrack
            }
        case .add, .all, .books, .comics, .audiobooks, .homevideos, .musicvideos:
            break
        }

        return (library, filteredRemote)
    }

    static func remoteNotInLibrary(library: [LibrarySearchHit], remote: [SearchResult]) -> [SearchResult] {
        let titles = Set(library.flatMap { hit -> [String] in
            switch hit {
            case .movie(let m): return ["\(SearchMediaType.movie.rawValue):\(m.title.lowercased())"]
            case .tv(let s): return ["\(SearchMediaType.tv.rawValue):\(s.title.lowercased())"]
            case .other(_, _, let title, let subtitle, _):
                if subtitle == "Music" { return ["music:\(title.lowercased())"] }
                return []
            }
        })
        return remote.filter { result in
            if result.mediaType == .music || result.mediaType == .musicAlbum || result.mediaType == .musicTrack {
                let key = (result.artistName ?? result.title).lowercased()
                return !titles.contains("music:\(key)")
            }
            return !titles.contains("\(result.mediaType.rawValue):\(result.title.lowercased())")
        }
    }

    private static func scopeIncludesLibrary(_ scope: SearchScope, _ lib: String) -> Bool {
        scope == .all || scope.rawValue == lib
    }

    private static func scopeIncludesMovieTVRemote(_ scope: SearchScope) -> Bool {
        scope == .all || scope == .add || scope == .movies || scope == .tv
    }

    private static func scopeIncludesMusicRemote(_ scope: SearchScope, caps: Capabilities) -> Bool {
        guard caps.libraryEnabled("music") else { return false }
        return scope == .all || scope == .add || scope == .music
    }

    private static func rowTitle(_ row: LibraryRow) -> String {
        (row.title ?? row.name ?? row.id).lowercased()
    }

    private static func rowLabel(_ row: LibraryRow) -> String {
        row.title ?? row.name ?? row.id
    }
}
