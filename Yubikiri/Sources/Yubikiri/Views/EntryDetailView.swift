import SwiftUI

struct EntryDetailView: View {
    let entry: Entry

    var body: some View {
        List {
            Section("内容") {
                Text(entry.body)
            }
            Section("条件") {
                if let amount = entry.amount {
                    LabeledContent("金額", value: "\(amount)")
                }
                if let dueDate = entry.dueDate {
                    LabeledContent("納期", value: dueDate.formatted(date: .abbreviated, time: .omitted))
                }
                LabeledContent("記録日時", value: entry.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            Section("改ざん検証") {
                LabeledContent("SHA-256") {
                    Text(entry.contentHash)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                if entry.isAnchored {
                    Label("ブロックチェーンに刻印済み", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("端末内保存のみ（未刻印）", systemImage: "checkmark.seal")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("記録の詳細")
    }
}
