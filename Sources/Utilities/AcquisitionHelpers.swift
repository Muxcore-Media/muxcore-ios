import Foundation

enum AcquisitionHelpers {
    static func isWatchable(_ hasFile: Bool) -> Bool { hasFile }

    static func isActiveRequestStatus(_ status: String) -> Bool {
        let s = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !s.isEmpty && s != "available"
    }

    static func requestStatusLabel(_ status: String) -> String {
        switch status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "downloading": return "Downloading"
        case "searching": return "Searching"
        case "queued": return "Queued"
        case "added": return "In library"
        case "requested": return "Requested"
        case "workflow": return "Pending approval"
        case "available": return "Available"
        default:
            return status.replacingOccurrences(of: "_", with: " ")
        }
    }

    static func requestPhase(_ status: String) -> String {
        switch status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "downloading": return "downloading"
        case "searching", "queued": return "searching"
        default: return "requested"
        }
    }

    static func posterURLForRequest(_ poster: String, serverBase: URL?) -> String {
        let p = poster.trimmingCharacters(in: .whitespacesAndNewlines)
        if p.isEmpty { return "" }
        if p.hasPrefix("http") || p.hasPrefix("/images") {
            return PosterURL.absolute(p, serverBase: serverBase)
        }
        if p.hasPrefix("/") { return "https://image.tmdb.org/t/p/w185\(p)" }
        return p
    }

    enum InProgressEntry: Identifiable, Hashable {
        case request(MediaRequest)
        case libraryMovie(Movie)
        case libraryTV(TVShow)

        var id: String {
            switch self {
            case .request(let r): return "req-\(r.id)"
            case .libraryMovie(let m): return "lib-movie-\(m.id)"
            case .libraryTV(let s): return "lib-tv-\(s.id)"
            }
        }
    }

    static func mergeInProgress(requests: [MediaRequest], movies: [Movie], shows: [TVShow]) -> [InProgressEntry] {
        let active = requests.filter { isActiveRequestStatus($0.status) }
        var keys = Set(active.map { requestKey($0) })
        var out: [InProgressEntry] = active.map { .request($0) }

        for movie in movies where !isWatchable(movie.hasFile) {
            let key = movie.id.isEmpty ? "movie:\(movie.title.lowercased())" : "movie:\(movie.id)"
            if keys.contains(key) { continue }
            keys.insert(key)
            out.append(.libraryMovie(movie))
        }
        for show in shows where !isWatchable(show.hasFile) {
            let key = show.id.isEmpty ? "tv:\(show.title.lowercased())" : "tv:\(show.id)"
            if keys.contains(key) { continue }
            keys.insert(key)
            out.append(.libraryTV(show))
        }
        return out
    }

    static func groupByPhase(_ entries: [InProgressEntry]) -> (downloading: [InProgressEntry], searching: [InProgressEntry], requested: [InProgressEntry]) {
        var downloading: [InProgressEntry] = []
        var searching: [InProgressEntry] = []
        var requested: [InProgressEntry] = []
        for entry in entries {
            let phase: String
            switch entry {
            case .request(let r): phase = requestPhase(r.status)
            case .libraryMovie, .libraryTV: phase = "requested"
            }
            switch phase {
            case "downloading": downloading.append(entry)
            case "searching": searching.append(entry)
            default: requested.append(entry)
            }
        }
        return (downloading, searching, requested)
    }

    private static func requestKey(_ req: MediaRequest) -> String {
        if !req.itemId.isEmpty { return "\(req.itemType):\(req.itemId)" }
        if req.tmdbId > 0 { return "\(req.itemType):tmdb:\(req.tmdbId)" }
        return "\(req.itemType):\(req.title.lowercased())"
    }
}
