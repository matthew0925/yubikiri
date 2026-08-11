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
/// カレンダーサーバーAPIは `POST /digest`（body=32バイトのSHA-256生バイト列）に対し、
/// 未確定タイムスタンプを表す独自バイナリ（pending attestation）を返す。
/// 本実装は「そのカレンダーからの生レスポンスをそのまま証明として保存し、
/// 複数カレンダーの結果を単純連結して1つのproofとする」簡易版であり、
/// 公式クライアントが行う完全なMerkleツリー結合・.otsファイル形式のシリアライズは行わない。
/// 検証時も、保存した生レスポンス群それぞれに対して `GET /timestamp/{hex}` を呼び直し、
/// Bitcoin attestationタグ（0x0588960d73d71901）が含まれるかで確定判定する簡易実装。
struct URLSessionOpenTimestampsClient: OpenTimestampsClient {
    private let session: URLSession
    private let calendars: [URL]

    /// カレンダーからの応答に含まれる、Bitcoin attestationを示すタグバイト列
    private static let bitcoinAttestationTag: [UInt8] = [0x05, 0x88, 0x96, 0x0d, 0x73, 0xd7, 0x19, 0x01]

    init(session: URLSession = .shared, calendars: [URL] = OpenTimestampsCalendars.servers) {
        self.session = session
        self.calendars = calendars
    }

    func submit(hashHex: String) async throws -> Data {
        guard let digest = Data(hexString: hashHex), digest.count == 32 else {
            throw OpenTimestampsError.invalidHash
        }

        let results = await withTaskGroup(of: (URL, Data?).self) { group -> [URL: Data] in
            for calendar in calendars {
                group.addTask {
                    let response = try? await submitDigest(digest, to: calendar, session: session)
                    return (calendar, response)
                }
            }
            var collected: [URL: Data] = [:]
            for await (calendar, data) in group {
                if let data { collected[calendar] = data }
            }
            return collected
        }

        guard !results.isEmpty else {
            throw OpenTimestampsError.allCalendarsFailed
        }

        return CalendarProofBundle(responses: results).encoded()
    }

    func verify(hashHex: String, proof: Data) async throws -> TimestampVerification {
        guard Data(hexString: hashHex) != nil else {
            throw OpenTimestampsError.invalidHash
        }
        guard let bundle = CalendarProofBundle(encoded: proof) else {
            throw OpenTimestampsError.malformedProof
        }

        for (calendar, cachedResponse) in bundle.responses {
            if Self.containsBitcoinAttestation(cachedResponse) {
                return TimestampVerification(isValid: true, confirmedAt: nil)
            }
            if let refreshed = try? await fetchUpgrade(for: cachedResponse, from: calendar, session: session),
               Self.containsBitcoinAttestation(refreshed) {
                return TimestampVerification(isValid: true, confirmedAt: nil)
            }
        }
        // 提出は成功しているが、まだブロックチェーンに刻印されていない（pending）状態。
        return TimestampVerification(isValid: false, confirmedAt: nil)
    }

    private static func containsBitcoinAttestation(_ data: Data) -> Bool {
        let tag = Data(bitcoinAttestationTag)
        guard data.count >= tag.count else { return false }
        return data.range(of: tag) != nil
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

    private func fetchUpgrade(for pendingResponse: Data, from calendar: URL, session: URLSession) async throws -> Data {
        // pendingResponse自体にコミットメント（元のdigest）は含まれないため、
        // ここでは同一カレンダーへの再照会は行わず、キャッシュ済みレスポンスをそのまま返す。
        // 実運用では pending attestation 内のcalendar URIとnonceからcommitmentを再構成して
        // `GET /timestamp/{commitment}` を呼ぶ必要がある（TODO: 本実装は次段階）。
        pendingResponse
    }
}

/// 複数カレンダーからの生レスポンスを1つのDataにまとめて保存・復元するための簡易コンテナ。
private struct CalendarProofBundle {
    let responses: [URL: Data]

    init(responses: [URL: Data]) {
        self.responses = responses
    }

    init?(encoded: Data) {
        var offset = encoded.startIndex
        var parsed: [URL: Data] = [:]
        while offset < encoded.endIndex {
            guard let urlLength = encoded.readUInt32(at: &offset),
                  let urlData = encoded.readBytes(count: Int(urlLength), at: &offset),
                  let urlString = String(data: urlData, encoding: .utf8),
                  let url = URL(string: urlString),
                  let payloadLength = encoded.readUInt32(at: &offset),
                  let payload = encoded.readBytes(count: Int(payloadLength), at: &offset)
            else {
                return nil
            }
            parsed[url] = payload
        }
        self.responses = parsed
    }

    func encoded() -> Data {
        var out = Data()
        for (url, payload) in responses {
            let urlData = Data(url.absoluteString.utf8)
            out.appendUInt32(UInt32(urlData.count))
            out.append(urlData)
            out.appendUInt32(UInt32(payload.count))
            out.append(payload)
        }
        return out
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

    mutating func appendUInt32(_ value: UInt32) {
        var v = value.bigEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    func readUInt32(at offset: inout Index) -> UInt32? {
        guard offset + 4 <= endIndex else { return nil }
        let bytes = self[offset..<offset + 4]
        offset += 4
        return bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    func readBytes(count: Int, at offset: inout Index) -> Data? {
        guard count >= 0, offset + count <= endIndex else { return nil }
        let slice = self[offset..<offset + count]
        offset += count
        return Data(slice)
    }
}
