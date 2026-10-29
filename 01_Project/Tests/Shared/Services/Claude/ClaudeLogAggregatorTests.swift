import Foundation
import XCTest
@testable import LLMUsageStatus

/// Fixtures are synthetic JSONL transcripts in disposable temp directories;
/// the real ~/.claude is never read and no test touches the Keychain.
final class ClaudeLogAggregatorTests: XCTestCase {
    /// 2027-01-15T08:00:00Z; the rolling window starts at 2027-01-08T08:00:00Z.
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let windowStart = now.addingTimeInterval(-7 * 24 * 60 * 60)

    func testSumsTokensAcrossFilesAndSessions() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try write([
            line(timestamp: "2027-01-14T10:00:00Z", input: 10, output: 20, cacheCreation: 5, cacheRead: 5),
            line(timestamp: "2027-01-12T00:00:00.500Z", input: 1, output: 2)
        ], to: "proj-a/session-1.jsonl", root: root)
        try write([
            line(timestamp: "2027-01-15T07:00:00Z", input: 100, output: 200, cacheCreation: 30, cacheRead: 40)
        ], to: "proj-b/session-2.jsonl", root: root)
        try write(["not a transcript"], to: "proj-b/notes.txt", root: root)

        let result = await aggregator(root: root).aggregate()
        guard case .summarized(let summary) = result else {
            XCTFail("Expected a summarized result")
            return
        }
        XCTAssertEqual(summary.windowStart, Self.windowStart)
        XCTAssertEqual(summary.malformedLines, 0)
        XCTAssertEqual(summary.sessions.count, 2)
        XCTAssertEqual(summary.totals, ClaudeTokenTotals(inputTokens: 111, outputTokens: 222,
                                                         cacheCreationInputTokens: 35, cacheReadInputTokens: 45))
        XCTAssertEqual(summary.sessions.first?.id, "proj-b/session-2.jsonl")
        let first = try XCTUnwrap(session("proj-a/session-1.jsonl", in: summary))
        XCTAssertEqual(first.totals, ClaudeTokenTotals(inputTokens: 11, outputTokens: 22,
                                                       cacheCreationInputTokens: 5, cacheReadInputTokens: 5))
        XCTAssertEqual(first.lastActivity, Date(timeIntervalSince1970: 1_799_920_800))
        let second = try XCTUnwrap(session("proj-b/session-2.jsonl", in: summary))
        XCTAssertEqual(second.lastActivity, Date(timeIntervalSince1970: 1_799_996_400))
    }

    func testRollingSevenDayWindowFiltersLinesByTimestamp() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try write([
            line(timestamp: "2027-01-08T08:00:00Z", input: 1),    // exactly at window start: included
            line(timestamp: "2027-01-08T07:59:59Z", input: 1000), // one second early: excluded
            line(timestamp: "2026-12-20T10:00:00Z", input: 10000), // a week stale: excluded
            line(timestamp: "2027-01-16T00:00:00Z", output: 7)    // future: accepted defensively
        ], to: "proj/recent.jsonl", root: root)
        try write([
            line(timestamp: "2026-12-01T00:00:00Z", input: 999)
        ], to: "proj/only-old.jsonl", root: root)

        let result = await aggregator(root: root).aggregate()
        guard case .summarized(let summary) = result else {
            XCTFail("Expected a summarized result")
            return
        }
        XCTAssertEqual(summary.sessions.count, 1)
        XCTAssertEqual(summary.sessions.first?.id, "proj/recent.jsonl")
        XCTAssertEqual(summary.totals, ClaudeTokenTotals(inputTokens: 1, outputTokens: 7,
                                                         cacheCreationInputTokens: 0, cacheReadInputTokens: 0))
        XCTAssertEqual(summary.malformedLines, 0)
    }

    func testMalformedLinesAreSkippedAndCountedButNeverFailTheFile() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try write([
            "not json",
            #"{"timestamp":"2027-01-14T10:00:00Z""#,
            "",
            line(timestamp: "2027-01-14T10:00:00Z", input: 3),
            "null",
            "[]",
            "{}",
            line(timestamp: "2027-01-14T11:00:00Z", output: 4)
        ], to: "proj/mixed.jsonl", root: root)

        let result = await aggregator(root: root).aggregate()
        guard case .summarized(let summary) = result else {
            XCTFail("Expected a summarized result")
            return
        }
        XCTAssertEqual(summary.malformedLines, 5)
        XCTAssertEqual(summary.sessions.count, 1)
        XCTAssertEqual(summary.totals, ClaudeTokenTotals(inputTokens: 3, outputTokens: 4,
                                                         cacheCreationInputTokens: 0, cacheReadInputTokens: 0))
    }

    func testEmptyDirectoryProducesZeroState() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appending(path: "proj-a", directoryHint: .isDirectory),
                                                withIntermediateDirectories: true)

        let result = await aggregator(root: root).aggregate()
        guard case .summarized(let summary) = result else {
            XCTFail("Expected a zero summary")
            return
        }
        XCTAssertEqual(summary.windowStart, Self.windowStart)
        XCTAssertEqual(summary.sessions, [])
        XCTAssertEqual(summary.totals, ClaudeTokenTotals(inputTokens: 0, outputTokens: 0,
                                                         cacheCreationInputTokens: 0, cacheReadInputTokens: 0))
        XCTAssertEqual(summary.malformedLines, 0)
    }

    func testAbsentDirectoryIsNotDetected() async {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let result = await aggregator(root: root).aggregate()
        XCTAssertEqual(result, .notDetected)
    }

    func testSidechainLinesAreExcludedFromAllAggregates() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try write([
            line(timestamp: "2027-01-14T10:00:00Z", input: 10),
            line(timestamp: "2027-01-14T11:00:00Z", input: 5000, sidechain: true)
        ], to: "proj/main.jsonl", root: root)
        try write([
            line(timestamp: "2027-01-14T12:00:00Z", output: 999, sidechain: true)
        ], to: "proj/only-sidechain.jsonl", root: root)

        let result = await aggregator(root: root).aggregate()
        guard case .summarized(let summary) = result else {
            XCTFail("Expected a summarized result")
            return
        }
        XCTAssertEqual(summary.sessions.count, 1)
        XCTAssertEqual(summary.sessions.first?.id, "proj/main.jsonl")
        XCTAssertEqual(summary.totals, ClaudeTokenTotals(inputTokens: 10, outputTokens: 0,
                                                         cacheCreationInputTokens: 0, cacheReadInputTokens: 0))
        XCTAssertEqual(summary.malformedLines, 0)
    }

    func testCacheTokensAreSummedWhileUnknownKeysAndUserLinesAreIgnored() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try write([
            line(timestamp: "2027-01-14T10:00:00Z", input: 10, output: 20, cacheCreation: 5, cacheRead: 40),
            #"{"timestamp":"2027-01-14T11:00:00Z","message":{"role":"user","content":"synthetic"}}"#,
            #"{"timestamp":"2027-01-14T12:00:00Z","message":{"role":"assistant","usage":{"input_tokens":1,"output_tokens":2,"cache_creation_input_tokens":3,"cache_read_input_tokens":4,"unknown_future_key":777}}}"#
        ], to: "proj/tokens.jsonl", root: root)

        let result = await aggregator(root: root).aggregate()
        guard case .summarized(let summary) = result else {
            XCTFail("Expected a summarized result")
            return
        }
        XCTAssertEqual(summary.sessions.count, 1)
        XCTAssertEqual(summary.totals, ClaudeTokenTotals(inputTokens: 11, outputTokens: 22,
                                                         cacheCreationInputTokens: 8, cacheReadInputTokens: 44))
        XCTAssertEqual(summary.totals.totalTokens, 85)
        XCTAssertEqual(summary.malformedLines, 0)
    }

    private func aggregator(root: URL) -> ClaudeLogAggregator {
        ClaudeLogAggregator(root: root, now: { Self.now })
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func write(_ lines: [String], to relativePath: String, root: URL) throws {
        let url = root.appending(path: relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func line(timestamp: String, input: Int = 0, output: Int = 0,
                      cacheCreation: Int = 0, cacheRead: Int = 0,
                      role: String = "assistant", sidechain: Bool = false) -> String {
        let usage = #"{"role":"\#(role)","usage":{"input_tokens":\#(input),"output_tokens":\#(output),"cache_creation_input_tokens":\#(cacheCreation),"cache_read_input_tokens":\#(cacheRead)}}"#
        return #"{"timestamp":"\#(timestamp)","isSidechain":\#(sidechain),"message":\#(usage)}"#
    }

    private func session(_ id: String, in summary: ClaudeLogSummary) -> ClaudeSessionUsage? {
        summary.sessions.first { $0.id == id }
    }
}
