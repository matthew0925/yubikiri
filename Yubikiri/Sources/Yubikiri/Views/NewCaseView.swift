import SwiftUI

struct NewCaseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var clientName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                BrandPalette.backgroundGradient.ignoresSafeArea()
                Form {
                    Section {
                        TextField("案件名（例：Webサイト制作）", text: $title)
                        TextField("クライアント名", text: $clientName)
                    }
                    .listRowBackground(Color.white.opacity(0.7))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("新しい案件")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        let newCase = Case(title: title, clientName: clientName)
                        context.insert(newCase)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
