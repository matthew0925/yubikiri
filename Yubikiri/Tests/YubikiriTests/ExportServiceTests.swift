import XCTest
@testable import Yubikiri

final class ExportServiceTests: XCTestCase {
    @MainActor
    func testBundleIncludesCaseAndEntryFields() throws {
        let caseItem = Case(title: "サイト制作", clientName: "A社", createdAt: Date(timeIntervalSince1970: 0))
        let entry = Entry(
            body: "初回納品",
            amount: 100000,
            dueDate: Date(timeIntervalSince1970: 86400),
            createdAt: Date(timeIntervalSince1970: 3600),
            contentHash: String(repeating: "a", count: 64)
        )
        caseItem.entries = [entry]

        let bundle = ExportService.makeBundle(cases: [caseItem], exportedAt: Date(timeIntervalSince1970: 7200))
        XCTAssertEqual(bundle.cases.count, 1)
        XCTAssertEqual(bundle.cases[0].title, "サイト制作")
        XCTAssertEqual(bundle.cases[0].entries.count, 1)
        XCTAssertEqual(bundle.cases[0].entries[0].contentHash, String(repeating: "a", count: 64))
        XCTAssertFalse(bundle.cases[0].entries[0].isAnchored)
    }

    func testJSONRoundTrip() throws {
        let bundle = ExportService.ExportedBundle(
            exportedAt: Date(timeIntervalSince1970: 0),
            cases: [
                ExportService.ExportedCase(
                    title: "案件A",
                    clientName: "クライアントA",
                    createdAt: Date(timeIntervalSince1970: 0),
                    entries: []
                )
            ]
        )
        let data = try ExportService.encodeJSON(bundle)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportService.ExportedBundle.self, from: data)
        XCTAssertEqual(decoded.cases.first?.title, "案件A")
    }
}
