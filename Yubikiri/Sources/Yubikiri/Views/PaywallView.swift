import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("外部アンカリングを解放")
                    .font(.title2.bold())
                Text("記録のハッシュ値をOpenTimestamps経由でビットコインブロックチェーンに刻印し、第三者証明力を付与します。買い切りで、以降すべての記録に無制限に使えます。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if let product = purchaseManager.products.first {
                    Button {
                        Task { await purchase() }
                    } label: {
                        if isPurchasing {
                            ProgressView()
                        } else {
                            Text("\(product.displayName) — \(product.displayPrice)")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPurchasing)
                    .padding(.horizontal)
                } else {
                    ProgressView("読み込み中…")
                }

                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
            }
            .padding()
            .navigationTitle("有料版")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                await purchaseManager.loadProducts()
            }
        }
    }

    private func purchase() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            try await purchaseManager.purchaseAnchoring()
            if purchaseManager.isAnchoringUnlocked {
                dismiss()
            }
        } catch {
            errorMessage = "購入処理に失敗しました。時間をおいて再度お試しください。"
        }
    }
}
