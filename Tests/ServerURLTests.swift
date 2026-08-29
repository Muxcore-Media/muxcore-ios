import XCTest
@testable import MuxCoreKit

final class ServerURLTests: XCTestCase {
    func testValidationAcceptsMediaServer() {
        let url = URL(string: "https://mux.zem.systems")!
        XCTAssertNil(ServerURL.validationError(for: url))
    }

    func testValidationRejectsAuthHost() {
        let url = URL(string: "https://auth.zem.systems")!
        XCTAssertEqual(
            ServerURL.validationError(for: url),
            "Use your media server URL (https://mux.zem.systems), not the auth login host."
        )
    }

    func testValidationRejectsAdminHost() {
        let url = URL(string: "https://admin.zem.systems")!
        XCTAssertEqual(
            ServerURL.validationError(for: url),
            "Use your media server URL (https://mux.zem.systems), not the admin UI host."
        )
    }
}
