import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import MuxCoreKit

private final class FixtureURLProtocol: URLProtocol {
    static var response: (URLRequest) throws -> (Int, Data) = { _ in (200, Data()) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.response(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class APIClientUserdataTests: XCTestCase {
    @MainActor private func client() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureURLProtocol.self]
        return APIClient(serverBase: URL(string: "https://fixture.invalid"), sessionToken: "fixture-session", configuration: config)
    }

    @MainActor func testNativePutUsesBearerEvenWithStaleSharedCookie() async throws {
        let cookie = HTTPCookie(properties: [.domain: "fixture.invalid", .path: "/", .name: "session", .value: "stale-cookie"])!
        HTTPCookieStorage.shared.setCookie(cookie)
        defer { HTTPCookieStorage.shared.deleteCookie(cookie) }
        FixtureURLProtocol.response = { request in
            XCTAssertEqual(request.url?.path, "/api/userdata")
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-session")
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            XCTAssertFalse(request.httpShouldHandleCookies)
            XCTAssertNil(request.value(forHTTPHeaderField: "Origin"))
            XCTAssertNil(request.value(forHTTPHeaderField: "Referer"))
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            XCTAssertNotNil(body["queue"])
            XCTAssertNil(body["favorites"])
            XCTAssertNil(body["user_id"])
            return (200, Data(#"{"user_id":"alice","queue":[]}"#.utf8))
        }
        _ = try await client().putUserdata(APIClient.UserdataBlob(queue: []))
    }

    @MainActor func testForeignOriginsAreRefusedBeforeTransport() async {
        var calls = 0
        FixtureURLProtocol.response = { _ in calls += 1; return (200, Data("{}".utf8)) }
        let api = client()
        for path in ["https://other.invalid/api/userdata", "//other.invalid/api/userdata", "http://fixture.invalid/api/userdata", "https://fixture.invalid:8443/api/userdata", "https://user@fixture.invalid/api/userdata"] {
            do { _ = try await api.getJSON(path: path); XCTFail("Accepted \(path)") } catch {}
        }
        XCTAssertEqual(calls, 0)
    }

    @MainActor func testOriginChangeClearsBearer() async throws {
        FixtureURLProtocol.response = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            return (200, Data("{}".utf8))
        }
        let api = client()
        api.setServerBase(URL(string: "https://other.invalid")!)
        XCTAssertNil(api.sessionToken)
        _ = try await api.getJSON(path: "/api/capabilities")
    }

    @MainActor func testLoginExchangeOmitsExistingBearer() async throws {
        FixtureURLProtocol.response = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            XCTAssertEqual(request.url?.path, "/api/mobile/session")
            XCTAssertEqual(request.httpMethod, "POST")
            return (200, Data(#"{"session_token":"new-session","user_id":"alice"}"#.utf8))
        }
        let result = try await client().exchangeMobileCode("one-time-code")
        XCTAssertEqual(result.token, "new-session")
        XCTAssertEqual(result.userID, "alice")
    }

    @MainActor func testSessionScopeUsesStableUserAndTenant() async throws {
        FixtureURLProtocol.response = { request in
            XCTAssertEqual(request.url?.path, "/api/session")
            return (200, Data(#"{"user_id":"alice-id","username":"Display name","tenant_id":"household"}"#.utf8))
        }
        let scope = try await client().sessionScope()
        XCTAssertEqual(scope, UserDataScope(origin: "https://fixture.invalid:443", userID: "alice-id", tenantID: "household"))
    }

    @MainActor func testInvalidSuccessfulDocumentsThrowAtomically() async {
        let documents = ["[]", "null", "{}", #"{"user_id":"alice","queue":[{}]}"#,
            #"{"user_id":"alice","favorites":{"bad":{}}}"#,
            #"{"user_id":"alice","progress":"wrong"}"#,
            #"{"user_id":"alice","prefs":{"display":{"libraryPageSize":"wrong"}}}"#,
            #"{"user_id":"alice","tenant_id":3}"#,
            #"{"user_id":"alice","playlists":[{"id":"p","name":"N"}]}"#]
        let api = client()
        for json in documents {
            FixtureURLProtocol.response = { _ in (200, Data(json.utf8)) }
            do { _ = try await api.getUserdata(); XCTFail("Accepted malformed \(json)") } catch {}
        }
    }

    @MainActor func testIdentityOnlyFreshAccountIsValid() async throws {
        FixtureURLProtocol.response = { _ in (200, Data(#"{"user_id":"alice"}"#.utf8)) }
        let blob = try await client().getUserdata()
        XCTAssertEqual(blob.userID, "alice")
        XCTAssertNil(blob.progress)
    }

    @MainActor func testPreferencePatchPreservesUnknownFields() async throws {
        FixtureURLProtocol.response = { request in
            if request.httpMethod == "GET" {
                return (200, Data(#"{"user_id":"alice","prefs":{"custom":{"enabled":true},"display":{"futureOption":7}}}"#.utf8))
            }
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            let prefs = body["prefs"] as! [String: Any]
            XCTAssertEqual((prefs["custom"] as? [String: Any])?["enabled"] as? Bool, true)
            XCTAssertEqual((prefs["display"] as? [String: Any])?["futureOption"] as? Int, 7)
            XCTAssertEqual((prefs["display"] as? [String: Any])?["theme"] as? String, "light")
            return (200, try JSONSerialization.data(withJSONObject: ["user_id": "alice", "prefs": prefs]))
        }
        let api = client()
        var blob = try await api.getUserdata()
        blob.prefs?.display.theme = .light
        _ = try await api.putUserdata(blob)
    }

    @MainActor func testDeniedUnavailableAndInvalidJSONAreNotAcknowledged() async {
        let api = client()
        for status in [401, 403, 503] {
            FixtureURLProtocol.response = { _ in (status, Data(#"{"error":"fixture-session"}"#.utf8)) }
            do { _ = try await api.getUserdata(); XCTFail("Accepted \(status)") }
            catch { XCTAssertFalse(error.localizedDescription.contains("fixture-session")) }
        }
        FixtureURLProtocol.response = { _ in (200, Data("not json".utf8)) }
        do { _ = try await api.getUserdata(); XCTFail("Accepted invalid JSON") } catch {}
    }

    func testRedirectPolicyRefusesEvenSameOrigin() async {
        let delegate = BFFRedirectPolicy()
        let url = URL(string: "https://fixture.invalid/redirect")!
        let response = HTTPURLResponse(url: url, statusCode: 307, httpVersion: nil, headerFields: [:])!
        let session = URLSession(configuration: .ephemeral)
        for target in [url, URL(string: "https://other.invalid/target")!] {
            let completion = expectation(description: "redirect refused")
            delegate.urlSession(session, task: session.dataTask(with: url), willPerformHTTPRedirection: response,
                                newRequest: URLRequest(url: target)) { request in
                XCTAssertNil(request)
                completion.fulfill()
            }
            await fulfillment(of: [completion], timeout: 1)
        }
        session.invalidateAndCancel()
    }
    @MainActor func testResponseAfterSessionChangeIsDiscarded() async {
        let entered = expectation(description: "fixture request entered")
        let gate = DispatchSemaphore(value: 0)
        FixtureURLProtocol.response = { _ in
            entered.fulfill()
            _ = gate.wait(timeout: .now() + 2)
            return (200, Data(#"{"user_id":"alice"}"#.utf8))
        }
        let api = client()
        let response = Task { try await api.getUserdata() }
        await fulfillment(of: [entered], timeout: 1)
        api.setSessionToken("bob-session")
        gate.signal()
        do { _ = try await response.value; XCTFail("Old account response accepted") }
        catch { guard case APIError.sessionChanged = error else { return XCTFail("Unexpected error: \(error)") } }
    }

    @MainActor func testEquivalentOriginKeepsSessionAndUnsafeURLsAreRejected() async {
        let api = client()
        api.setServerBase(URL(string: "https://FIXTURE.invalid:443/")!)
        XCTAssertEqual(api.sessionToken, "fixture-session")
        for raw in ["ftp://fixture.invalid", "https://name:password@fixture.invalid", "https://fixture.invalid/api", "https://fixture.invalid?query", "https://fixture.invalid#fragment"] {
            XCTAssertNotNil(ServerURL.validationError(for: URL(string: raw)!))
        }
    }

}
