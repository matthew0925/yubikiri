import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                BrandPalette.backgroundGradient.ignoresSafeArea()
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(BrandPalette.thread.opacity(0.12))
                            .frame(width: 100, height: 100)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(BrandPalette.thread)
                    }
                    Text("外部アンカリングを解放")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(BrandPalette.ink)
                    Text("記録のハッシュ値をOpenTimestamps経由でビットコインブロックチェーンに刻印し、「この時刻に存在した」ことを外部から確認できるようにします。法的な有効性を保証するものではありませんが、交渉やトラブル予防のための記録として役立ちます。買い切りで、以降すべての記録に無制限に使えます。")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(BrandPalette.ink.opacity(0.65))
                        .padding(.horizontal)

                    if let product = purchaseManager.products.first {
                        Button {
                            Task { await purchase() }
                        } label: {
                            if isPurchasing {
                                ProgressView()
                            } else {
                                Text("\(product.displayName) — \(product.displayPrice)")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BrandPalette.thread)
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
            }
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
