import SwiftUI
import PhotosUI

struct NewEntryView: View {
    @Bindable var caseItem: Case
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var amountText = ""
    @State private var dueDate: Date = .now
    @State private var includeDueDate = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var attachmentData: Data?

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
                Section("納品物のスクリーンショット（任意）") {
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label(attachmentData == nil ? "画像を選択" : "画像を変更", systemImage: "photo")
                    }
                    if let attachmentData, let uiImage = UIImage(data: attachmentData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                        Button("画像を削除", role: .destructive) {
                            self.attachmentData = nil
                            pickedItem = nil
                        }
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
            .onChange(of: pickedItem) { _, newItem in
                Task {
                    attachmentData = try? await newItem?.loadTransferable(type: Data.self)
                }
            }
        }
    }

    private func save() {
        let amount = Decimal(string: amountText)
        let effectiveDueDate = includeDueDate ? dueDate : nil
        let hash = HashingService.hashEntry(body: text, amount: amount, dueDate: effectiveDueDate)
        let attachmentHash = attachmentData.map { HashingService.hashAttachment($0) }
        let entry = Entry(
            body: text,
            amount: amount,
            dueDate: effectiveDueDate,
            contentHash: hash,
            attachmentData: attachmentData,
            attachmentHash: attachmentHash
        )
        entry.parentCase = caseItem
        context.insert(entry)
        dismiss()
    }
}
