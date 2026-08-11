import Foundation
import SwiftData

/// 記録：条件・やり取り・納品物などの1件のスナップショット
@Model
final class Entry {
    var body: String
    var amount: Decimal?
    var dueDate: Date?
    var createdAt: Date
    /// 記録確定時点のバイト列から計算したSHA-256（16進文字列）
    var contentHash: String
    /// 有料版でOpenTimestampsに刻印した際の .ots 証明ファイル（未刻印はnil）
    var otsProofData: Data?
    var anchoredAt: Date?

    /// 納品物のスクリーンショット等（任意）。画像バイト列自体がハッシュ対象。
    @Attribute(.externalStorage)
    var attachmentData: Data?
    var attachmentHash: String?

    var parentCase: Case?

    init(
        body: String,
        amount: Decimal? = nil,
        dueDate: Date? = nil,
        createdAt: Date = .now,
        contentHash: String,
        attachmentData: Data? = nil,
        attachmentHash: String? = nil
    ) {
        self.body = body
        self.amount = amount
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.contentHash = contentHash
        self.attachmentData = attachmentData
        self.attachmentHash = attachmentHash
    }

    var isAnchored: Bool { otsProofData != nil }
}
