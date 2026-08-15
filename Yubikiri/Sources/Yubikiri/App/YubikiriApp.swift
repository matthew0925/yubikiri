import SwiftUI
import SwiftData

@main
struct YubikiriApp: App {
    @State private var purchaseManager = PurchaseManager()
    @State private var lockManager = AppLockManager()
    @Environment(\.scenePhase) private var scenePhase
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
            ZStack {
                CaseListView()
                if !lockManager.isUnlocked {
                    LockScreenView()
                        .transition(.opacity)
                }
            }
            .environment(purchaseManager)
            .environment(lockManager)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                lockManager.lockIfNeeded()
            }
        }
    }
}
