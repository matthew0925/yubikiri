import Foundation
import SwiftData

/// 案件：クライアント単位で記録をまとめる単位
@Model
final class Case {
    var title: String
    var clientName: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Entry.parentCase)
    var entries: [Entry] = []

    init(title: String, clientName: String, createdAt: Date = .now) {
        self.title = title
        self.clientName = clientName
        self.createdAt = createdAt
    }
}
