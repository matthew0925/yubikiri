import SwiftUI
import SwiftData

@main
struct YubikiriApp: App {
    @State private var purchaseManager = PurchaseManager()
    private let modelContainer: ModelContainer

    init() {
        SecureStoreLocation.ensureDirectoryExists()
        let schema = Schema([Case.self, Entry.self])
        let configuration = ModelConfiguration(schema: schema, url: SecureStoreLocation.storeURL)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("モデルコンテナの初期化に失敗しました: \(error)")
        }
        SecureStoreLocation.applyCompleteFileProtection()
    }

    var body: some Scene {
        WindowGroup {
            CaseListView()
                .environment(purchaseManager)
        }
        .modelContainer(modelContainer)
    }
}
