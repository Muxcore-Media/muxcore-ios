import XCTest

@testable import MuxCoreKit

final class AuthCallbackTests: XCTestCase {
    func testAuthCallbackCodeExtractsMuxBFFCallback() {
        let url = URL(string: "https://mux.zem.systems/auth/callback?code=abc123")!
        XCTAssertEqual(AuthCallback.authCallbackCode(from: url, serverHost: "mux.zem.systems"), "abc123")
    }

    func testAuthCallbackCodeExtractsMobileDeepLink() {
        let url = URL(string: "muxcore://auth/callback?code=mobile1")!
        XCTAssertEqual(AuthCallback.authCallbackCode(from: url, serverHost: "mux.zem.systems"), "mobile1")
    }

    func testAuthCallbackCodeIgnoresAuthHost() {
        let url = URL(string: "https://auth.zem.systems/login?redirect=...")!
        XCTAssertNil(AuthCallback.authCallbackCode(from: url, serverHost: "mux.zem.systems"))
    }

    func testAuthCallbackCodeIgnoresWrongServerHost() {
        let url = URL(string: "https://other.example/auth/callback?code=x")!
        XCTAssertNil(AuthCallback.authCallbackCode(from: url, serverHost: "mux.zem.systems"))
    }

    func testIsMuxcoreAuthDeepLink() {
        XCTAssertTrue(AuthCallback.isMuxcoreAuthDeepLink(URL(string: "muxcore://auth/callback?code=1")!))
        XCTAssertFalse(AuthCallback.isMuxcoreAuthDeepLink(URL(string: "https://mux.zem.systems/auth/callback?code=1")!))
    }

    func testMobileAuthLoginURL() {
        let base = URL(string: "https://mux.zem.systems")!
        let loginURL = AuthCallback.mobileAuthLoginURL(serverBase: base)
        XCTAssertEqual(loginURL.path, "/api/mobile/auth/login")
        XCTAssertTrue(loginURL.absoluteString.contains("redirect_uri=muxcore"))
    }
}
