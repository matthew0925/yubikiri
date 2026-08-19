import Foundation
import CryptoKit

/// OpenTimestamps公式クライアント(python-opentimestamps)のバイナリ形式に準拠した
/// シリアライズ/デシリアライズ実装。他のOTSツール（opentimestamps-client等）で
/// 開ける正式な `.ots` ファイルを生成・検証できる。
///
/// 仕様出典: https://github.com/opentimestamps/python-opentimestamps
///   core/timestamp.py（Timestamp/DetachedTimestampFile）
///   core/op.py（Op各種のTAGバイト）
///   core/notary.py（TimeAttestation各種のTAGバイト）
///   core/serialize.py（LEB128 varuint/varbytes）
enum OTSError: Error {
    case malformed(String)
    case unsupportedVersion
}

enum OTSVarint {
    static func encode(_ value: Int) -> Data {
        var v = UInt64(value)
        var out = Data()
        if v == 0 {
            out.append(0)
            return out
        }
        while v != 0 {
            var b = UInt8(v & 0x7f)
            if v > 0x7f { b |= 0x80 }
            out.append(b)
            if v <= 0x7f { break }
            v >>= 7
        }
        return out
    }

    static func decode(_ data: Data, offset: inout Int) throws -> Int {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            guard offset < data.count else { throw OTSError.malformed("varint truncated") }
            let b = data[data.startIndex + offset]
            offset += 1
            value |= UInt64(b & 0x7f) << shift
            if b & 0x80 == 0 { break }
            shift += 7
        }
        return Int(value)
    }
}

private extension Data {
    func readBytes(_ count: Int, offset: inout Int) throws -> Data {
        guard count >= 0, offset + count <= self.count else { throw OTSError.malformed("read past end") }
        let start = startIndex + offset
        let slice = self[start..<start + count]
        offset += count
        return Data(slice)
    }

    func readVarbytes(offset: inout Int, maxLength: Int = 8192) throws -> Data {
        let length = try OTSVarint.decode(self, offset: &offset)
        guard length >= 0, length <= maxLength else { throw OTSError.malformed("varbytes length out of range") }
        return try readBytes(length, offset: &offset)
    }

    func readByte(offset: inout Int) throws -> UInt8 {
        guard let byte = try readBytes(1, offset: &offset).first else {
            throw OTSError.malformed("read past end")
        }
        return byte
    }
}

/// タイムスタンプ証明ツリーの1エッジ（操作）。
enum OTSOp: Hashable {
    case sha1
    case ripemd160
    case sha256
    case keccak256
    case append(Data)
    case prepend(Data)
    case reverse
    case hexlify

    var tag: UInt8 {
        switch self {
        case .sha1: return 0x02
        case .ripemd160: return 0x03
        case .sha256: return 0x08
        case .keccak256: return 0x67
        case .append: return 0xf0
        case .prepend: return 0xf1
        case .reverse: return 0xf2
        case .hexlify: return 0xf3
        }
    }

    /// ソート用の比較キー（TAGバイト、続いて引数バイト列）
    var sortKey: (UInt8, Data) {
        switch self {
        case .append(let d), .prepend(let d): return (tag, d)
        default: return (tag, Data())
        }
    }

    func apply(to msg: Data) throws -> Data {
        switch self {
        case .sha1:
            return Data(Insecure.SHA1.hash(data: msg))
        case .ripemd160:
            // RIPEMD160は標準Cryptoフレームワークに無いため、タイムスタンプの
            // 検証パス上で登場した場合のみ扱う（自前生成では使用しない）。
            throw OTSError.malformed("ripemd160 not supported")
        case .sha256:
            return Data(SHA256.hash(data: msg))
        case .keccak256:
            throw OTSError.malformed("keccak256 not supported")
        case .append(let suffix):
            return msg + suffix
        case .prepend(let prefix):
            return prefix + msg
        case .reverse:
            return Data(msg.reversed())
        case .hexlify:
            return Data(msg.map { String(format: "%02x", $0) }.joined().utf8)
        }
    }

    func serialize(into data: inout Data) {
        data.append(tag)
        switch self {
        case .append(let d), .prepend(let d):
            data.append(OTSVarint.encode(d.count))
            data.append(d)
        default:
            break
        }
    }

