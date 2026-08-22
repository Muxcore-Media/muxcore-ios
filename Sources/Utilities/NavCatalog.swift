import Foundation

struct NavItem: Identifiable, Hashable {
    var id: String { to }
    let to: String
    let label: String
    let library: String?
    let feature: String?

    init(_ to: String, label: String, library: String? = nil, feature: String? = nil) {
        self.to = to
        self.label = label
        self.library = library
        self.feature = feature
    }
}

enum NavCatalog {
    static let primary: [NavItem] = [
        NavItem("/", label: "Home"),
        NavItem("/movies", label: "Movies", library: "movies"),
        NavItem("/tv", label: "TV", library: "tv"),
        NavItem("/music", label: "Music", library: "music"),
        NavItem("/books", label: "Books", library: "books"),
        NavItem("/comics", label: "Comics", library: "comics"),
        NavItem("/audiobooks", label: "Audiobooks", library: "audiobooks"),
    ]

    static let overflow: [NavItem] = [
        NavItem("/musicvideos", label: "Music Videos", library: "musicvideos"),
        NavItem("/mixed", label: "Mixed", feature: "mixed"),
        NavItem("/homevideos", label: "Home Videos", library: "homevideos"),
        NavItem("/collections", label: "Collections", feature: "collections"),
        NavItem("/studios", label: "Studios", feature: "studios"),
        NavItem("/upcoming", label: "Upcoming", feature: "upcoming"),
        NavItem("/requests", label: "In progress", feature: "request"),
        NavItem("/playlists", label: "Playlists", feature: "playlists"),
        NavItem("/queue", label: "Queue", feature: "queue"),
        NavItem("/livetv", label: "Live TV", feature: "livetv"),
        NavItem("/quickconnect", label: "Quick Connect", feature: "quickconnect"),
        NavItem("/favorites", label: "Favorites"),
    ]

    static let mobileTabPaths: Set<String> = ["/", "/search", "/movies"]

    static func visiblePrimary(_ caps: Capabilities) -> [NavItem] {
        primary.filter { item in
            if let lib = item.library { return caps.libraryEnabled(lib) }
            return true
        }
    }

    static func visibleOverflow(_ caps: Capabilities) -> [NavItem] {
        overflow.filter { item in
            if let lib = item.library { return caps.libraryEnabled(lib) }
            if let feat = item.feature { return caps.featureEnabled(feat) }
            return true
        }
    }

    static func mobileMoreItems(_ caps: Capabilities) -> [NavItem] {
        let fromPrimary = visiblePrimary(caps).filter { !mobileTabPaths.contains($0.to) }
        return fromPrimary + visibleOverflow(caps)
    }
}
