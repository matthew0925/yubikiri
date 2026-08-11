import SwiftUI

struct CaseDetailView: View {
    @Bindable var caseItem: Case
    @State private var isPresentingNewEntry = false

    private var sortedEntries: [Entry] {
        caseItem.entries.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Group {
            if sortedEntries.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sortedEntries) { entry in
                        NavigationLink(value: entry) {
                            EntryRow(entry: entry)
                        }
                    }
                }
                .listStyle(.plain)
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

    private var emptyState: some View {
        ZStack {
            BrandPalette.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "note.text")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(BrandPalette.thread)
                Text("まだ記録がありません")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(BrandPalette.ink)
                Text("右上の＋からこの案件の記録を追加できます")
                    .font(.subheadline)
                    .foregroundStyle(BrandPalette.ink.opacity(0.6))
            }
        }
    }
}

private struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.isAnchored ? "checkmark.seal.fill" : "checkmark.seal")
                .foregroundStyle(entry.isAnchored ? BrandPalette.thread : .secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.body).lineLimit(2)
                    .font(.system(.body, design: .rounded))
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
