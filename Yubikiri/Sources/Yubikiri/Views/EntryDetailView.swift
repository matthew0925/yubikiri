import SwiftUI

struct EntryDetailView: View {
    @Bindable var entry: Entry
    @Environment(PurchaseManager.self) private var purchaseManager

    @State private var isAnchoring = false
    @State private var isPresentingPaywall = false
    @State private var anchoringError: String?
    @State private var isVerifying = false
    @State private var verificationError: String?

    private let anchoringService = AnchoringService()

    var body: some View {
        ZStack {
            BrandPalette.backgroundGradient.ignoresSafeArea()
            listContent
        }
        .navigationTitle("記録の詳細")
        .sheet(isPresented: $isPresentingPaywall) {
            PaywallView()
        }
    }

    private var listContent: some View {
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
                    if entry.isConfirmedOnChain {
                        Label("ブロックチェーンへの刻印を確認済み", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(BrandPalette.thread)
                    } else {
                        Label("提出済み（ブロックチェーンへの刻印は未確定）", systemImage: "clock.badge.checkmark")
                            .foregroundStyle(.orange)
                        Text("カレンダーサーバーが実際にビットコインへ刻むまで数時間〜要することがあります。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let anchoredAt = entry.anchoredAt {
                        LabeledContent("提出日時", value: anchoredAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    if !entry.isConfirmedOnChain {
                        Button {
                            Task { await checkConfirmation() }
                        } label: {
                            if isVerifying {
                                ProgressView()
                            } else {
                                Text("刻印状況を確認する")
                            }
                        }
                        .disabled(isVerifying)
                        if let lastConfirmedCheckAt = entry.lastConfirmedCheckAt {
                            Text("最終確認：\(lastConfirmedCheckAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let verificationError {
                            Text(verificationError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
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
        .scrollContentBackground(.hidden)
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

    private func checkConfirmation() async {
        isVerifying = true
        verificationError = nil
        defer { isVerifying = false }
        do {
            let result = try await anchoringService.refreshVerification(entry)
            entry.lastConfirmedCheckAt = .now
            entry.isConfirmedOnChain = result.isValid
        } catch {
            verificationError = "確認に失敗しました。通信環境を確認して再度お試しください。"
        }
    }
}
