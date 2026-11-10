import Foundation
import XCTest
@testable import LLMUsageStatus

/// Synthetic journal fixtures in disposable temp directories only; the real
/// ~/.vibe store is never read.
final class VibeJournalAggregatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var root: URL!

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory
            .appending(path: "VibeJournalAggregatorTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    func testSumsInclusiveCountsDoesNotAddCacheWriteAndKeepsMetalessChildSessions() async throws {
        try writeSession("session-a", fixture: SessionFixture(journal: [[
            usageRecord(sequence: 10, actionID: "a1", input: 5_220, cacheWrite: 50,
                        cached: 5_120, output: 77, reasoning: 33),
            coreInputRecord(sequence: 11, actionID: "a1", timeUnixMs: milliseconds(now.addingTimeInterval(-3_600))),
            usageRecord(sequence: 20, actionID: "a2", input: 200, cached: 100, output: 10),
            coreInputRecord(sequence: 21, actionID: "a2", timeUnixMs: milliseconds(now.addingTimeInterval(-3_600)))
        ]]))
        // Child sessions have no meta.json but still aggregate.
        try writeSession("child-1", fixture: SessionFixture(journal: [[
            usageRecord(sequence: 1, actionID: "b1", input: 1_000, output: 500, reasoning: 100),
            coreInputRecord(sequence: 2, actionID: "b1", timeUnixMs: milliseconds(now.addingTimeInterval(-7_200)))
        ]]))

        let report = await aggregator().scan()

        XCTAssertTrue(report.detected)
        XCTAssertEqual(report.skippedSessions, 0)
        XCTAssertEqual(report.malformedRecords, 0)
        XCTAssertEqual(report.sessions.count, 2)
        XCTAssertEqual(report.totals, VibeTokenTotals(inputTokens: 6_420, cachedInputTokens: 5_220,
                                                      outputTokens: 587, reasoningTokens: 133))
        let child = try XCTUnwrap(report.sessions.first { $0.id == "child-1" })
        XCTAssertNil(child.modelName)
        XCTAssertNil(child.startedAt)
        XCTAssertNil(child.endedAt)
        XCTAssertEqual(child.usageRows, 1)
        XCTAssertEqual(child.totals, VibeTokenTotals(inputTokens: 1_000, outputTokens: 500, reasoningTokens: 100))
        XCTAssertEqual(report.last24Hours.attributed, report.totals)
        XCTAssertEqual(report.last24Hours.unattributed, .zero)
        XCTAssertEqual(report.last7Days.attributed, report.totals)
    }

    func testMalformedRowsAreSkippedAndCounted() async throws {
        try writeSession("session-malformed", fixture: SessionFixture(journal: [[
            "{ this is not json",
            usageRecord(sequence: 1, actionID: "m1", input: 10, output: 5),
            "{\"type\":\"action_result\",\"sequence\":2,\"payload\":{\"action_id\":\"m2\",\"result\":{\"result\":{\"usage\":{\"input_tokens\":\"bad\"}}}}}",
            "{\"type\":\"action_result\",\"sequence\":3,\"payload\":{\"action_id\":\"m3\",\"result\":{\"result\":{\"usage\":{}}}}}",
            "",
            "{\"type\":\"core_input\",\"sequence\":4,\"payload\":{\"input\":{}}}",
            "{\"type\":\"projection_delta\",\"sequence\":5,\"payload\":{}}"
        ]]))

        let report = await aggregator().scan()

        XCTAssertEqual(report.malformedRecords, 3)
        XCTAssertEqual(report.sessions.count, 1)
        XCTAssertEqual(report.sessions[0].usageRows, 1)
        XCTAssertEqual(report.totals, VibeTokenTotals(inputTokens: 10, outputTokens: 5))
    }

    func testEmptyStoreYieldsDetectedZeroState() async throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let report = await aggregator().scan()

        XCTAssertTrue(report.detected)
        XCTAssertEqual(report.sessions, [])
        XCTAssertEqual(report.totals, .zero)
        XCTAssertEqual(report.last24Hours, VibeWindowTotals())
        XCTAssertEqual(report.last7Days, VibeWindowTotals())
        XCTAssertEqual(report.skippedSessions, 0)
        XCTAssertEqual(report.malformedRecords, 0)
    }

    func testAbsentStoreIsNotDetected() async {
        let report = await aggregator().scan()

        XCTAssertFalse(report.detected)
        XCTAssertEqual(report.sessions, [])
        XCTAssertEqual(report.totals, .zero)
        XCTAssertEqual(report.skippedSessions, 0)
    }

    func testStoreFormatGateAcceptsOnlyUnifiedV1() async throws {
        try writeSession("accepted", fixture: SessionFixture(journal: [[
            usageRecord(sequence: 1, actionID: "k1", input: 10),
            coreInputRecord(sequence: 2, actionID: "k1", timeUnixMs: milliseconds(now))
        ]]))
        try writeSession("unknown-format", fixture: SessionFixture(
            storeFormat: "mistral.vibe.unified-session-store/v2",
            journal: [[usageRecord(sequence: 1, actionID: "k2", input: 999)]]))
        try writeSession("missing-current", fixture: SessionFixture(
            storeFormat: nil,
            journal: [[usageRecord(sequence: 1, actionID: "k3", input: 888)]]))

        let report = await aggregator().scan()

        XCTAssertEqual(report.skippedSessions, 2)
        XCTAssertEqual(report.sessions.map(\.id), ["accepted"])
        XCTAssertEqual(report.totals, VibeTokenTotals(inputTokens: 10))
    }

    func testTimestampsComeFromPairedCoreInputRecords() async throws {
        try writeSession("session-times", fixture: SessionFixture(journal: [[
            usageRecord(sequence: 10, actionID: "t1", input: 1),
            coreInputRecord(sequence: 11, actionID: "t1", timeUnixMs: milliseconds(now.addingTimeInterval(-2 * 86_400))),
            usageRecord(sequence: 20, actionID: "t2", input: 10),
            coreInputRecord(sequence: 21, actionID: "t2", timeUnixMs: milliseconds(now.addingTimeInterval(-3_600)))
        ]]))

        let report = await aggregator().scan()

        XCTAssertEqual(report.totals, VibeTokenTotals(inputTokens: 11))
        XCTAssertEqual(report.last24Hours.attributed, VibeTokenTotals(inputTokens: 10))
        XCTAssertEqual(report.last24Hours.unattributed, .zero)
        XCTAssertEqual(report.last7Days.attributed, report.totals)
    }

    func testUnmatchedActionFallsBackToNearestCoreInputSequence() async throws {
        try writeSession("session-nearest", fixture: SessionFixture(journal: [[
            usageRecord(sequence: 10, actionID: "orphan", input: 1),
            coreInputRecord(sequence: 11, actionID: "other", timeUnixMs: milliseconds(now.addingTimeInterval(-2 * 86_400)))
        ]]))

        let report = await aggregator().scan()

        // The freshly created file's mtime is "now"; only sequence pairing can
        // place this row two days back.
        XCTAssertEqual(report.last24Hours.attributed, .zero)
        XCTAssertEqual(report.last7Days.attributed, VibeTokenTotals(inputTokens: 1))
    }

    func testRowsWithoutCoreInputUseFileModificationDate() async throws {
        try writeSession("session-mtime", fixture: SessionFixture(journal: [[
            usageRecord(sequence: 1, actionID: "f1", input: 5),
            usageRecord(sequence: 2, actionID: "f2", input: 7)
        ]]), mtime: now.addingTimeInterval(-3 * 86_400))

        let report = await aggregator().scan()

        XCTAssertEqual(report.totals, VibeTokenTotals(inputTokens: 12))
        XCTAssertEqual(report.last24Hours.attributed, .zero)
        XCTAssertEqual(report.last24Hours.unattributed, .zero)
        XCTAssertEqual(report.last7Days.attributed, VibeTokenTotals(inputTokens: 12))
    }

    func testMetaTimesAttributeWholeSessionsWhenFileDatesUnavailable() async throws {
        try writeSession("session-meta-recent", fixture: SessionFixture(
            meta: meta(startAgo: 3 * 86_400, endAgo: 2 * 86_400),
            journal: [[usageRecord(sequence: 1, actionID: "r1", input: 4),
                       usageRecord(sequence: 2, actionID: "r2", input: 6)]]))
        try writeSession("session-meta-old", fixture: SessionFixture(
            meta: meta(startAgo: 30 * 86_400, endAgo: 20 * 86_400),
            journal: [[usageRecord(sequence: 1, actionID: "o1", input: 100)]]))

        let report = await aggregator(withoutFileDates: true).scan()

        XCTAssertEqual(report.totals, VibeTokenTotals(inputTokens: 110))
        XCTAssertEqual(report.last24Hours.attributed, .zero)
        XCTAssertEqual(report.last24Hours.unattributed, .zero)
        XCTAssertEqual(report.last7Days.attributed, VibeTokenTotals(inputTokens: 10))
        XCTAssertEqual(report.last7Days.unattributed, .zero)
        let recent = try XCTUnwrap(report.sessions.first { $0.id == "session-meta-recent" })
        XCTAssertEqual(recent.startedAt, now.addingTimeInterval(-3 * 86_400))
        XCTAssertEqual(recent.endedAt, now.addingTimeInterval(-2 * 86_400))
    }

    func testSessionsWithoutAnyResolvableTimeDegradeWindowsToSessionTotals() async throws {
        try writeSession("session-lost-time", fixture: SessionFixture(journal: [[
            usageRecord(sequence: 1, actionID: "u1", input: 9, output: 1)
        ]]))

        let report = await aggregator(withoutFileDates: true).scan()

        XCTAssertEqual(report.totals, VibeTokenTotals(inputTokens: 9, outputTokens: 1))
        XCTAssertEqual(report.last24Hours.attributed, .zero)
        XCTAssertEqual(report.last24Hours.unattributed, report.totals)
        XCTAssertEqual(report.last24Hours.combined, report.totals)
        XCTAssertEqual(report.last7Days.attributed, .zero)
        XCTAssertEqual(report.last7Days.unattributed, report.totals)
    }

    func testModelNameIsReadFromMeta() async throws {
        try writeSession("session-model-config", fixture: SessionFixture(
            meta: meta(startAgo: 60, endAgo: 30, modelName: "zai-glm-5-3"),
            journal: [[usageRecord(sequence: 1, actionID: "n1", input: 1)]]))
        try writeSession("session-model-top", fixture: SessionFixture(
            meta: ["session_id": "session-model-top", "model_name": "mistral-medium-3.5",
                   "start_time": iso(60), "end_time": iso(30)],
            journal: [[usageRecord(sequence: 1, actionID: "n2", input: 1)]]))

        let report = await aggregator().scan()

        XCTAssertEqual(report.sessions.first { $0.id == "session-model-config" }?.modelName, "zai-glm-5-3")
        XCTAssertEqual(report.sessions.first { $0.id == "session-model-top" }?.modelName, "mistral-medium-3.5")
    }

    func testModelNameSourceIsPluggable() async throws {
        try writeSession("session-plug", fixture: SessionFixture(journal: [[
            usageRecord(sequence: 1, actionID: "p1", input: 1)
        ]]))
        let scannedAt = now
        let aggregator = VibeJournalAggregator(
            storeRoot: root,
            modelNameSource: { sessionID, _ in "wired-\(sessionID)" },
            now: { scannedAt })

        let report = await aggregator.scan()

        XCTAssertEqual(report.sessions.first?.modelName, "wired-session-plug")
    }

    // MARK: - Fixtures

    private struct SessionFixture {
        var storeFormat: String? = "mistral.vibe.unified-session-store/v1"
        var meta: [String: Any]? = nil
        var journal: [[String]] = []
    }

    private func aggregator(withoutFileDates: Bool = false) -> VibeJournalAggregator {
        let scannedAt = now
        if withoutFileDates {
            return VibeJournalAggregator(storeRoot: root, modificationDateSource: { _ in nil }, now: { scannedAt })
        }
        return VibeJournalAggregator(storeRoot: root, now: { scannedAt })
    }

    private func writeSession(_ id: String, fixture: SessionFixture, mtime: Date? = nil) throws {
        let directory = root.appending(path: id, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let storeFormat = fixture.storeFormat {
            let current: [String: Any] = ["session_id": id, "store_format": storeFormat,
                                          "store_format_minor": 10, "generation": "1",
                                          "manifest_sha256": "0", "snapshot_sequence": 1]
            try Self.jsonData(current).write(to: directory.appending(path: "CURRENT"))
        }
        if let meta = fixture.meta {
            try Self.jsonData(meta).write(to: directory.appending(path: "meta.json"))
        }
        guard !fixture.journal.isEmpty else { return }
        let journalDirectory = directory.appending(path: "journal", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: journalDirectory, withIntermediateDirectories: true)
        for (index, lines) in fixture.journal.enumerated() {
            let fileURL = journalDirectory.appending(path: String(format: "%012d", index) + ".jsonl")
            try lines.joined(separator: "\n").data(using: .utf8)?.write(to: fileURL)
            if let mtime {
                try FileManager.default.setAttributes([.modificationDate: mtime], ofItemAtPath: fileURL.path)
            }
        }
    }

    private func usageRecord(sequence: Int, actionID: String,
                             input: Int = 0, cacheWrite: Int = 0, cached: Int = 0,
                             output: Int = 0, reasoning: Int = 0) -> String {
        let usage: [String: Any] = ["input_tokens": input, "cache_write_tokens": cacheWrite,
                                    "cached_input_tokens": cached, "output_tokens": output,
                                    "reasoning_tokens": reasoning,
                                    "total_tokens": input + output]
        let record: [String: Any] = ["type": "action_result", "sequence": sequence,
                                     "payload": ["action_id": actionID, "state": "succeeded",
                                                 "result": ["result": ["usage": usage]]]]
        return Self.line(record)
    }

    private func coreInputRecord(sequence: Int, actionID: String? = nil, timeUnixMs: Int64? = nil) -> String {
        var input: [String: Any] = ["input_id": "input-\(sequence)", "protocol_version": 1]
        if let actionID { input["command"] = ["action_id": actionID, "type": "tool"] }
        if let timeUnixMs { input["determinism"] = ["time_unix_ms": timeUnixMs, "random_seed": 0] }
        let record: [String: Any] = ["type": "core_input", "sequence": sequence,
                                     "payload": ["input": input]]
        return Self.line(record)
    }

    private func meta(startAgo: TimeInterval, endAgo: TimeInterval, modelName: String? = nil) -> [String: Any] {
        var meta: [String: Any] = ["session_id": "fixture", "parent_session_id": NSNull(),
                                   "start_time": iso(startAgo), "end_time": iso(endAgo)]
        if let modelName { meta["config"] = ["model_name": modelName] }
        return meta
    }

    private func iso(_ secondsAgo: TimeInterval) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: now.addingTimeInterval(-secondsAgo))
    }

    private func milliseconds(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1_000)
    }

    private static func line(_ record: [String: Any]) -> String {
        String(decoding: jsonData(record), as: UTF8.self)
    }

    private static func jsonData(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }
}
