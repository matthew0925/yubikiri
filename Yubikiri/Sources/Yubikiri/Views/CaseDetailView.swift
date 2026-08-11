import SwiftUI

struct CaseDetailView: View {
    @Bindable var caseItem: Case
    @State private var isPresentingNewEntry = false

    private var sortedEntries: [Entry] {
        caseItem.entries.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            ForEach(sortedEntries) { entry in
                NavigationLink(value: entry) {
                    EntryRow(entry: entry)
                }
            }
        }
        .navigationTitle(caseItem.title)
        .navigationDestination(for: Entry.self) { EntryDetailView(entry: $0) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingNewEntry = true
                } label: {
                    Label("記録を追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingNewEntry) {
            NewEntryView(caseItem: caseItem)
        }
    }
}

private struct EntryRow: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.body).lineLimit(2)
            HStack(spacing: 6) {
                Image(systemName: entry.isAnchored ? "checkmark.seal.fill" : "checkmark.seal")
                    .foregroundStyle(entry.isAnchored ? .green : .secondary)
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
