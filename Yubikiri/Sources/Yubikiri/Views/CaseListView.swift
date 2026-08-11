import SwiftUI
import SwiftData

struct CaseListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Case.createdAt, order: .reverse) private var cases: [Case]
    @State private var isPresentingNewCase = false
    @State private var exportURL: URL?
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            List {
                if cases.isEmpty {
                    ContentUnavailableView(
                        "案件がありません",
                        systemImage: "doc.text",
                        description: Text("右上の＋から最初の案件を作成しましょう")
                    )
                }
                ForEach(cases) { item in
                    NavigationLink(value: item) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.headline)
                            Text(item.clientName).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteCases)
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
                        exportBackup()
                    } label: {
                        Label("バックアップをエクスポート", systemImage: "square.and.arrow.up")
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
}
