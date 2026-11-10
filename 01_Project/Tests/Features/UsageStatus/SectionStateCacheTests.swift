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

    func testStoreUnderRegularFileParentDoesNotCrashAndLoadStaysEmpty() throws {
        // The "directory" component is a regular file, so directory creation
        // and the write both fail; the cache must swallow that (after logging).
        let blocker = FileManager.default.temporaryDirectory
            .appending(path: "SectionStateCacheTests-blocker-\(UUID().uuidString)")
        try Data("x".utf8).write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }
        let blockedURL = blocker.appending(path: "sub/last-sections.json")

        let cache = SectionStateCache(fileURL: blockedURL)
        cache.store(Self.section(timestamp: 1_000), for: "codex")

        XCTAssertTrue(cache.loadSections().isEmpty)
    }

    func testStoreIntoReadOnlyDirectoryKeepsPriorData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "SectionStateCacheTests-dir-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }
        let url = directory.appending(path: "last-sections.json")
        let cache = SectionStateCache(fileURL: url)
        let codex = Self.section(timestamp: 1_000)
        cache.store(codex, for: "codex")

        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        cache.store(Self.section(timestamp: 2_000), for: "claude")

        // The atomic write fails in the read-only directory (unless running
        // as root); either way the file stays readable and the prior entry intact.
        XCTAssertEqual(cache.loadSections()["codex"], codex)
    }

    private static func section(timestamp: TimeInterval) -> ProviderSection {
        ProviderSection(rows: [SectionRow(id: "credits", label: "Credits", value: "12.75")],
                        glanceLine: SectionGlanceLine("1.2M tokens · 24 hours", isEstimate: true),
                        note: .refreshClaudeSignIn,
                        lastUpdated: Date(timeIntervalSince1970: timestamp))
    }
}
