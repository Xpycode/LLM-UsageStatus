import Foundation
import XCTest
@testable import LLMUsageStatus

/// Conformance of the Claude sources to the normalized provider seam.
/// All tokens and HTTP responses below are synthetic; fixtures live in
/// disposable temp directories, never in the real ~/.claude or Keychain.
final class ClaudeUsageProviderTests: XCTestCase {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var transcriptsRoot: URL!

    override func setUp() {
        super.setUp()
        transcriptsRoot = FileManager.default.temporaryDirectory
            .appending(path: "ClaudeUsageProviderTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: transcriptsRoot)
        super.tearDown()
    }

    func testProviderIdentity() {
        let provider = ClaudeUsageProvider()
        XCTAssertEqual(provider.id, "claude")
        XCTAssertEqual(provider.displayName, "Claude Code")
    }

    func testEndpointSuccessPublishesAuthoritativeMetersAndDeadlines() async throws {
        let body = Data("""
        {"five_hour":{"utilization":42,"resets_at":1893456000},
        "seven_day":{"utilization":81,"resets_at":"2027-01-21T00:00:00Z"}}
        """.utf8)
        let provider = ClaudeUsageProvider(
            oauthService: oauth(transport: .success(body), token: "synthetic-claude-token"),
            logAggregator: ClaudeLogAggregator(root: absentRoot(), now: { Self.now }))

        let state = await provider.refresh()

        guard case .populated(let section) = state else {
            return XCTFail("Expected populated, got \(state)")
        }
        XCTAssertEqual(section.meters, [
            SectionMeter(id: "five-hour-limit", label: "5-hour limit", fraction: 0.42),
            SectionMeter(id: "seven-day-limit", label: "7-day limit", fraction: 0.81),
        ])
        XCTAssertEqual(section.deadlines, [
            SectionDeadline(id: "five-hour-reset", label: "5-hour limit",
                            date: Date(timeIntervalSince1970: 1_893_456_000)),
            SectionDeadline(id: "seven-day-reset", label: "7-day limit",
                            date: Self.isoDate("2027-01-21T00:00:00Z")),
        ])
        XCTAssertTrue(section.rows.isEmpty)
        XCTAssertEqual(section.lastUpdated, Self.now)
        // Both windows headline in fixed order, whichever resets first.
        XCTAssertEqual(section.headlines, [
            SectionHeadline(id: "five-hour", windowLabel: "5-hour limit", fractionLeft: 1 - 0.42,
                            resetsAt: Date(timeIntervalSince1970: 1_893_456_000))!,
            SectionHeadline(id: "seven-day", windowLabel: "7-day limit", fractionLeft: 1 - 0.81,
                            resetsAt: Self.isoDate("2027-01-21T00:00:00Z"))!,
        ])
    }

    func testHeadlinesListFiveHourThenSevenDay() {
        let fiveHourReset = Self.now.addingTimeInterval(3_600)
        let usage = ClaudeOAuthUsage(
            fiveHour: ClaudeUsageWindow(utilization: 0.42, resetsAt: fiveHourReset),
            sevenDay: ClaudeUsageWindow(utilization: 0.81, resetsAt: Self.now.addingTimeInterval(600_000)),
            fetchedAt: Self.now)
        let section = ClaudeUsageProvider.section(for: usage)
        XCTAssertEqual(section.headlines, [
            SectionHeadline(id: "five-hour", windowLabel: "5-hour limit", fractionLeft: 1 - 0.42,
                            resetsAt: fiveHourReset)!,
            SectionHeadline(id: "seven-day", windowLabel: "7-day limit", fractionLeft: 1 - 0.81,
                            resetsAt: Self.now.addingTimeInterval(600_000))!,
        ])
        XCTAssertNil(section.note)
    }

    func testHeadlineIsPresentOnlyForWindowsWithUtilization() {
        let sevenDayOnly = ClaudeOAuthUsage(
            fiveHour: nil,
            sevenDay: ClaudeUsageWindow(utilization: 0.5, resetsAt: nil),
            fetchedAt: Self.now)
        XCTAssertEqual(ClaudeUsageProvider.section(for: sevenDayOnly).headlines, [
            SectionHeadline(id: "seven-day", windowLabel: "7-day limit", fractionLeft: 0.5, resetsAt: nil)!,
        ])

        let fiveHourWithoutUtilization = ClaudeOAuthUsage(
            fiveHour: ClaudeUsageWindow(utilization: nil, resetsAt: Self.now.addingTimeInterval(60)),
            sevenDay: ClaudeUsageWindow(utilization: 0.25, resetsAt: nil),
            fetchedAt: Self.now)
        XCTAssertEqual(ClaudeUsageProvider.section(for: fiveHourWithoutUtilization).headlines.map(\.id),
                       ["seven-day"])
    }

    func testMissingTokenFallsBackToLabeledLocalAggregates() async throws {
        try writeTranscript("session-a.jsonl", lines: [
            transcriptLine(hoursAgo: 1, input: 100, output: 50, cacheCreation: 10, cacheRead: 5),
            transcriptLine(hoursAgo: 2, input: 40, output: 20),
            "this is not json",
        ])
        let provider = ClaudeUsageProvider(
            oauthService: oauth(transport: .success(Data()), token: nil),
            logAggregator: ClaudeLogAggregator(root: transcriptsRoot, now: { Self.now }))

        let state = await provider.refresh()

        guard case .populated(let section) = state else {
            return XCTFail("Expected populated, got \(state)")
        }
        XCTAssertTrue(section.meters.isEmpty)
        XCTAssertTrue(section.deadlines.isEmpty)
        XCTAssertEqual(section.rows, [
            SectionRow(id: "sessions", label: "Sessions (7 days)", value: "1", isEstimate: true),
            SectionRow(id: "input-tokens", label: "Input tokens (7 days)", value: "140", isEstimate: true),
            SectionRow(id: "output-tokens", label: "Output tokens (7 days)", value: "70", isEstimate: true),
            SectionRow(id: "cache-creation-tokens", label: "Cache creation (7 days)", value: "10", isEstimate: true),
            SectionRow(id: "cache-read-tokens", label: "Cache read (7 days)", value: "5", isEstimate: true),
            SectionRow(id: "malformed-lines", label: "Skipped malformed lines", value: "1", isEstimate: true),
        ])
        // Collapsed sections hide rows, so the fallback must carry its own
        // visible line: the reason plus top-line local facts, estimate-labeled.
        XCTAssertEqual(section.glanceLine,
                       SectionGlanceLine("No Claude sign-in · 1 session · 225 tokens · 7 days",
                                         isEstimate: true))
        XCTAssertEqual(section.note, .refreshClaudeSignIn)
        XCTAssertEqual(section.lastUpdated, Self.now.addingTimeInterval(-3_600))
    }

    func testUnauthorizedFallsBackWithExpiredSignInGlanceLine() async throws {
        try writeTranscript("session-401.jsonl", lines: [transcriptLine(hoursAgo: 2, input: 10)])
        let provider = ClaudeUsageProvider(
            oauthService: oauth(transport: .status(401), token: "synthetic-claude-token"),
            logAggregator: ClaudeLogAggregator(root: transcriptsRoot, now: { Self.now }))

        let state = await provider.refresh()

        guard case .populated(let section) = state else {
            return XCTFail("Expected populated, got \(state)")
        }
        XCTAssertEqual(section.glanceLine,
                       SectionGlanceLine("Sign-in expired · 1 session · 10 tokens · 7 days",
                                         isEstimate: true))
        XCTAssertEqual(section.note, .refreshClaudeSignIn)
    }

    func testFallbackWithoutLocalUsageSaysNoLocalUsage() async throws {
        // The directory exists but carries no in-window usage: the fallback
        // stays populated and honest rather than looking broken.
        try FileManager.default.createDirectory(at: transcriptsRoot, withIntermediateDirectories: true)
        let provider = ClaudeUsageProvider(
            oauthService: oauth(transport: .success(Data()), token: nil),
            logAggregator: ClaudeLogAggregator(root: transcriptsRoot, now: { Self.now }))

        let state = await provider.refresh()

        guard case .populated(let section) = state else {
            return XCTFail("Expected populated, got \(state)")
        }
        XCTAssertEqual(section.glanceLine,
                       SectionGlanceLine("No Claude sign-in · no local usage (7 days)", isEstimate: true))
        XCTAssertEqual(section.note, .refreshClaudeSignIn)
        XCTAssertTrue(section.rows.allSatisfy { $0.value == "0" })
    }

    func testMissingTokenWithoutTranscriptsIsNotDetected() async {
        let provider = ClaudeUsageProvider(
            oauthService: oauth(transport: .success(Data()), token: nil),
            logAggregator: ClaudeLogAggregator(root: absentRoot(), now: { Self.now }))

        let state = await provider.refresh()

        XCTAssertEqual(state, .notDetected)
    }

    func testInsufficientScopeFallsBackToLabeledLocalAggregates() async throws {
        try writeTranscript("session-b.jsonl", lines: [transcriptLine(hoursAgo: 3, input: 10)])
        let provider = ClaudeUsageProvider(
            oauthService: oauth(transport: .status(403), token: "synthetic-claude-token"),
            logAggregator: ClaudeLogAggregator(root: transcriptsRoot, now: { Self.now }))

        let state = await provider.refresh()

        guard case .populated(let section) = state else {
            return XCTFail("Expected populated, got \(state)")
        }
        XCTAssertEqual(section.rows.first, SectionRow(id: "sessions", label: "Sessions (7 days)",
                                                      value: "1", isEstimate: true))
        XCTAssertEqual(section.glanceLine,
                       SectionGlanceLine("Sign-in lacks usage scope · 1 session · 10 tokens · 7 days",
                                         isEstimate: true))
    }

    func testRateLimitedDoesNotFallBackAndRetainsUnavailable() async throws {
        try writeTranscript("session-c.jsonl", lines: [transcriptLine(hoursAgo: 1, input: 10)])
        let provider = ClaudeUsageProvider(
            oauthService: oauth(transport: .status(429), token: "synthetic-claude-token"),
            logAggregator: ClaudeLogAggregator(root: transcriptsRoot, now: { Self.now }))

        let state = await provider.refresh()

        XCTAssertEqual(state, .unavailable)
    }

    func testTransportFailureIsUnavailableWithoutSurfacingDetails() async {
        let provider = ClaudeUsageProvider(
            oauthService: oauth(transport: .failure, token: "synthetic-claude-token"),
            logAggregator: ClaudeLogAggregator(root: absentRoot(), now: { Self.now }))

        let state = await provider.refresh()

        XCTAssertEqual(state, .unavailable)
    }

    // MARK: - Fixtures

    private enum TransportFixture {
        case success(Data)
        case status(Int)
        case failure
    }

    private func oauth(transport: TransportFixture, token: String?) -> ClaudeOAuthUsageService {
        struct StubTokenProvider: ClaudeTokenProviding {
            let token: String?
            func accessToken() async -> String? { token }
        }
        let transport: ClaudeOAuthUsageService.Transport = { _ in
            switch transport {
            case .success(let data):
                return (data, HTTPURLResponse(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
                                              statusCode: 200, httpVersion: nil, headerFields: nil)!)
            case .status(let code):
                return (Data(), HTTPURLResponse(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
                                                statusCode: code, httpVersion: nil, headerFields: nil)!)
            case .failure:
                throw NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut,
                               userInfo: [NSLocalizedDescriptionKey: "synthetic private transport error"])
            }
        }
        return ClaudeOAuthUsageService(transport: transport,
                                       tokenProvider: StubTokenProvider(token: token),
                                       now: { Self.now })
    }

    private func absentRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "ClaudeUsageProviderTests-absent-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    private static func isoDate(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)!
    }

    private func writeTranscript(_ name: String, lines: [String]) throws {
        try FileManager.default.createDirectory(at: transcriptsRoot, withIntermediateDirectories: true)
        try lines.joined(separator: "\n").data(using: .utf8)!
            .write(to: transcriptsRoot.appending(path: name))
    }

    private func transcriptLine(hoursAgo: TimeInterval, input: Int, output: Int = 0,
                                cacheCreation: Int = 0, cacheRead: Int = 0) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: Self.now.addingTimeInterval(-hoursAgo * 3_600))
        return """
        {"timestamp":"\(timestamp)","message":{"role":"assistant","usage":{"input_tokens":\(input),"output_tokens":\(output),"cache_creation_input_tokens":\(cacheCreation),"cache_read_input_tokens":\(cacheRead)}}}
        """
    }
}
