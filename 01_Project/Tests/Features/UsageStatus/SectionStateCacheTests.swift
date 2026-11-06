import XCTest
@testable import LLMUsageStatus

/// Last-known-state persistence: write/read round-trips of the credentials-free
/// display model, and tolerant behavior on missing or corrupt storage.
final class SectionStateCacheTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appending(path: "SectionStateCacheTests-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    func testMissingFileReadsAsEmpty() {
        let cache = SectionStateCache(fileURL: fileURL)
        XCTAssertTrue(cache.loadSections().isEmpty)
    }

    func testCorruptFileReadsAsEmptyInsteadOfFailing() throws {
        try Data("this is not json".utf8).write(to: fileURL)
        let sections = SectionStateCache(fileURL: fileURL).loadSections()
        XCTAssertTrue(sections.isEmpty)
    }

    func testStorePreservesOtherProvidersSections() {
        let cache = SectionStateCache(fileURL: fileURL)
        let codex = Self.section(timestamp: 1_000)
        let claude = Self.section(timestamp: 2_000)
        cache.store(codex, for: "codex")
        cache.store(claude, for: "claude")

        let loaded = SectionStateCache(fileURL: fileURL).loadSections()
        XCTAssertEqual(loaded["codex"], codex)
        XCTAssertEqual(loaded["claude"], claude)
    }

    func testFullSectionSurvivesEncodeDecodeRoundTrip() {
        // Every section shape must stay Codable-complete: a field silently
        // dropped by persistence would silently change the next-launch seed.
        let section = ProviderSection(
            rows: [SectionRow(id: "credits", label: "Credits", value: "12.75", isEstimate: true)],
            meters: [SectionMeter(id: "weekly", label: "Weekly limit", fraction: 0.32, isEstimate: false)!],
            deadlines: [SectionDeadline(id: "weekly-reset", label: "Weekly limit", date: Date(timeIntervalSince1970: 1_800_000_900), isEstimate: true)],
            headline: SectionHeadline(windowLabel: "Weekly limit", fractionLeft: 0.68,
                                      resetsAt: Date(timeIntervalSince1970: 1_800_000_900),
                                      dailyBudget: SectionDailyBudget(amount: Decimal(string: "7417273")!,
                                                                      unitText: "credits", isEstimate: false),
                                      isEstimate: true),
            glanceLine: SectionGlanceLine("≈ $2.41+ · 5.3K tokens · 24 hours", isEstimate: true),
            note: .refreshClaudeSignIn,
            lastUpdated: Date(timeIntervalSince1970: 1_800_000_000))
        let cache = SectionStateCache(fileURL: fileURL)
        cache.store(section, for: "codex")

        XCTAssertEqual(SectionStateCache(fileURL: fileURL).loadSections()["codex"], section)
    }

    private static func section(timestamp: TimeInterval) -> ProviderSection {
        ProviderSection(rows: [SectionRow(id: "credits", label: "Credits", value: "12.75")],
                        glanceLine: SectionGlanceLine("1.2M tokens · 24 hours", isEstimate: true),
                        note: .refreshClaudeSignIn,
                        lastUpdated: Date(timeIntervalSince1970: timestamp))
    }
}
