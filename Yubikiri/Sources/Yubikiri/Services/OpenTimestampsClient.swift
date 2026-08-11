import Foundation

/// OpenTimestampsの公開カレンダーサーバーへハッシュを提出し、.ots証明を取得・検証するクライアント。
/// v1では複数カレンダーサーバーへ冗長化して提出する想定（特定サービス依存を避けるため）。
protocol OpenTimestampsClient {
    /// ハッシュ値を公開カレンダーサーバーに提出し、.ots証明ファイルを取得する。
    /// ブロックチェーンへの実刻印には数時間〜要するため、返るのは「提出済み」の未確定証明。
    func submit(hashHex: String) async throws -> Data

    /// 保存済みの.ots証明が、指定ハッシュに対して有効かを検証する。
    func verify(hashHex: String, proof: Data) async throws -> TimestampVerification
}

struct TimestampVerification {
    let isValid: Bool
    /// ブロックチェーン上で確認できた場合の刻印時刻（未確定の場合はnil）
    let confirmedAt: Date?
}

enum OpenTimestampsError: Error {
    case submissionFailed
    case invalidProof
}

/// 既定のカレンダーサーバー群。単一障害点を避けるため複数へ提出する。
enum OpenTimestampsCalendars {
    static let servers: [URL] = [
        URL(string: "https://alice.btc.calendar.opentimestamps.org")!,
        URL(string: "https://bob.btc.calendar.opentimestamps.org")!,
        URL(string: "https://finney.calendar.eternitywall.com")!,
    ]
}
