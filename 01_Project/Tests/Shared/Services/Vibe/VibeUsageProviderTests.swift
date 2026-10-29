import Foundation
import XCTest
@testable import LLMUsageStatus

/// Conformance of the local Vibe journal aggregation to the normalized
/// provider seam. Synthetic journal fixtures live in disposable temp
/// directories; the real ~/.vibe store is never read.
final class VibeUsageProviderTests: XCTestCase {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var storeRoot: URL!

    override func setUp() {
        super.setUp()
        storeRoot = FileManager.default.temporaryDirectory
            .appending(path: "VibeUsageProviderTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: storeRoot)
        super.tearDown()
    }

    func testProviderIdentity() {
        let provider = VibeUsageProvider()
        XCTAssertEqual(provider.id, "vibe")
        XCTAssertEqual(provider.displayName, "Mistral Vibe")
    }

    func testScanPopulatesRowsAndCostWhenModelResolves() async throws {
        try writeSession("session-a", journal: [
            usageRecord(sequence: 1, actionID: "a1", input: 100, cached: 5_000, output: 200),
            coreInputRecord(sequence: 2, actionID: "a1", timeUnixMs: milliseconds(Self.now.addingTimeInterval(-3_600))),
        ], modelName: "mistral-medium-3.5")
        let provider = VibeUsageProvider(aggregator: aggregator(modelName: { _, _ in "mistral-medium-3.5" }))

        let state = await provider.refresh()

        guard case .populated(let section) = state else {
            return XCTFail("Expected populated, got \(state)")
        }
        let cost = MistralRateCard.cost(inputTokens: 100, cachedTokens: 5_000, outputTokens: 200,
                                        prices: MistralRateCard.resolve("mistral-medium-3.5")!)
        let tokenTotal = 5_300.formatted()
        XCTAssertEqual(section.rows, [
            SectionRow(id: "sessions", label: "Sessions", value: "1"),
            SectionRow(id: "tokens-24h", label: "Tokens (24 hours)", value: tokenTotal),
            SectionRow(id: "tokens-7d", label: "Tokens (7 days)", value: tokenTotal),
            SectionRow(id: "tokens-total", label: "Tokens (all time)", value: tokenTotal),
            SectionRow(id: "estimated-cost", label: "Estimated cost",
                       value: cost.formatted(.currency(code: "USD")), isEstimate: true),
        ])
        XCTAssertTrue(section.meters.isEmpty)
        XCTAssertTrue(section.deadlines.isEmpty)
        XCTAssertEqual(section.lastUpdated, Self.now)
    }

    func testCostLineOmittedWhenModelPriceDoesNotResolve() async throws {
        try writeSession("session-unknown", journal: [
            usageRecord(sequence: 1, actionID: "u1", input: 100, output: 10),
            coreInputRecord(sequence: 2, actionID: "u1", timeUnixMs: milliseconds(Self.now)),
        ], modelName: nil)
        let provider = VibeUsageProvider(aggregator: aggregator(modelName: { _, _ in "not-a-mistral-model" }))

        let state = await provider.refresh()

        guard case .populated(let section) = state else {
            return XCTFail("Expected populated, got \(state)")
        }
        XCTAssertFalse(section.rows.contains { $0.id == "estimated-cost" })
    }

    func testUnattributedWindowsAreLabeledAsEstimates() async throws {
        // No core_input timestamps, no meta.json, no file dates: session totals
        // degrade into the rolling windows, so those rows carry the estimate flag.
        try writeSession("session-flat", journal: [
            usageRecord(sequence: 1, actionID: "f1", input: 1_000, output: 500),
        ], modelName: "mistral-medium-3.5")
        let provider = VibeUsageProvider(
            aggregator: VibeJournalAggregator(storeRoot: storeRoot,
                                             modelNameSource: { _, _ in "mistral-medium-3.5" },
                                             modificationDateSource: { _ in nil },
                                             now: { Self.now }))

        let state = await provider.refresh()

        guard case .populated(let section) = state else {
            return XCTFail("Expected populated, got \(state)")
        }
        let windowRows = section.rows.filter { $0.id == "tokens-24h" || $0.id == "tokens-7d" }
        XCTAssertEqual(windowRows.count, 2)
        XCTAssertTrue(windowRows.allSatisfy(\.isEstimate))
        XCTAssertFalse(section.rows.contains { $0.id == "tokens-total" && $0.isEstimate })
    }

    func testSkippedSessionsAndMalformedRecordsAreNoted() async throws {
        try writeSession("accepted", journal: [
            usageRecord(sequence: 1, actionID: "k1", input: 10),
            coreInputRecord(sequence: 2, actionID: "k1", timeUnixMs: milliseconds(Self.now)),
        ], modelName: "mistral-medium-3.5")
        try writeSession("unknown-format", storeFormat: "mistral.vibe.unified-session-store/v2",
                         journal: [usageRecord(sequence: 1, actionID: "k2", input: 999)], modelName: nil)
        try writeSession("malformed", journal: ["{ this is not json"], modelName: nil)
        let provider = VibeUsageProvider(aggregator: aggregator(modelName: { _, _ in nil }))

        let state = await provider.refresh()

        guard case .populated(let section) = state else {
            return XCTFail("Expected populated, got \(state)")
        }
        // The unknown model on the malformed-data sessions suppresses the cost line.
        XCTAssertFalse(section.rows.contains { $0.id == "estimated-cost" })
        XCTAssertEqual(section.rows.first { $0.id == "skipped-sessions" }?.value, "1")
        XCTAssertEqual(section.rows.first { $0.id == "malformed-records" }?.value, "1")
        XCTAssertEqual(section.rows.first { $0.id == "sessions" }?.value, "2")
    }

    func testAbsentStoreIsNotDetected() async {
        let provider = VibeUsageProvider(
            aggregator: VibeJournalAggregator(storeRoot: storeRoot, now: { Self.now }))

        let state = await provider.refresh()

        XCTAssertEqual(state, .notDetected)
    }

    func testEmptyStorePopulatesZeroStateWithoutErrors() async throws {
        try FileManager.default.createDirectory(at: storeRoot, withIntermediateDirectories: true)
        let provider = VibeUsageProvider(aggregator: aggregator(modelName: { _, _ in nil }))

        let state = await provider.refresh()

        guard case .populated(let section) = state else {
            return XCTFail("Expected populated, got \(state)")
        }
        XCTAssertEqual(section.rows.map(\.id), ["sessions", "tokens-24h", "tokens-7d", "tokens-total"])
        XCTAssertTrue(section.rows.allSatisfy { $0.value == "0" })
    }

    // MARK: - Fixtures

    private func aggregator(modelName: @escaping VibeJournalAggregator.ModelNameSource) -> VibeJournalAggregator {
        VibeJournalAggregator(storeRoot: storeRoot, modelNameSource: modelName, now: { Self.now })
    }

    private func writeSession(_ id: String, storeFormat: String? = "mistral.vibe.unified-session-store/v1",
                              journal: [String], modelName: String?) throws {
        let directory = storeRoot.appending(path: id, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let storeFormat {
            let current: [String: Any] = ["session_id": id, "store_format": storeFormat]
            try Self.jsonData(current).write(to: directory.appending(path: "CURRENT"))
        }
        let journalDirectory = directory.appending(path: "journal", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: journalDirectory, withIntermediateDirectories: true)
        try journal.joined(separator: "\n").data(using: .utf8)!
            .write(to: journalDirectory.appending(path: "000000000000.jsonl"))
        if let modelName {
            let meta: [String: Any] = ["session_id": id, "config": ["model_name": modelName]]
            try Self.jsonData(meta).write(to: directory.appending(path: "meta.json"))
        }
    }

    private func usageRecord(sequence: Int, actionID: String,
                             input: Int, cached: Int = 0, output: Int = 0) -> String {
        let usage: [String: Any] = ["input_tokens": input, "cached_input_tokens": cached,
                                    "output_tokens": output,
                                    "total_tokens": input + cached + output]
        let record: [String: Any] = ["type": "action_result", "sequence": sequence,
                                     "payload": ["action_id": actionID,
                                                 "result": ["result": ["usage": usage]]]]
        return String(decoding: Self.jsonData(record), as: UTF8.self)
    }

    private func coreInputRecord(sequence: Int, actionID: String, timeUnixMs: Int64) -> String {
        let record: [String: Any] = ["type": "core_input", "sequence": sequence,
                                     "payload": ["input": [
                                        "command": ["action_id": actionID],
                                        "determinism": ["time_unix_ms": timeUnixMs],
                                     ]]]
        return String(decoding: Self.jsonData(record), as: UTF8.self)
    }

    private func milliseconds(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1_000)
    }

    private static func jsonData(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }
}
