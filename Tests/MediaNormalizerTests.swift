import XCTest
@testable import MuxCoreKit

final class MediaNormalizerTests: XCTestCase {
    func testNormalizeMovieFromSnakeCase() {
        let base = URL(string: "https://mux.zem.systems")!
        let raw: [String: Any] = [
            "id": "abc123",
            "title": "Test Movie",
            "year": 2024,
            "overview": "Hello",
            "runtime": 120,
            "vote_average": 7.5,
            "genres": ["Action", "Sci-Fi"],
            "poster_path": "/abc.jpg",
            "has_file": true,
            "stream_url": "/stream/movies/abc123",
        ]
        let movie = MediaNormalizer.movie(from: raw, serverBase: base)
        XCTAssertEqual(movie.id, "abc123")
        XCTAssertEqual(movie.title, "Test Movie")
        XCTAssertEqual(movie.year, 2024)
        XCTAssertTrue(movie.hasFile)
        XCTAssertTrue(movie.posterURL.contains("image.tmdb.org"))
        XCTAssertEqual(movie.streamURL, "/stream/movies/abc123")
    }

    func testListMoviesFromItemsEnvelope() {
        let base = URL(string: "https://mux.zem.systems")!
        let data: [String: Any] = [
            "items": [
                ["id": "1", "title": "A", "has_file": true],
                ["id": "2", "title": "B", "has_file": false],
            ],
            "total": 2,
            "page": 1,
            "page_size": 48,
        ]
        let list = MediaNormalizer.listMovies(from: data, serverBase: base)
        XCTAssertEqual(list.items.count, 2)
        XCTAssertEqual(list.total, 2)
        XCTAssertEqual(list.items[0].title, "A")
    }

    func testPosterURLAbsolute() {
        let base = URL(string: "https://mux.zem.systems")!
        let resolved = PosterURL.resolve("/images/movies/p1.jpg", serverBase: base)
        XCTAssertEqual(resolved, "https://mux.zem.systems/images/movies/p1.jpg")
    }
}
