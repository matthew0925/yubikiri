import Foundation

/// OpenTimestampsの公開カレンダーサーバーへハッシュを提出し、.ots証明を取得・検証するクライアント。
/// v1では複数カレンダーサーバーへ冗長化して提出する想定（特定サービス依存を避けるため）。
protocol OpenTimestampsClient {
    /// ハッシュ値を公開カレンダーサーバーに提出し、標準の.ots形式（DetachedTimestampFile）で
    /// 証明を組み立てて返す。ブロックチェーンへの実刻印には数時間〜要するため、
    /// 返るのは「提出済み」の未確定証明（pending attestation）。
    func submit(hashHex: String) async throws -> Data

    /// 保存済みの.ots証明を検証する。各カレンダーへ`GET /timestamp/{hex}`で問い合わせ、
    /// ビットコインへの刻印が確定していれば取り込んだ証明とともに結果を返す。
    func verify(hashHex: String, proof: Data) async throws -> TimestampVerification
}

struct TimestampVerification {
    let isValid: Bool
    /// ブロックチェーン上で確認できた場合の刻印時刻（未確定の場合はnil）
    let confirmedAt: Date?
    /// 確定情報を取り込んだ場合の更新後.otsデータ（変化がなければnil）
    let upgradedProof: Data?
}

enum OpenTimestampsError: Error {
    case invalidHash
    case allCalendarsFailed
    case malformedProof
}

/// 既定のカレンダーサーバー群。単一障害点を避けるため複数へ提出する。
enum OpenTimestampsCalendars {
    static let servers: [URL] = [
        URL(string: "https://alice.btc.calendar.opentimestamps.org")!,
        URL(string: "https://bob.btc.calendar.opentimestamps.org")!,
        URL(string: "https://finney.calendar.eternitywall.com")!,
    ]
}

/// OpenTimestampsカレンダーサーバーのHTTP APIを叩く実装。
///
/// - 提出: `POST /digest`（body=32バイトのSHA-256生ダイジェスト）に対し、各カレンダーは
///   そのダイジェストを起点とするTimestamp木（pending attestation付き）を返す。
///   複数カレンダーの木を`OTSTimestamp.merge`で合流させ、`OTSDetachedFile`として
///   シリアライズすることで、公式クライアントや他の検証ツールと互換性のある
///   正式な`.ots`バイナリを生成する。
/// - 検証: 保存済み`.ots`をパースし、各pending attestationのURIに対して
///   `GET /timestamp/{hex}` で刻印状況を問い合わせる。ビットコインへの刻印が
///   見つかれば証明ツリーに取り込み、確定として扱う。
struct URLSessionOpenTimestampsClient: OpenTimestampsClient {
    private let session: URLSession
    private let calendars: [URL]

    init(session: URLSession = .shared, calendars: [URL] = OpenTimestampsCalendars.servers) {
        self.session = session
        self.calendars = calendars
    }

    func submit(hashHex: String) async throws -> Data {
        guard let digest = Data(hexString: hashHex), digest.count == 32 else {
            throw OpenTimestampsError.invalidHash
        }

        let responses = await withTaskGroup(of: Data?.self) { group -> [Data] in
            for calendar in calendars {
                group.addTask {
                    try? await submitDigest(digest, to: calendar, session: session)
                }
            }
            var collected: [Data] = []
            for await data in group {
                if let data { collected.append(data) }
            }
            return collected
        }

        guard !responses.isEmpty else {
            throw OpenTimestampsError.allCalendarsFailed
        }

        let root = OTSTimestamp(msg: digest)
        for responseData in responses {
            var offset = 0
            guard let subTree = try? OTSTimestamp.deserialize(from: responseData, offset: &offset, msg: digest) else {
                continue
            }
            try? root.merge(subTree)
        }
        guard !root.attestations.isEmpty || !root.ops.isEmpty else {
            throw OpenTimestampsError.allCalendarsFailed
        }

        return try OTSDetachedFile(timestamp: root).serialize()
    }

    func verify(hashHex: String, proof: Data) async throws -> TimestampVerification {
        guard let digest = Data(hexString: hashHex), digest.count == 32 else {
            throw OpenTimestampsError.invalidHash
        }
        guard let file = try? OTSDetachedFile.deserialize(proof), file.timestamp.msg == digest else {
            throw OpenTimestampsError.malformedProof
        }

        var didUpgrade = false
        for (node, attestation) in file.timestamp.allAttestationNodes() {
            guard case .pending(let uri) = attestation else { continue }
            guard let calendarURL = URL(string: "https://\(uri)") ?? URL(string: uri) else { continue }
            guard let upgradeData = try? await fetchUpgrade(digest: node.msg, from: calendarURL, session: session) else { continue }
            var offset = 0
            guard let upgradedTree = try? OTSTimestamp.deserialize(from: upgradeData, offset: &offset, msg: node.msg) else { continue }
            if (try? node.merge(upgradedTree)) != nil {
                didUpgrade = true
            }
        }

        let isConfirmed = file.timestamp.allAttestations().contains { _, attestation in
            if case .bitcoin = attestation { return true }
            return false
        }

        let upgradedProof: Data? = didUpgrade ? try? OTSDetachedFile(timestamp: file.timestamp).serialize() : nil
        return TimestampVerification(isValid: isConfirmed, confirmedAt: nil, upgradedProof: upgradedProof)
    }

    private func submitDigest(_ digest: Data, to calendar: URL, session: URLSession) async throws -> Data {
        var request = URLRequest(url: calendar.appendingPathComponent("digest"))
        request.httpMethod = "POST"
        request.httpBody = digest
        request.setValue("application/x-octet-stream", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OpenTimestampsError.allCalendarsFailed
        }
        return data
    }

    private func fetchUpgrade(digest: Data, from calendar: URL, session: URLSession) async throws -> Data {
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let url = calendar.appendingPathComponent("timestamp").appendingPathComponent(hex)
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OpenTimestampsError.allCalendarsFailed
        }
        return data
    }
}

private extension Data {
    init?(hexString: String) {
        let chars = Array(hexString)
        guard chars.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(chars.count / 2)
        var index = 0
        while index < chars.count {
            guard let byte = UInt8(String(chars[index...index + 1]), radix: 16) else { return nil }
            bytes.append(byte)
            index += 2
        }
        self = Data(bytes)
    }
}
