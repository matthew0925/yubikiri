import SwiftUI

struct LockScreenView: View {
    @Environment(AppLockManager.self) private var lockManager

    var body: some View {
        ZStack {
            BrandPalette.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(BrandPalette.thread.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "faceid")
                        .font(.system(size: 40))
                        .foregroundStyle(BrandPalette.thread)
                }
                Text("ロック中")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(BrandPalette.ink)
                Button {
                    Task { await lockManager.authenticate() }
                } label: {
                    Text("認証して開く")
                        .font(.headline)
                        .frame(maxWidth: 240)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandPalette.thread)
            }
        }
        .task {
            await lockManager.authenticate()
        }
    }
}
