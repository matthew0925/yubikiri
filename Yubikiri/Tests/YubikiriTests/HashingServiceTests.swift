import XCTest
@testable import Yubikiri

final class HashingServiceTests: XCTestCase {
    func testSameInputProducesSameHash() {
        let due = Date(timeIntervalSince1970: 0)
        let a = HashingService.hashEntry(body: "納品しました", amount: 50000, dueDate: due)
        let b = HashingService.hashEntry(body: "納品しました", amount: 50000, dueDate: due)
        XCTAssertEqual(a, b)
    }

    func testDifferentBodyProducesDifferentHash() {
        let a = HashingService.hashEntry(body: "A案", amount: nil, dueDate: nil)
        let b = HashingService.hashEntry(body: "B案", amount: nil, dueDate: nil)
        XCTAssertNotEqual(a, b)
    }

    func testLineEndingNormalization() {
        let a = HashingService.hashEntry(body: "line1\r\nline2", amount: nil, dueDate: nil)
        let b = HashingService.hashEntry(body: "line1\nline2", amount: nil, dueDate: nil)
        XCTAssertEqual(a, b)
    }

    func testHashIsHex64() {
        let hash = HashingService.hashEntry(body: "test", amount: nil, dueDate: nil)
        XCTAssertEqual(hash.count, 64)
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit })
    }
}
