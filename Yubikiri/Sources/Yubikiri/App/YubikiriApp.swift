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
            // ブランド配色（生成り背景＋焦茶文字）がダークモード非対応のため、
            // システムのダーク切り替えで文字が読めなくなるのを避けライト固定にする。
            .preferredColorScheme(.light)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                lockManager.lockIfNeeded()
            }
        }
    }
}
