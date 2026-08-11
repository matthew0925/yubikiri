import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private let steps: [(icon: String, title: String, body: String)] = [
        (
            "text.book.closed",
            "口約束を、その場で記録",
            "受注条件や納品のやり取りを、案件ごとにテキストで残します。難しい入力は不要、メモ感覚で使えます。"
        ),
        (
            "checkmark.seal",
            "記録した瞬間にハッシュ化",
            "確定した記録はSHA-256で自動的にハッシュ値が計算され、端末内に保存されます。ここまでは無料です。"
        ),
        (
            "link.badge.plus",
            "必要なときだけ外部に刻印",
            "「言った／言わない」が起きそうな記録だけ、有料でOpenTimestamps経由のブロックチェーン刻印を追加できます。"
        ),
    ]

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $page) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 20) {
                        Image(systemName: step.icon)
                            .font(.system(size: 56))
                            .foregroundStyle(.tint)
                        Text(step.title)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text(step.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)

            Text("法的な助言は行いません。あくまで「交渉・トラブル予防のための記録」を目的としたツールです。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                if page < steps.count - 1 {
                    page += 1
                } else {
                    dismiss()
                }
            } label: {
                Text(page < steps.count - 1 ? "次へ" : "はじめる")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .interactiveDismissDisabled(false)
    }
}
