import XCTest
@testable import Yubikiri

final class OpenTimestampsClientTests: XCTestCase {
    private func makeStubbedSession(responder: @escaping (URLRequest) -> (Data, HTTPURLResponse)) -> URLSession {
        StubURLProtocol.responder = responder
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func digestData(_ hex: String) -> Data {
        var bytes = [UInt8]()
        var chars = Array(hex)
        while chars.count >= 2 {
            bytes.append(UInt8(String(chars[0...1]), radix: 16)!)
            chars.removeFirst(2)
        }
        return Data(bytes)
    }

    /// カレンダーの `POST /digest` 応答を模した、単一pending attestationのみのTimestampを作る。
    private func makePendingResponse(digest: Data, uri: String) throws -> Data {
        let stamp = OTSTimestamp(msg: digest)
        stamp.attestations.insert(.pending(uri: uri))
        var data = Data()
        try stamp.serialize(into: &data)
        return data
    }

    /// カレンダーの `GET /timestamp/{hex}` 応答を模した、bitcoin attestation付きのTimestamp。
    private func makeBitcoinResponse(digest: Data, height: Int) throws -> Data {
        let stamp = OTSTimestamp(msg: digest)
        stamp.attestations.insert(.bitcoin(height: height))
        var data = Data()
        try stamp.serialize(into: &data)
        return data
    }

    func testSubmitAggregatesResponsesFromAllCalendars() async throws {
        let hashHex = String(repeating: "ab", count: 32)
        let digest = digestData(hashHex)
        let calendars = [
            URL(string: "https://calendar-a.example.com")!,
            URL(string: "https://calendar-b.example.com")!,
        ]

        let session = makeStubbedSession { request in
            let uri = request.url!.host!
            let body = try! self.makePendingResponse(digest: digest, uri: uri)
            return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let client = URLSessionOpenTimestampsClient(session: session, calendars: calendars)
        let proof = try await client.submit(hashHex: hashHex)

        XCTAssertFalse(proof.isEmpty)
        let file = try OTSDetachedFile.deserialize(proof)
        let uris = file.timestamp.allAttestations().compactMap { _, attestation -> String? in
            if case .pending(let uri) = attestation { return uri }
            return nil
        }
        XCTAssertEqual(Set(uris), Set(["calendar-a.example.com", "calendar-b.example.com"]))
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

    func testVerifyDetectsBitcoinAttestationAfterUpgrade() async throws {
        let hashHex = String(repeating: "ef", count: 32)
        let digest = digestData(hashHex)
        let calendar = URL(string: "https://calendar-a.example.com")!

        let session = makeStubbedSession { request in
            let body: Data
            if request.url!.path.contains("timestamp") {
                body = try! self.makeBitcoinResponse(digest: digest, height: 800_000)
            } else {
                body = try! self.makePendingResponse(digest: digest, uri: "calendar-a.example.com")
            }
            return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = URLSessionOpenTimestampsClient(session: session, calendars: [calendar])
        let proof = try await client.submit(hashHex: hashHex)

        let result = try await client.verify(hashHex: hashHex, proof: proof)
        XCTAssertTrue(result.isValid)
        XCTAssertNotNil(result.upgradedProof)
    }

    func testVerifyReportsPendingWhenNoAttestation() async throws {
        let hashHex = String(repeating: "12", count: 32)
        let digest = digestData(hashHex)
        let calendar = URL(string: "https://calendar-a.example.com")!

        let session = makeStubbedSession { request in
            let body = try! self.makePendingResponse(digest: digest, uri: "calendar-a.example.com")
            return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = URLSessionOpenTimestampsClient(session: session, calendars: [calendar])
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
