import SwiftUI

struct EntryDetailView: View {
    @Bindable var entry: Entry
    @Environment(PurchaseManager.self) private var purchaseManager

    @State private var isAnchoring = false
    @State private var isPresentingPaywall = false
    @State private var anchoringError: String?

    private let anchoringService = AnchoringService()

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
            if let attachmentData = entry.attachmentData, let uiImage = UIImage(data: attachmentData) {
                Section("添付画像") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                    if let attachmentHash = entry.attachmentHash {
                        LabeledContent("画像SHA-256") {
                            Text(attachmentHash)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            Section("改ざん検証") {
                LabeledContent("SHA-256") {
                    Text(entry.contentHash)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                if entry.isAnchored {
                    Label("ブロックチェーンに提出済み", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    if let anchoredAt = entry.anchoredAt {
                        LabeledContent("提出日時", value: anchoredAt.formatted(date: .abbreviated, time: .shortened))
                    }
                } else {
                    Label("端末内保存のみ（未刻印）", systemImage: "checkmark.seal")
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await startAnchoring() }
                    } label: {
                        if isAnchoring {
                            ProgressView()
                        } else {
                            Text("外部に刻印する（有料）")
                        }
                    }
                    .disabled(isAnchoring)
                    if let anchoringError {
                        Text(anchoringError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("記録の詳細")
        .sheet(isPresented: $isPresentingPaywall) {
            PaywallView()
        }
    }

    private func startAnchoring() async {
        guard purchaseManager.isAnchoringUnlocked else {
            isPresentingPaywall = true
            return
        }
        isAnchoring = true
        anchoringError = nil
        defer { isAnchoring = false }
        do {
            try await anchoringService.anchor(entry)
        } catch {
            anchoringError = "刻印の提出に失敗しました。通信環境を確認して再度お試しください。"
        }
    }
}
