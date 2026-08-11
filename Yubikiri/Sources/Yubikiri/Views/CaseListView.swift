import SwiftUI
import SwiftData

struct CaseListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Case.createdAt, order: .reverse) private var cases: [Case]
    @State private var isPresentingNewCase = false

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
            }
            .sheet(isPresented: $isPresentingNewCase) {
                NewCaseView()
            }
        }
    }

    private func deleteCases(at offsets: IndexSet) {
        for index in offsets {
            context.delete(cases[index])
        }
    }
}
