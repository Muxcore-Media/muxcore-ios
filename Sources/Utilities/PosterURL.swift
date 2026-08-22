import Foundation

enum PosterURL {
    static func resolve(_ path: String, kind: PosterAssetKind = .movie, serverBase: URL?) -> String {
        guard !path.isEmpty else { return "" }
        if path.hasPrefix("http://") || path.hasPrefix("https://") || path.hasPrefix("/images/") {
            return absolute(path, serverBase: serverBase)
        }
        if path.hasPrefix("/") {
            return "https://image.tmdb.org/t/p/w500\(path)"
        }
        let prefix = kind == .tv ? "/images/tv/" : "/images/movies/"
        return absolute(prefix + path, serverBase: serverBase)
    }

    static func absolute(_ path: String, serverBase: URL?) -> String {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return path
        }
        guard let serverBase else { return path }
        if path.hasPrefix("/") {
            return serverBase.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path
        }
        return URL(string: path, relativeTo: serverBase)?.absoluteString ?? path
    }
}

enum PosterAssetKind {
    case movie
    case tv
}
