import Foundation
import CryptoKit

/// 記録データのSHA-256ハッシュを計算する。
/// 保存時点のバイト列を正とし、改行コードや浮動小数の丸め差でハッシュが揺れないよう
/// 正規化してから計算する。
enum HashingService {
    /// テキスト本文＋構造化フィールドを正規化した1つのバイト列に連結してハッシュ化する。
    static func hashEntry(body: String, amount: Decimal?, dueDate: Date?) -> String {
        var payload = normalizeText(body)
        payload += "\u{0}amount=" + (amount.map { "\($0)" } ?? "")
        payload += "\u{0}dueDate=" + (dueDate.map { ISO8601DateFormatter().string(from: $0) } ?? "")
        return sha256Hex(of: Data(payload.utf8))
    }

    static func hashAttachment(_ data: Data) -> String {
        sha256Hex(of: data)
    }

    private static func normalizeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
