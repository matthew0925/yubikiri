import Foundation
import LocalAuthentication

/// Face ID / Touch ID / パスコードによるアプリロック。
/// 受注条件や納品記録という機微なデータを扱うため、無料版から提供する。
@MainActor
@Observable
final class AppLockManager {
    private static let defaultsKey = "isAppLockEnabled"

    var isAppLockEnabled: Bool {
        didSet {
            guard isAppLockEnabled != oldValue else { return }
            UserDefaults.standard.set(isAppLockEnabled, forKey: Self.defaultsKey)
        }
    }

    private(set) var isUnlocked = true

    init() {
        isAppLockEnabled = UserDefaults.standard.bool(forKey: Self.defaultsKey)
    }

    func lockIfNeeded() {
        guard isAppLockEnabled else { return }
        isUnlocked = false
    }

    func authenticate() async {
        guard isAppLockEnabled else {
            isUnlocked = true
            return
        }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // 生体認証・パスコードが未設定の端末ではロックせず通す
            isUnlocked = true
            return
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "記録を表示するために認証してください"
            )
            isUnlocked = success
        } catch {
            isUnlocked = false
        }
    }
}
