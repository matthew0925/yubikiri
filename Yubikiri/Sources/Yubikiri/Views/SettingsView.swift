import SwiftUI

struct SettingsView: View {
    @Environment(AppLockManager.self) private var lockManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var lockManager = lockManager
        NavigationStack {
            ZStack {
                BrandPalette.backgroundGradient.ignoresSafeArea()
                Form {
                    Section {
                        Toggle("Face ID / パスコードでロック", isOn: $lockManager.isAppLockEnabled)
                    } footer: {
                        Text("有効にすると、アプリをバックグラウンドから復帰するたびに認証を求めます。記録データを第三者に見られないようにします。")
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
        }
    }
}
