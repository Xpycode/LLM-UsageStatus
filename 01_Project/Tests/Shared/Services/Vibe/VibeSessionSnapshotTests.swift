import Foundation
import XCTest
@testable import LLMUsageStatus

/// Synthetic unified-store fixtures in disposable temp directories only; the
/// real ~/.vibe store is never read.
final class VibeSessionSnapshotTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var root: URL!

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory
            .appending(path: "VibeSessionSnapshotTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    // MARK: - Tests

    func testTotalsSurviveJournalRotationAcrossGenerations() async throws {
        // Generation A: its journal segment still holds the usage rows.
        try writeSession("s", generation: "0000000000000001", usage: (1_000, 100),
                         segments: ["0000000000000002": [usageRecord(sequence: 2, input: 1_000, output: 100)]])
        let afterA = await aggregator().scan().totals

        // Generation B: Vibe deleted segment A+1; only B+1 remains.
        try writeSession("s", generation: "0000000000000003", usage: (2_000, 200),
                         segments: ["0000000000000004": [usageRecord(sequence: 4, input: 500, output: 50)]])
        let afterB = await aggregator().scan().totals

        // Generation C: segment B+1 is gone too.
        try writeSession("s", generation: "0000000000000005", usage: (3_000, 300),
                         segments: ["0000000000000006": [usageRecord(sequence: 6, input: 100, output: 10)]])
        let afterC = await aggregator().scan().totals

        XCTAssertEqual(VibeUsageProvider.totalTokens(afterA), 1_100)
        XCTAssertEqual(VibeUsageProvider.totalTokens(afterB), 2_200)
        XCTAssertEqual(VibeUsageProvider.totalTokens(afterC), 3_300)
        XCTAssertLessThanOrEqual(VibeUsageProvider.totalTokens(afterA), VibeUsageProvider.totalTokens(afterB))
        XCTAssertLessThanOrEqual(VibeUsageProvider.totalTokens(afterB), VibeUsageProvider.totalTokens(afterC))
    }

    func testNewestCompleteJournalEnvelopeOverridesSnapshotAndTruncatedTailIsIgnored() async throws {
        let lines = [
            envelopeDelta(id: "s", usage: (1_500, 150)),
            envelopeDelta(id: "s", usage: (2_500, 250)),
            // Newer envelope without counters keeps the previous counters.
            envelopeDelta(id: "s", usage: nil),
        ]
        // The last record is complete JSON but lacks its terminating newline:
        // still being written, so it must not count.
        let trailing = envelopeDelta(id: "s", usage: (9_999, 999))
        try writeSession("s", generation: "0000000000000001", usage: (1_000, 100),
                         segments: ["0000000000000002": lines + [trailing]], terminateLastLine: false)

        let report = await aggregator().scan()

        XCTAssertEqual(VibeUsageProvider.totalTokens(report.totals), 2_750)
    }

    func testChunkedProjectionStateReadsCountersFromProjectionStateFile() async throws {
        let digest = String(repeating: "ab", count: 32)
        try writeSession("s", generation: "0000000000000001", usage: (7_000, 700),
                         segments: [:], chunks: [digest])

        let report = await aggregator().scan()

        XCTAssertEqual(report.totals, VibeTokenTotals(inputTokens: 7_000, cachedInputTokens: 0,
                                                      outputTokens: 700, reasoningTokens: 0))
    }

    func testSessionWithoutTokenUsageFallsBackToJournalSums() async throws {
        try writeSession("s", generation: "0000000000000001", usage: nil,
                         segments: ["0000000000000002": [usageRecord(sequence: 2, input: 300, output: 30),
                                                         usageRecord(sequence: 3, input: 100, output: 10)]])

        let report = await aggregator().scan()

        XCTAssertEqual(VibeUsageProvider.totalTokens(report.totals), 440)
        XCTAssertEqual(report.sessions.first?.usageRows, 2)
    }

    func testMissingManifestFallsBackToJournalSums() async throws {
        try writeSession("s", generation: "0000000000000001", usage: (5_000, 500),
                         segments: ["0000000000000002": [usageRecord(sequence: 2, input: 40, output: 4)]])
        try FileManager.default.removeItem(
            at: root.appending(path: "s/generations/0000000000000001/manifest.json"))

        let report = await aggregator().scan()

        XCTAssertEqual(VibeUsageProvider.totalTokens(report.totals), 44)
    }

    func testChildrenFoldIntoSessionCountButNotTotalsAndPriceByOwnOrRootModel() async throws {
        try writeSession("root", generation: "0000000000000001", usage: (1_000, 100), segments: [:],
                         rootID: "root")
        try writeSession("child-with-root", generation: "0000000000000001", usage: (400, 40), segments: [:],
                         rootID: "root", parentID: "root")
        try writeSession("child-own-model", generation: "0000000000000001", usage: (300, 30), segments: [:],
                         rootID: "root", parentID: "root")
        try writeSession("child-orphan", generation: "0000000000000001", usage: (200, 20), segments: [:],
                         rootID: "ghost-root", parentID: "ghost-root")
        let models: [String: String] = ["root": "mistral-medium-3.5", "child-own-model": "zai-glm-5.3"]
        let scannedAt = now
        let report = await VibeJournalAggregator(
            storeRoot: root, modelNameSource: { id, _ in models[id] }, now: { scannedAt }).scan()

        XCTAssertEqual(report.sessions.count, 4)
        XCTAssertEqual(report.rootSessionCount, 2)
        XCTAssertEqual(VibeUsageProvider.totalTokens(report.totals), 2_090)
        func model(_ id: String) -> String?? { report.sessions.first { $0.id == id }.map(\.modelName) }
        XCTAssertEqual(model("child-with-root"), .some("mistral-medium-3.5"))
        XCTAssertEqual(model("child-own-model"), .some("zai-glm-5.3"))
        XCTAssertEqual(model("child-orphan"), .some(nil))

        guard case .populated(let section) = await VibeUsageProvider(
            aggregator: VibeJournalAggregator(storeRoot: root, modelNameSource: { id, _ in models[id] },
                                              now: { scannedAt })).refresh() else {
            return XCTFail("Expected populated")
        }
        XCTAssertEqual(section.rows.first { $0.id == "sessions" }?.value, "2")
    }

    func testSnapshotReaderReportsIdentityAndInclusiveCounters() throws {
        try writeSession("s", generation: "0000000000000001", usage: (900, 90), segments: [:],
                         rootID: "r", parentID: "p")

        let snapshot = try VibeSessionSnapshot.read(sessionDirectory: root.appending(path: "s"))

        XCTAssertEqual(snapshot.rootSessionID, "r")
        XCTAssertEqual(snapshot.parentSessionID, "p")
        XCTAssertEqual(snapshot.tokenUsage?.inputTokens, 900)
        XCTAssertEqual(snapshot.tokenUsage?.outputTokens, 90)
    }

    // MARK: - Fixtures

    private func aggregator() -> VibeJournalAggregator {
        let scannedAt = now
        return VibeJournalAggregator(storeRoot: root, now: { scannedAt })
    }

    /// Replaces the session's CURRENT, generation and journal directory, so a
    /// second call models Vibe rotating to a new generation and deleting
    /// segments that are no longer named.
    private func writeSession(_ id: String, generation: String, usage: (input: Int, output: Int)?,
                              segments: [String: [String]], chunks: [String] = [],
                              terminateLastLine: Bool = true,
                              rootID: String? = nil, parentID: String? = nil) throws {
        let fileManager = FileManager.default
        let directory = root.appending(path: id, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let journalDirectory = directory.appending(path: "journal", directoryHint: .isDirectory)
        if fileManager.fileExists(atPath: journalDirectory.path) {
            try fileManager.removeItem(at: journalDirectory)
        }
        try fileManager.createDirectory(at: journalDirectory, withIntermediateDirectories: true)
        for (name, lines) in segments {
            var text = lines.joined(separator: "\n")
            if terminateLastLine { text += "\n" }
            try Data(text.utf8).write(to: journalDirectory.appending(path: "\(name).jsonl"))
        }

        let current: [String: Any] = ["generation": generation, "session_id": id,
                                      "store_format": "mistral.vibe.unified-session-store/v1",
                                      "store_format_minor": 10, "manifest_sha256": "0",
                                      "snapshot_sequence": 1]
        try Self.jsonData(current).write(to: directory.appending(path: "CURRENT"))

        let generationDirectory = directory.appending(path: "generations/\(generation)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: generationDirectory, withIntermediateDirectories: true)
        var manifest: [String: Any] = [
            "generation": generation, "manifest_version": 1, "session_id": id,
            "projection_state": ["chunks": chunks, "path": "projection-state.json", "sha256": "0"],
        ]
        if let segment = segments.keys.sorted().first {
            manifest["recovery_journal_segment"] = ["first_sequence": 1, "path": "journal/\(segment).jsonl"]
        }
        try Self.jsonData(manifest).write(to: generationDirectory.appending(path: "manifest.json"))
        let state: [String: Any] = [
            "projection_state_version": 1, "session_id": id, "snapshot_sequence": 1, "watermark": 1,
            "snapshot": envelope(id: id, usage: usage, rootID: rootID ?? id, parentID: parentID),
        ]
        try Self.jsonData(state).write(to: generationDirectory.appending(path: "projection-state.json"))

        if !chunks.isEmpty {
            let chunkDirectory = directory.appending(path: "chunks", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: chunkDirectory, withIntermediateDirectories: true)
            for digest in chunks {
                try Data("[{\"type\":\"message\"}]".utf8).write(to: chunkDirectory.appending(path: "\(digest).json"))
            }
        }
    }

    private func envelope(id: String, usage: (input: Int, output: Int)?,
                          rootID: String? = nil, parentID: String? = nil) -> [String: Any] {
        var session: [String: Any] = ["id": id, "parentSessionId": parentID ?? NSNull(),
                                      "rootSessionId": rootID ?? NSNull()]
        if let usage {
            session["tokenUsage"] = ["inputTokens": usage.input, "cachedInputTokens": 0,
                                     "outputTokens": usage.output, "totalTokens": usage.input + usage.output]
        } else {
            session["tokenUsage"] = NSNull()
        }
        return ["format": "harness.public-session-state/v1", "session": session,
                "history": ["entries": [], "range": "latest"]]
    }

    private func envelopeDelta(id: String, usage: (input: Int, output: Int)?) -> String {
        let record: [String: Any] = [
            "type": "projection_delta", "sequence": 1,
            "payload": ["delta": [["op": "set_envelope",
                                   "state": envelope(id: id, usage: usage, rootID: id)]]],
        ]
        return Self.line(record)
    }

    private func usageRecord(sequence: Int, input: Int, output: Int) -> String {
        let usage: [String: Any] = ["input_tokens": input, "output_tokens": output,
                                    "total_tokens": input + output]
        let record: [String: Any] = ["type": "action_result", "sequence": sequence,
                                     "payload": ["action_id": "a\(sequence)", "state": "succeeded",
                                                 "result": ["result": ["usage": usage]]]]
        return Self.line(record)
    }

    private static func line(_ record: [String: Any]) -> String {
        String(decoding: jsonData(record), as: UTF8.self)
    }

    private static func jsonData(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }
}
