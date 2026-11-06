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
        let cost = VibeRateCard.cost(inputTokens: 100, cachedTokens: 5_000, outputTokens: 200,
                                        prices: VibeRateCard.resolve("mistral-medium-3.5")!)
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

    func testCostLineSuppressesWhenNoUsedSessionIsPriced() async throws {
        try writeSession("session-unknown", journal: [
            usageRecord(sequence: 1, actionID: "u1", input: 100, output: 10),
            coreInputRecord(sequence: 2, actionID: "u1", timeUnixMs: milliseconds(Self.now)),
        ], modelName: nil)
        let provider = VibeUsageProvider(aggregator: aggregator(modelName: { _, _ in "not-a-mistral-model" }))

        let state = await provider.refresh()

        guard case .populated(let section) = state else {
            return XCTFail("Expected populated, got \(state)")
        }
        // A floor of zero over an empty priced set says nothing; no row.
        XCTAssertFalse(section.rows.contains { $0.id == "estimated-cost" })
    }

    func testMixedModelsShowPartialCostFloorLabeledWithUnpricedCount() async throws {
        try writeSession("session-priced", journal: [
            usageRecord(sequence: 1, actionID: "p1", input: 500_000, output: 100_000),
            coreInputRecord(sequence: 2, actionID: "p1", timeUnixMs: milliseconds(Self.now)),
        ], modelName: "mistral-medium-3.5")
        try writeSession("session-unpriced", journal: [
            usageRecord(sequence: 1, actionID: "u1", input: 999, output: 999),
            coreInputRecord(sequence: 2, actionID: "u1", timeUnixMs: milliseconds(Self.now)),
        ], modelName: "some-unknown-model")
        let provider = VibeUsageProvider(
            aggregator: aggregator(modelName: { sessionID, _ in
                sessionID == "session-priced" ? "mistral-medium-3.5" : "some-unknown-model"
            }))

        let state = await provider.refresh()

        guard case .populated(let section) = state else {
            return XCTFail("Expected populated, got \(state)")
        }
        // 500k input + 100k output on medium-3.5 = $0.75 + $0.75 = $1.50.
        // The floor is a partial sum: "+" plus the unpriced-session count,
        // never presented as the complete spend. Expected formatting mirrors
        // the production formatter, since currency output is locale-dependent.
        let pricedCost = VibeRateCard.cost(inputTokens: 500_000, cachedTokens: 0, outputTokens: 100_000,
                                           prices: VibeRateCard.resolve("mistral-medium-3.5")!)
        let costRow = section.rows.first { $0.id == "estimated-cost" }
        XCTAssertEqual(costRow, SectionRow(id: "estimated-cost", label: "Estimated cost",
                                           value: pricedCost.formatted(.currency(code: "USD")) + "+ · 1 session unpriced",
                                           isEstimate: true))
        // A partial floor is not good enough for the budget headline.
        XCTAssertNil(section.headline)
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

    // MARK: - Monthly budget headline

    func testBudgetHeadlineEstimatesPercentLeftAndDailyBudget() async throws {
        try writeSession("session-budget", journal: [
            usageRecord(sequence: 1, actionID: "b1", input: 100, cached: 5_000, output: 200),
            coreInputRecord(sequence: 2, actionID: "b1", timeUnixMs: milliseconds(Self.now)),
        ], modelName: "mistral-medium-3.5")
        let report = await aggregator(modelName: { _, _ in "mistral-medium-3.5" }).scan()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!

        let section = VibeUsageProvider.section(for: report,
                                                budget: VibeBudget(amountUSD: 300, resetDay: 15),
                                                now: now, calendar: calendar)

        let cost = VibeRateCard.cost(inputTokens: 100, cachedTokens: 5_000, outputTokens: 200,
                                        prices: VibeRateCard.resolve("mistral-medium-3.5")!)
        let expectedHeadline = SectionHeadline(
            windowLabel: "Monthly budget",
            fractionLeft: 1 - Double(truncating: cost as NSDecimalNumber) / 300,
            resetsAt: calendar.date(from: DateComponents(year: 2025, month: 1, day: 15)),
            dailyBudget: SectionDailyBudget(amount: Decimal(300) - cost, unitText: "$", isEstimate: true),
            isEstimate: true)
        XCTAssertEqual(section.headline, expectedHeadline)
    }

    func testBudgetWithoutResolvableCostHasNoHeadline() async throws {
        try writeSession("session-unknown-budget", journal: [
            usageRecord(sequence: 1, actionID: "u1", input: 100, output: 10),
            coreInputRecord(sequence: 2, actionID: "u1", timeUnixMs: milliseconds(Self.now)),
        ], modelName: nil)
        let report = await aggregator(modelName: { _, _ in "unknown-model" }).scan()

        let section = VibeUsageProvider.section(for: report,
                                                budget: VibeBudget(amountUSD: 300, resetDay: 15))
        XCTAssertNil(section.headline)
    }

    func testNoBudgetMeansNoHeadline() async throws {
        try writeSession("session-no-budget", journal: [
            usageRecord(sequence: 1, actionID: "n1", input: 100, output: 10),
            coreInputRecord(sequence: 2, actionID: "n1", timeUnixMs: milliseconds(Self.now)),
        ], modelName: "mistral-medium-3.5")
        let report = await aggregator(modelName: { _, _ in "mistral-medium-3.5" }).scan()
        XCTAssertNil(VibeUsageProvider.section(for: report, budget: nil).headline)
    }

    func testGlanceLineShowsCostAndTokensForLast24Hours() async throws {
        try writeSession("session-glance", journal: [
            usageRecord(sequence: 1, actionID: "g1", input: 100, cached: 5_000, output: 200),
            coreInputRecord(sequence: 2, actionID: "g1", timeUnixMs: milliseconds(Self.now)),
        ], modelName: "mistral-medium-3.5")
        let report = await aggregator(modelName: { _, _ in "mistral-medium-3.5" }).scan()

        let section = VibeUsageProvider.section(for: report, budget: nil)

        let cost = VibeRateCard.cost(inputTokens: 100, cachedTokens: 5_000, outputTokens: 200,
                                        prices: VibeRateCard.resolve("mistral-medium-3.5")!)
        let expected = "≈ \(cost.formatted(.currency(code: "USD"))) · \(5_300.formatted(.number.notation(.compactName).locale(.current))) tokens · 24 hours"
        XCTAssertEqual(section.glanceLine, SectionGlanceLine(expected, isEstimate: true))
    }

    func testGlanceLineMarksPartialCostWithFloorMarker() async throws {
        try writeSession("session-glance-priced", journal: [
            usageRecord(sequence: 1, actionID: "g1", input: 100, cached: 5_000, output: 200),
            coreInputRecord(sequence: 2, actionID: "g1", timeUnixMs: milliseconds(Self.now)),
        ], modelName: "mistral-medium-3.5")
        try writeSession("session-glance-unpriced", journal: [
            usageRecord(sequence: 1, actionID: "u1", input: 4_900, output: 100),
            coreInputRecord(sequence: 2, actionID: "u1", timeUnixMs: milliseconds(Self.now)),
        ], modelName: "some-unknown-model")
        let report = await aggregator(modelName: { sessionID, _ in
            sessionID == "session-glance-priced" ? "mistral-medium-3.5" : "some-unknown-model"
        }).scan()

        let section = VibeUsageProvider.section(for: report, budget: nil)

        let pricedCost = VibeRateCard.cost(inputTokens: 100, cachedTokens: 5_000, outputTokens: 200,
                                           prices: VibeRateCard.resolve("mistral-medium-3.5")!)
        let tokens = 10_300.formatted(.number.notation(.compactName).locale(.current))
        let expected = "≈ \(pricedCost.formatted(.currency(code: "USD")))+ · \(tokens) tokens · 24 hours"
        XCTAssertEqual(section.glanceLine, SectionGlanceLine(expected, isEstimate: true))
    }

    func testGlanceLineOmitsCostWhenWindowPriceUnresolvable() async throws {
        try writeSession("session-glance-unknown", journal: [
            usageRecord(sequence: 1, actionID: "u1", input: 100, output: 10),
            coreInputRecord(sequence: 2, actionID: "u1", timeUnixMs: milliseconds(Self.now)),
        ], modelName: nil)
        let report = await aggregator(modelName: { _, _ in "unknown-model" }).scan()

        let section = VibeUsageProvider.section(for: report, budget: nil)

        XCTAssertEqual(section.glanceLine,
                       SectionGlanceLine("110 tokens · 24 hours", isEstimate: true))
    }

    func testGlanceLineSuppressedWhenBudgetHeadlinePresent() async throws {
        try writeSession("session-glance-budget", journal: [
            usageRecord(sequence: 1, actionID: "b1", input: 100, output: 10),
            coreInputRecord(sequence: 2, actionID: "b1", timeUnixMs: milliseconds(Self.now)),
        ], modelName: "mistral-medium-3.5")
        let report = await aggregator(modelName: { _, _ in "mistral-medium-3.5" }).scan()

        let section = VibeUsageProvider.section(for: report,
                                                budget: VibeBudget(amountUSD: 300, resetDay: 15))

        XCTAssertNotNil(section.headline)
        XCTAssertNil(section.glanceLine)
    }

    func testGlanceLineSuppressedWhenWindowIsEmpty() async throws {
        try writeSession("session-glance-old", journal: [
            usageRecord(sequence: 1, actionID: "o1", input: 100, output: 10),
            coreInputRecord(sequence: 2, actionID: "o1", timeUnixMs: milliseconds(Self.now.addingTimeInterval(-48 * 3_600))),
        ], modelName: "mistral-medium-3.5")
        let report = await aggregator(modelName: { _, _ in "mistral-medium-3.5" }).scan()

        XCTAssertNil(VibeUsageProvider.section(for: report, budget: nil).glanceLine)
    }

    func testNextResetDateClampsToMonthLengthAndRollsForward() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let jan20 = calendar.date(from: DateComponents(year: 2025, month: 1, day: 20))!

        // Day already passed this month -> rolls to next month.
        XCTAssertEqual(VibeUsageProvider.nextResetDate(onOrAfter: jan20, dayOfMonth: 15, calendar: calendar),
                       calendar.date(from: DateComponents(year: 2025, month: 2, day: 15)))
        // Day 31 clamps to February's 28 days.
        let feb1 = calendar.date(from: DateComponents(year: 2025, month: 2, day: 1))!
        XCTAssertEqual(VibeUsageProvider.nextResetDate(onOrAfter: feb1, dayOfMonth: 31, calendar: calendar),
                       calendar.date(from: DateComponents(year: 2025, month: 2, day: 28)))
        // Out-of-range day yields nil.
        XCTAssertNil(VibeUsageProvider.nextResetDate(onOrAfter: jan20, dayOfMonth: 0, calendar: calendar))
    }

    func testBudgetReadIgnoresMalformedDefaults() {
        let name = "VibeUsageProviderTests.Budget-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        XCTAssertNil(VibeUsageProvider.budget(from: defaults))
        defaults.set(-5.0, forKey: UsagePreferenceKeys.vibeMonthlyBudgetUSD)
        XCTAssertNil(VibeUsageProvider.budget(from: defaults))
        defaults.set(300.0, forKey: UsagePreferenceKeys.vibeMonthlyBudgetUSD)
        defaults.set(45, forKey: UsagePreferenceKeys.vibeBudgetResetDay)
        XCTAssertNil(VibeUsageProvider.budget(from: defaults))
        defaults.set(15, forKey: UsagePreferenceKeys.vibeBudgetResetDay)
        XCTAssertEqual(VibeUsageProvider.budget(from: defaults),
                       VibeBudget(amountUSD: 300, resetDay: 15))
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
