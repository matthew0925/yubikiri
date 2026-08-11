import Foundation

/// 単一端末完結方針のため、バックアップはユーザー自身によるJSONエクスポートで対応する。
enum ExportService {
    struct ExportedEntry: Codable {
        let body: String
        let amount: String?
        let dueDate: Date?
        let createdAt: Date
        let contentHash: String
        let attachmentHash: String?
        let isAnchored: Bool
        let anchoredAt: Date?
    }

    struct ExportedCase: Codable {
        let title: String
        let clientName: String
        let createdAt: Date
        let entries: [ExportedEntry]
    }

    struct ExportedBundle: Codable {
        let exportedAt: Date
        let cases: [ExportedCase]
    }

    static func makeBundle(cases: [Case], exportedAt: Date) -> ExportedBundle {
        let exportedCases = cases.map { caseItem in
            ExportedCase(
                title: caseItem.title,
                clientName: caseItem.clientName,
                createdAt: caseItem.createdAt,
                entries: caseItem.entries.map { entry in
                    ExportedEntry(
                        body: entry.body,
                        amount: entry.amount.map { "\($0)" },
                        dueDate: entry.dueDate,
                        createdAt: entry.createdAt,
                        contentHash: entry.contentHash,
                        attachmentHash: entry.attachmentHash,
                        isAnchored: entry.isAnchored,
                        anchoredAt: entry.anchoredAt
                    )
                }
            )
        }
        return ExportedBundle(exportedAt: exportedAt, cases: exportedCases)
    }

    /// 添付画像バイナリを含めず、記録内容とハッシュ・刻印状態のみをJSONとして書き出す。
    /// （画像を含める場合はファイルサイズが大きくなるため、v1ではJSON側にはハッシュ値のみ保持）
    static func encodeJSON(_ bundle: ExportedBundle) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(bundle)
    }

    static func writeToTemporaryFile(_ data: Data, exportedAt: Date) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "yubikiri-export-\(formatter.string(from: exportedAt)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }
}
