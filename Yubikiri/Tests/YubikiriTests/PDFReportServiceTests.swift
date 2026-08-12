import XCTest
@testable import Yubikiri

final class PDFReportServiceTests: XCTestCase {
    @MainActor
    func testMakeReportProducesNonEmptyPDF() {
        let caseItem = Case(title: "サイト制作", clientName: "A社", createdAt: Date(timeIntervalSince1970: 0))
        let entry = Entry(
            body: "初回納品",
            amount: 100000,
            dueDate: Date(timeIntervalSince1970: 86400),
            createdAt: Date(timeIntervalSince1970: 3600),
            contentHash: String(repeating: "a", count: 64)
        )
        caseItem.entries = [entry]

        let data = PDFReportService.makeReport(for: caseItem, generatedAt: Date(timeIntervalSince1970: 7200))

        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(data.prefix(5), Data("%PDF-".utf8))
    }

    @MainActor
    func testMakeReportHandlesEmptyEntries() {
        let caseItem = Case(title: "空案件", clientName: "B社", createdAt: Date(timeIntervalSince1970: 0))
        let data = PDFReportService.makeReport(for: caseItem, generatedAt: Date(timeIntervalSince1970: 0))
        XCTAssertFalse(data.isEmpty)
    }

    func testWriteToTemporaryFileCreatesReadableFile() throws {
        let data = Data("%PDF-1.7 test".utf8)
        let url = try PDFReportService.writeToTemporaryFile(data, caseTitle: "テスト案件", generatedAt: Date(timeIntervalSince1970: 0))
        defer { try? FileManager.default.removeItem(at: url) }

        let readBack = try Data(contentsOf: url)
        XCTAssertEqual(readBack, data)
    }
}
