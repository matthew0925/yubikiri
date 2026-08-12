import SwiftUI
import SwiftData

struct CaseListView: View {
    @Environment(\.modelContext) private var context
    @Environment(PurchaseManager.self) private var purchaseManager
    @Query(sort: \Case.createdAt, order: .reverse) private var cases: [Case]
    @State private var isPresentingNewCase = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var isPresentingExportPaywall = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        NavigationStack {
            Group {
                if cases.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(cases) { item in
                            NavigationLink(value: item) {
                                CaseRow(caseItem: item)
                            }
                        }
                        .onDelete(perform: deleteCases)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("ゆびきり")
            .navigationDestination(for: Case.self) { CaseDetailView(caseItem: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingNewCase = true
                    } label: {
                        Label("案件を追加", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        if purchaseManager.isPremiumUnlocked {
                            exportBackup()
                        } else {
                            isPresentingExportPaywall = true
                        }
                    } label: {
                        Label("バックアップをエクスポート（有料）", systemImage: "square.and.arrow.up")
                    }
                    .disabled(cases.isEmpty)
                }
            }
            .sheet(isPresented: $isPresentingNewCase) {
                NewCaseView()
            }
            .sheet(isPresented: Binding(
                get: { exportURL != nil },
                set: { if !$0 { exportURL = nil } }
            )) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
            .alert("エクスポートに失敗しました", isPresented: .constant(exportError != nil), actions: {
                Button("OK") { exportError = nil }
            }, message: {
                Text(exportError ?? "")
            })
            .sheet(isPresented: $isPresentingExportPaywall) {
                PaywallView()
            }
            .fullScreenCover(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { isPresented in if !isPresented { hasCompletedOnboarding = true } }
            )) {
                OnboardingView()
            }
        }
    }

    private func exportBackup() {
        do {
            let now = Date()
            let bundle = ExportService.makeBundle(cases: cases, exportedAt: now)
            let data = try ExportService.encodeJSON(bundle)
            exportURL = try ExportService.writeToTemporaryFile(data, exportedAt: now)
        } catch {
            exportError = "ファイルの書き出しに失敗しました。"
        }
    }

    private func deleteCases(at offsets: IndexSet) {
        for index in offsets {
            context.delete(cases[index])
        }
    }

    private var emptyState: some View {
        ZStack {
            BrandPalette.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(BrandPalette.thread.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "text.bubble")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(BrandPalette.thread)
                }
                VStack(spacing: 6) {
                    Text("最初の約束を記録しよう")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(BrandPalette.ink)
                    Text("右上の＋から案件を作成できます")
                        .font(.subheadline)
                        .foregroundStyle(BrandPalette.ink.opacity(0.6))
                }
                Button {
                    isPresentingNewCase = true
                } label: {
                    Label("案件を作成", systemImage: "plus")
                        .font(.headline)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandPalette.thread)
            }
        }
    }
}

private struct CaseRow: View {
    let caseItem: Case

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BrandPalette.thread.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(String(caseItem.title.prefix(1)))
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(BrandPalette.thread)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(caseItem.title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                Text(caseItem.clientName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !caseItem.entries.isEmpty {
                Text("\(caseItem.entries.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandPalette.thread)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(BrandPalette.thread.opacity(0.12), in: Capsule())
            }
        }
        .padding(.vertical, 6)
    }
}
