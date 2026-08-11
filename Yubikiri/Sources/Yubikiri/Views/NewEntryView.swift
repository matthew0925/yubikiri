import SwiftUI

struct NewEntryView: View {
    @Bindable var caseItem: Case
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var amountText = ""
    @State private var dueDate: Date = .now
    @State private var includeDueDate = false

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextEditor(text: $text).frame(minHeight: 120)
                }
                Section("条件（任意）") {
                    TextField("金額", text: $amountText)
                        .keyboardType(.decimalPad)
                    Toggle("納期を指定", isOn: $includeDueDate)
                    if includeDueDate {
                        DatePicker("納期", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("記録を確定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("確定") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let amount = Decimal(string: amountText)
        let effectiveDueDate = includeDueDate ? dueDate : nil
        let hash = HashingService.hashEntry(body: text, amount: amount, dueDate: effectiveDueDate)
        let entry = Entry(body: text, amount: amount, dueDate: effectiveDueDate, contentHash: hash)
        entry.parentCase = caseItem
        context.insert(entry)
        dismiss()
    }
}