    static func deserialize(tag: UInt8, from bytes: Data, offset: inout Int) throws -> OTSOp {
        switch tag {
        case 0x02: return .sha1
        case 0x03: return .ripemd160
        case 0x08: return .sha256
        case 0x67: return .keccak256
        case 0xf2: return .reverse
        case 0xf3: return .hexlify
        case 0xf0:
            let arg = try bytes.readVarbytes(offset: &offset, maxLength: 4096)
            return .append(arg)
        case 0xf1:
            let arg = try bytes.readVarbytes(offset: &offset, maxLength: 4096)
            return .prepend(arg)
        default:
            throw OTSError.malformed("unknown op tag 0x\(String(format: "%02x", tag))")
        }
    }
}

/// カレンダーからの証明が経由する「刻印」の種類。
enum OTSAttestation: Hashable {
    case pending(uri: String)
    case bitcoin(height: Int)
    case litecoin(height: Int)
    case unknown(tag: Data, payload: Data)

    static let pendingTag = Data([0x83, 0xdf, 0xe3, 0x0d, 0x2e, 0xf9, 0x0c, 0x8e])
    static let bitcoinTag = Data([0x05, 0x88, 0x96, 0x0d, 0x73, 0xd7, 0x19, 0x01])
    static let litecoinTag = Data([0x06, 0x86, 0x9a, 0x0d, 0x73, 0xd7, 0x1b, 0x45])

    var tag: Data {
        switch self {
        case .pending: return Self.pendingTag
        case .bitcoin: return Self.bitcoinTag
        case .litecoin: return Self.litecoinTag
        case .unknown(let tag, _): return tag
        }
    }

    private func serializePayload() -> Data {
        switch self {
        case .pending(let uri):
            var out = Data()
            let uriData = Data(uri.utf8)
            out.append(OTSVarint.encode(uriData.count))
            out.append(uriData)
            return out
        case .bitcoin(let height), .litecoin(let height):
            return OTSVarint.encode(height)
        case .unknown(_, let payload):
            return payload
        }
    }

    func serialize(into data: inout Data) {
        data.append(tag)
        let payload = serializePayload()
        data.append(OTSVarint.encode(payload.count))
        data.append(payload)
    }

    static func deserialize(from bytes: Data, offset: inout Int) throws -> OTSAttestation {
        let tag = try bytes.readBytes(8, offset: &offset)
        let payload = try bytes.readVarbytes(offset: &offset)
        var payloadOffset = 0
        switch tag {
        case pendingTag:
            let uriData = try payload.readVarbytes(offset: &payloadOffset, maxLength: 1000)
            guard let uri = String(data: uriData, encoding: .utf8) else {
                throw OTSError.malformed("invalid pending attestation URI")
            }
            return .pending(uri: uri)
        case bitcoinTag:
            let height = try OTSVarint.decode(payload, offset: &payloadOffset)
            return .bitcoin(height: height)
        case litecoinTag:
            let height = try OTSVarint.decode(payload, offset: &payloadOffset)
            return .litecoin(height: height)
        default:
            return .unknown(tag: tag, payload: payload)
        }
    }
}

/// 証明ツリー（メッセージ→操作→…→刻印、の木構造）。
final class OTSTimestamp {
    let msg: Data
    var attestations: Set<OTSAttestation> = []
    var ops: [OTSOp: OTSTimestamp] = [:]

    init(msg: Data) {
        self.msg = msg
    }

    /// 同じmsgに対する別のTimestamp木を合流させる（複数カレンダーの証明を1つにまとめる）。
    func merge(_ other: OTSTimestamp) throws {
        guard msg == other.msg else { throw OTSError.malformed("cannot merge timestamps for different messages") }
        attestations.formUnion(other.attestations)
        for (op, otherSub) in other.ops {
            if let existing = ops[op] {
                try existing.merge(otherSub)
            } else {
                ops[op] = otherSub
            }
        }
    }

    func allAttestations() -> [(Data, OTSAttestation)] {
        var result: [(Data, OTSAttestation)] = attestations.map { (msg, $0) }
        for sub in ops.values {
            result.append(contentsOf: sub.allAttestations())
        }
        return result
    }

    /// 各刻印が実際に紐づいているツリー上のノード（参照）と刻印のペア。
    /// pending刻印をupgradeで置き換える際、このノードに直接mergeできる。
    func allAttestationNodes() -> [(OTSTimestamp, OTSAttestation)] {
        var result: [(OTSTimestamp, OTSAttestation)] = attestations.map { (self, $0) }
        for sub in ops.values {
            result.append(contentsOf: sub.allAttestationNodes())
        }
        return result
    }

