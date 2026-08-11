import Foundation

/// 記録をOpenTimestampsに提出し、結果をEntryに書き戻す。有料版のみで使用する。
@MainActor
final class AnchoringService {
    private let client: OpenTimestampsClient

    init(client: OpenTimestampsClient = URLSessionOpenTimestampsClient()) {
        self.client = client
    }

    func anchor(_ entry: Entry) async throws {
        let proof = try await client.submit(hashHex: entry.contentHash)
        entry.otsProofData = proof
        entry.anchoredAt = .now
    }

    func refreshVerification(_ entry: Entry) async throws -> TimestampVerification {
        guard let proof = entry.otsProofData else {
            throw OpenTimestampsError.malformedProof
        }
        return try await client.verify(hashHex: entry.contentHash, proof: proof)
    }
}
