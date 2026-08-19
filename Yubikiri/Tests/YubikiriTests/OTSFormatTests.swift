import XCTest
@testable import Yubikiri

final class OTSFormatTests: XCTestCase {
    private func randomDigest() -> Data {
        Data((0..<32).map { _ in UInt8.random(in: 0...255) })
    }

    func testVarintRoundTrip() throws {
        for value in [0, 1, 127, 128, 300, 16384, 999_999] {
            let encoded = OTSVarint.encode(value)
            var offset = 0
            let decoded = try OTSVarint.decode(encoded, offset: &offset)
            XCTAssertEqual(decoded, value)
            XCTAssertEqual(offset, encoded.count)
        }
    }

    func testSingleAttestationRoundTrip() throws {
        let digest = randomDigest()
        let stamp = OTSTimestamp(msg: digest)
        stamp.attestations.insert(.pending(uri: "alice.btc.calendar.opentimestamps.org"))

        var data = Data()
        try stamp.serialize(into: &data)

        var offset = 0
        let decoded = try OTSTimestamp.deserialize(from: data, offset: &offset, msg: digest)
        XCTAssertEqual(decoded.attestations, stamp.attestations)
        XCTAssertEqual(offset, data.count)
    }

    func testDetachedFileRoundTrip() throws {
        let digest = randomDigest()
        let stamp = OTSTimestamp(msg: digest)
        stamp.attestations.insert(.bitcoin(height: 812_345))

        let file = OTSDetachedFile(timestamp: stamp)
        let data = try file.serialize()

        XCTAssertTrue(data.starts(with: OTSDetachedFile.headerMagic))

        let decoded = try OTSDetachedFile.deserialize(data)
        XCTAssertEqual(decoded.timestamp.msg, digest)
        XCTAssertEqual(decoded.timestamp.attestations, stamp.attestations)
    }

    func testMergeCombinesAttestationsFromDifferentCalendars() throws {
        let digest = randomDigest()
        let a = OTSTimestamp(msg: digest)
        a.attestations.insert(.pending(uri: "alice.btc.calendar.opentimestamps.org"))
        let b = OTSTimestamp(msg: digest)
        b.attestations.insert(.pending(uri: "bob.btc.calendar.opentimestamps.org"))

        try a.merge(b)

        XCTAssertEqual(a.attestations.count, 2)
    }

    func testOpAppendChangesDigestAndRoundTrips() throws {
        let digest = randomDigest()
        let root = OTSTimestamp(msg: digest)
        let suffix = Data([0x01, 0x02, 0x03])
        let appended = try OTSOp.append(suffix).apply(to: digest)
        let child = OTSTimestamp(msg: appended)
        child.attestations.insert(.pending(uri: "alice.btc.calendar.opentimestamps.org"))
        root.ops[.append(suffix)] = child

        var data = Data()
        try root.serialize(into: &data)

        var offset = 0
        let decoded = try OTSTimestamp.deserialize(from: data, offset: &offset, msg: digest)
        XCTAssertEqual(decoded.ops.count, 1)
        XCTAssertEqual(decoded.ops[.append(suffix)]?.msg, appended)
    }

    func testMalformedDataThrows() {
        XCTAssertThrowsError(try OTSDetachedFile.deserialize(Data([0x01, 0x02])))
    }
}