    func serialize(into data: inout Data) throws {
        guard !attestations.isEmpty || !ops.isEmpty else {
            throw OTSError.malformed("empty timestamp cannot be serialized")
        }
        let sortedAttestations = attestations.sorted { $0.tag.lexicographicallyPrecedes($1.tag) }
        if sortedAttestations.count > 1 {
            for attestation in sortedAttestations.dropLast() {
                data.append(contentsOf: [0xff, 0x00])
                attestation.serialize(into: &data)
            }
        }

        let sortedOps = ops.sorted { $0.key.sortKey.0 == $1.key.sortKey.0 ? $0.key.sortKey.1.lexicographicallyPrecedes($1.key.sortKey.1) : $0.key.sortKey.0 < $1.key.sortKey.0 }

        if sortedOps.isEmpty {
            data.append(0x00)
            guard let last = sortedAttestations.last else {
                throw OTSError.malformed("no attestations to terminate timestamp")
            }
            last.serialize(into: &data)
        } else {
            if let last = sortedAttestations.last {
                data.append(contentsOf: [0xff, 0x00])
                last.serialize(into: &data)
            }
            for (op, subStamp) in sortedOps.dropLast() {
                data.append(0xff)
                op.serialize(into: &data)
                try subStamp.serialize(into: &data)
            }
            if let (lastOp, lastStamp) = sortedOps.last {
                lastOp.serialize(into: &data)
                try lastStamp.serialize(into: &data)
            }
        }
    }

    static func deserialize(from bytes: Data, offset: inout Int, msg: Data, depth: Int = 0) throws -> OTSTimestamp {
        guard depth < 256 else { throw OTSError.malformed("recursion limit reached") }
        let stamp = OTSTimestamp(msg: msg)

        func handle(tag: UInt8) throws {
            if tag == 0x00 {
                let attestation = try OTSAttestation.deserialize(from: bytes, offset: &offset)
                stamp.attestations.insert(attestation)
            } else {
                let op = try OTSOp.deserialize(tag: tag, from: bytes, offset: &offset)
                let result = try op.apply(to: msg)
                let subStamp = try OTSTimestamp.deserialize(from: bytes, offset: &offset, msg: result, depth: depth + 1)
                stamp.ops[op] = subStamp
            }
        }

        var tagByte = try bytes.readByte(offset: &offset)
        while tagByte == 0xff {
            let nextTag = try bytes.readByte(offset: &offset)
            try handle(tag: nextTag)
            tagByte = try bytes.readByte(offset: &offset)
        }
        try handle(tag: tagByte)

        return stamp
    }
}

/// `.ots` ファイル全体（ヘッダ＋ハッシュ種別＋ダイジェスト＋証明ツリー）。
struct OTSDetachedFile {
    static let headerMagic: Data = {
        var d = Data([0x00])
        d.append(Data("OpenTimestamps".utf8))
        d.append(Data([0x00, 0x00]))
        d.append(Data("Proof".utf8))
        d.append(Data([0x00, 0xbf, 0x89, 0xe2, 0xe8, 0x84, 0xe8, 0x92, 0x94]))
        return d
    }()
    static let majorVersion: UInt8 = 1

    let timestamp: OTSTimestamp

    func serialize() throws -> Data {
        var data = Data()
        data.append(Self.headerMagic)
        data.append(Self.majorVersion)
        data.append(OTSOp.sha256.tag) // file_hash_op：本アプリは常にSHA-256
        data.append(timestamp.msg)
        try timestamp.serialize(into: &data)
        return data
    }

    static func deserialize(_ data: Data) throws -> OTSDetachedFile {
        guard data.count > headerMagic.count, data.prefix(headerMagic.count) == headerMagic else {
            throw OTSError.malformed("missing OTS header magic")
        }
        var offset = headerMagic.count
        let version = try data.readByte(offset: &offset)
        guard version == majorVersion else { throw OTSError.unsupportedVersion }
        let hashOpTag = try data.readByte(offset: &offset)
        let digestLength = hashOpTag == OTSOp.sha256.tag ? 32 : 20
        let digest = try data.readBytes(digestLength, offset: &offset)
        let timestamp = try OTSTimestamp.deserialize(from: data, offset: &offset, msg: digest)
        return OTSDetachedFile(timestamp: timestamp)
    }
}
