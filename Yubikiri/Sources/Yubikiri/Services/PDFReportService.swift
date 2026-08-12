import UIKit

/// 案件の記録一覧を、クライアントや相談時にそのまま見せられるPDFに整形する。
/// レンダリングは端末内で完結し、外部への通信は発生しない。
enum PDFReportService {
    private static let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
    private static let margin: CGFloat = 36
    private static var contentWidth: CGFloat { pageRect.width - margin * 2 }

    static func makeReport(for caseItem: Case, generatedAt: Date) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let sortedEntries = caseItem.entries.sorted { $0.createdAt < $1.createdAt }

        return renderer.pdfData { context in
            var cursorY: CGFloat = 0

            func startPage() {
                context.beginPage()
                cursorY = margin
            }

            func ensureSpace(_ height: CGFloat) {
                if cursorY + height > pageRect.height - margin {
                    startPage()
                }
            }

            @discardableResult
            func drawText(_ text: String, font: UIFont, color: UIColor = .black, spacingAfter: CGFloat = 4) -> CGFloat {
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let bounds = (text as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: attributes,
                    context: nil
                )
                ensureSpace(bounds.height)
                (text as NSString).draw(
                    in: CGRect(x: margin, y: cursorY, width: contentWidth, height: bounds.height),
                    withAttributes: attributes
                )
                cursorY += bounds.height + spacingAfter
                return bounds.height
            }

            func drawDivider() {
                ensureSpace(12)
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: cursorY))
                path.addLine(to: CGPoint(x: pageRect.width - margin, y: cursorY))
                UIColor.lightGray.setStroke()
                path.lineWidth = 0.5
                path.stroke()
                cursorY += 12
            }

            startPage()

            drawText(caseItem.title, font: .boldSystemFont(ofSize: 20), spacingAfter: 6)
            drawText("クライアント：\(caseItem.clientName)", font: .systemFont(ofSize: 12), color: .darkGray)
            drawText(
                "案件作成日：\(caseItem.createdAt.formatted(date: .abbreviated, time: .omitted))",
                font: .systemFont(ofSize: 10),
                color: .gray,
                spacingAfter: 12
            )
            drawDivider()

            if sortedEntries.isEmpty {
                drawText("記録がありません。", font: .systemFont(ofSize: 12), color: .gray)
            }

            for (index, entry) in sortedEntries.enumerated() {
                ensureSpace(40)
                drawText(
                    "記録 \(index + 1) ／ \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))",
                    font: .boldSystemFont(ofSize: 13),
                    spacingAfter: 6
                )
                drawText(entry.body, font: .systemFont(ofSize: 11), spacingAfter: 6)

                if let amount = entry.amount {
                    drawText("金額：\(amount)", font: .systemFont(ofSize: 10), color: .darkGray)
                }
                if let dueDate = entry.dueDate {
                    drawText(
                        "納期：\(dueDate.formatted(date: .abbreviated, time: .omitted))",
                        font: .systemFont(ofSize: 10),
                        color: .darkGray
                    )
                }

                drawText(
                    "SHA-256：\(entry.contentHash)",
                    font: .monospacedSystemFont(ofSize: 8, weight: .regular),
                    color: .gray
                )

                let statusText: String
                if entry.isAnchored {
                    statusText = entry.isConfirmedOnChain
                        ? "検証状況：ブロックチェーンへの刻印を確認済み"
                        : "検証状況：外部提出済み（ブロックチェーンへの刻印は未確定）"
                } else {
                    statusText = "検証状況：端末内保存のみ（外部への刻印なし）"
                }
                drawText(statusText, font: .systemFont(ofSize: 10), color: .darkGray, spacingAfter: 8)

                if let attachmentData = entry.attachmentData, let image = UIImage(data: attachmentData) {
                    let maxHeight: CGFloat = 180
                    let aspect = image.size.width / max(image.size.height, 1)
                    var width = contentWidth
                    var height = width / max(aspect, 0.001)
                    if height > maxHeight {
                        height = maxHeight
                        width = height * aspect
                    }
                    ensureSpace(height + 8)
                    image.draw(in: CGRect(x: margin, y: cursorY, width: width, height: height))
                    cursorY += height + 8
                }

                if index < sortedEntries.count - 1 {
                    drawDivider()
                }
            }

            cursorY += 16
            ensureSpace(30)
            drawText(
                "この文書はゆびきりアプリが \(generatedAt.formatted(date: .abbreviated, time: .shortened)) に生成した記録の写しです。法的な有効性を保証するものではありません。",
                font: .systemFont(ofSize: 8),
                color: .gray
            )
        }
    }

    static func writeToTemporaryFile(_ data: Data, caseTitle: String, generatedAt: Date) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let sanitizedTitle = caseTitle.isEmpty ? "case" : caseTitle
        let fileName = "\(sanitizedTitle)-\(formatter.string(from: generatedAt)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }
}
