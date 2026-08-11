import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private let steps: [(icon: String, title: String, body: String)] = [
        (
            "text.bubble",
            "「言った・言わない」を、なくす",
            "受けた条件や納品のやり取りを、その場でサッと記録。あとから見返せる形で残しておけます。"
        ),
        (
            "lock.shield",
            "記録した瞬間から、書き換え不可に",
            "確定した記録は自動で改ざん防止処理がかかります。難しい設定は一切不要です。"
        ),
        (
            "checkmark.seal",
            "ここぞという時は、外部にも刻印",
            "揉めそうな案件だけ、有料で外部の公開記録に刻印。「この時刻に存在した」と第三者にも示せます。"
        ),
    ]

    var body: some View {
        ZStack {
            BrandPalette.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 12)

                TabView(selection: $page) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(BrandPalette.thread.opacity(0.12))
                                    .frame(width: 132, height: 132)
                                Image(systemName: step.icon)
                                    .font(.system(size: 46, weight: .medium))
                                    .foregroundStyle(BrandPalette.thread)
                            }
                            Text(step.title)
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundStyle(BrandPalette.ink)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(step.body)
                                .font(.body)
                                .foregroundStyle(BrandPalette.ink.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 36)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(steps.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? BrandPalette.thread : BrandPalette.thread.opacity(0.2))
                            .frame(width: index == page ? 22 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: page)
                    }
                }

                Text("法的な助言は行いません。トラブルを未然に防ぐための記録ツールです。")
                    .font(.caption)
                    .foregroundStyle(BrandPalette.ink.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    if page < steps.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        dismiss()
                    }
                } label: {
                    Text(page < steps.count - 1 ? "次へ" : "はじめる")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandPalette.thread)
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
            }
        }
    }
}
