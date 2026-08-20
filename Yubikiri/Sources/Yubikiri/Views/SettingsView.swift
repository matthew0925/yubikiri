import SwiftUI

struct SettingsView: View {
    @Environment(AppLockManager.self) private var lockManager
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var isPresentingPaywall = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    private static let privacyPolicyURL = URL(string: "https://matthew0925.github.io/yubikiri/privacy-policy.html")!
    private static let contactURL = URL(string: "mailto:gourcuffxd@gmail.com")!

    var body: some View {
        @Bindable var lockManager = lockManager
        NavigationStack {
            ZStack {
                BrandPalette.backgroundGradient.ignoresSafeArea()
                Form {
                    Section {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(BrandPalette.thread.opacity(0.12))
                                    .frame(width: 76, height: 76)
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(BrandPalette.thread)
                            }
                            Text("ゆびきり")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(BrandPalette.ink)
                            Text("約束は、消えない。")
                                .font(.caption)
                                .foregroundStyle(BrandPalette.ink.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                    }
                    .listRowInsets(EdgeInsets())

                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: purchaseManager.isPremiumUnlocked ? "checkmark.seal.fill" : "checkmark.seal")
                                .foregroundStyle(BrandPalette.thread)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(purchaseManager.isPremiumUnlocked ? "有料機能：解放済み" : "有料機能：未解放")
                                    .font(.subheadline.weight(.semibold))
                                Text("外部への刻印・証跡PDF・バックアップ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if !purchaseManager.isPremiumUnlocked {
                            Button {
                                isPresentingPaywall = true
                            } label: {
                                Text("有料機能の詳細を見る")
                            }
                        }
                        Button {
                            Task { await restore() }
                        } label: {
                            if isRestoring {
                                ProgressView()
                            } else {
                                Text("購入を復元")
                            }
                        }
                        .disabled(isRestoring)
                        if let restoreMessage {
                            Text(restoreMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("購入")
                    }
                    .listRowBackground(Color.white.opacity(0.7))

                    Section {
                        Toggle("Face ID / パスコードでロック", isOn: $lockManager.isAppLockEnabled)
                    } header: {
                        Text("セキュリティ")
                    } footer: {
                        Text("有効にすると、アプリをバックグラウンドから復帰するたびに認証を求めます。記録データを第三者に見られないようにします。")
                    }
                    .listRowBackground(Color.white.opacity(0.7))

                    Section {
                        Button {
                            openURL(Self.privacyPolicyURL)
                        } label: {
                            LabeledContent("プライバシーポリシー") {
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                            }
                        }
                        Button {
                            openURL(Self.contactURL)
                        } label: {
                            LabeledContent("お問い合わせ") {
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                            }
                        }
                    } header: {
                        Text("サポート")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(BrandPalette.ink)
                    .listRowBackground(Color.white.opacity(0.7))

                    Section {
                        LabeledContent("バージョン", value: appVersionString)
                    }
                    .listRowBackground(Color.white.opacity(0.7))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $isPresentingPaywall) {
                PaywallView()
            }
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func restore() async {
        isRestoring = true
        restoreMessage = nil
        defer { isRestoring = false }
        do {
            try await purchaseManager.restorePurchases()
            restoreMessage = purchaseManager.isPremiumUnlocked ? "購入を復元しました。" : "復元できる購入が見つかりませんでした。"
        } catch {
            restoreMessage = "復元に失敗しました。時間をおいて再度お試しください。"
        }
    }
}
