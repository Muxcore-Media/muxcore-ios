import XCTest
@testable import MuxCoreKit

final class WebVTTParserTests: XCTestCase {
    func testParseSimpleCue() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:04.000
        Hello world
        """
        let cues = WebVTTParser.parse(content)
        XCTAssertEqual(cues.count, 1)
        XCTAssertEqual(cues[0].start, 1, accuracy: 0.001)
        XCTAssertEqual(cues[0].end, 4, accuracy: 0.001)
        XCTAssertEqual(cues[0].text, "Hello world")
    }

    func testActiveCueSelection() {
        let cues = [
            VTTCue(start: 0, end: 2, text: "A"),
            VTTCue(start: 2, end: 5, text: "B"),
        ]
        XCTAssertEqual(WebVTTParser.activeCue(at: 1.5, cues: cues), "A")
        XCTAssertEqual(WebVTTParser.activeCue(at: 3, cues: cues), "B")
        XCTAssertNil(WebVTTParser.activeCue(at: 6, cues: cues))
    }
}
