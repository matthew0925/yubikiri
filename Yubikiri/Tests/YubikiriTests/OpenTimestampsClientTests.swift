import XCTest
@testable import Yubikiri

final class OpenTimestampsClientTests: XCTestCase {
    private func makeStubbedSession(responder: @escaping (URLRequest) -> (Data, HTTPURLResponse)) -> URLSession {
        StubURLProtocol.responder = responder
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    func testSubmitAggregatesResponsesFromAllCalendars() async throws {
        let hashHex = String(repeating: "ab", count: 32)
        let calendars = [
            URL(string: "https://calendar-a.example.com")!,
            URL(string: "https://calendar-b.example.com")!,
        ]

        let session = makeStubbedSession { request in
            let body = "pending-from-\(request.url!.host!)".data(using: .utf8)!
            return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let client = URLSessionOpenTimestampsClient(session: session, calendars: calendars)
        let proof = try await client.submit(hashHex: hashHex)

        XCTAssertFalse(proof.isEmpty)
        let text = String(data: proof, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("pending-from-calendar-a.example.com"))
        XCTAssertTrue(text.contains("pending-from-calendar-b.example.com"))
    }

    func testSubmitThrowsWhenAllCalendarsFail() async {
        let hashHex = String(repeating: "cd", count: 32)
        let session = makeStubbedSession { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!)
        }
        let client = URLSessionOpenTimestampsClient(session: session, calendars: [URL(string: "https://x.example.com")!])

        do {
            _ = try await client.submit(hashHex: hashHex)
            XCTFail("expected failure")
        } catch {
            XCTAssertTrue(error is OpenTimestampsError)
        }
    }

    func testSubmitRejectsInvalidHash() async {
        let session = makeStubbedSession { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = URLSessionOpenTimestampsClient(session: session, calendars: [URL(string: "https://x.example.com")!])
        do {
            _ = try await client.submit(hashHex: "not-a-hash")
            XCTFail("expected failure")
        } catch {
            XCTAssertTrue(error is OpenTimestampsError)
        }
    }

    func testVerifyDetectsBitcoinAttestationTag() async throws {
        let hashHex = String(repeating: "ef", count: 32)
        let bitcoinTag: [UInt8] = [0x05, 0x88, 0x96, 0x0d, 0x73, 0xd7, 0x19, 0x01]
        let calendar = URL(string: "https://calendar-a.example.com")!

        let submitSession = makeStubbedSession { request in
            (Data(bitcoinTag), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = URLSessionOpenTimestampsClient(session: submitSession, calendars: [calendar])
        let proof = try await client.submit(hashHex: hashHex)

        let result = try await client.verify(hashHex: hashHex, proof: proof)
        XCTAssertTrue(result.isValid)
    }

    func testVerifyReportsPendingWhenNoAttestation() async throws {
        let hashHex = String(repeating: "12", count: 32)
        let calendar = URL(string: "https://calendar-a.example.com")!

        let submitSession = makeStubbedSession { request in
            ("just-pending".data(using: .utf8)!, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = URLSessionOpenTimestampsClient(session: submitSession, calendars: [calendar])
        let proof = try await client.submit(hashHex: hashHex)

        let result = try await client.verify(hashHex: hashHex, proof: proof)
        XCTAssertFalse(result.isValid)
    }
}

private final class StubURLProtocol: URLProtocol {
    static var responder: ((URLRequest) -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let responder = Self.responder else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let (data, response) = responder(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
