import Foundation

/// SwiftDataのストアファイルを配置し、NSFileProtectionCompleteを付与するための補助。
/// 端末ロック中はストアファイルが復号不可になり、記録データを保護する。
enum SecureStoreLocation {
    static let storeFileName = "yubikiri.store"

    static var storeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent(storeFileName)
    }

    /// ストア作成後に呼び、ディレクトリとファイルへ完全保護属性を付与する。
    static func applyCompleteFileProtection() {
        let directory = storeURL.deletingLastPathComponent()
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: directory.path
        )
        for suffix in ["", "-wal", "-shm"] {
            let path = storeURL.path + suffix
            guard fileManager.fileExists(atPath: path) else { continue }
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: path
            )
        }
    }
}
