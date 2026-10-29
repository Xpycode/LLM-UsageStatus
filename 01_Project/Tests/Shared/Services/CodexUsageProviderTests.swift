import Foundation
import XCTest
@testable import LLMUsageStatus

/// Conformance of the verbatim Codex port to the normalized provider seam.
/// All auth and HTTP data below are synthetic; no URLSession or auth-file reads occur.
final class CodexUsageProviderTests: XCTestCase {
    private static let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
    private static let auth = Data(#"{"tokens":{"access_token":"synthetic-token","account_id":"synthetic-account"}}"#.utf8)
    private static let primary = Data("""
    {"rate_limit":{"primary_window":{"limit_window_seconds":604800,"used_percent":20},
    "secondary_window":{"limit_window_seconds":18000,"used_percent":7}},
    "credits":{"balance":"12.5"},"rate_limit_reset_credits":{"available_count":null}}
    """.utf8)

    func testProviderIdentity() {
        let provider = CodexUsageService()
        XCTAssertEqual(provider.id, "codex")
        XCTAssertEqual(provider.displayName, "Codex")
    }

    func testSuccessfulRefreshPublishesNormalizedSection() async throws {
        let state = await providerSuccess.refresh()
        guard case .populated(let section) = state else {
            return XCTFail("Expected populated, got \(state)")
        }
        XCTAssertEqual(section.lastUpdated, Self.timestamp)
        XCTAssertEqual(section.meters, [
            SectionMeter(id: "weekly-limit", label: "Weekly limit", fraction: 0.2),
            SectionMeter(id: "five-hour-limit", label: "5-hour limit", fraction: 0.07),
        ])
        XCTAssertEqual(section.rows, [
            SectionRow(id: "credits", label: "Credits",
                       value: CreditBalance.available(Decimal(string: "12.5")!).displayLabel()),
            SectionRow(id: "reset-passes", label: "Reset passes", value: "Unavailable"),
        ])
        XCTAssertTrue(section.deadlines.isEmpty)
    }

    func testSectionMappingCarriesResetsExpiryAndUnlimitedCredits() {
        let now = Self.timestamp
        let snapshot = UsageSnapshot(
            weekly: QuotaWindow(usedPercentage: 32, resetsAt: now.addingTimeInterval(90_000)),
            fiveHour: QuotaWindow(usedPercentage: 18, resetsAt: now.addingTimeInterval(3_600)),
            credits: .unlimited,
            resets: ResetSummary(availableCount: 3, detailQuality: .complete,
                                 expiry: .next(now.addingTimeInterval(172_800))),
            fetchedAt: now)
        let section = CodexUsageService.section(for: snapshot)
        XCTAssertEqual(section.meters.map(\.id), ["weekly-limit", "five-hour-limit"])
        XCTAssertEqual(section.meters.map(\.fraction), [0.32, 0.18])
        XCTAssertEqual(section.rows, [
            SectionRow(id: "credits", label: "Credits", value: "Unlimited"),
            SectionRow(id: "reset-passes", label: "Reset passes", value: "3"),
        ])
        XCTAssertEqual(section.deadlines, [
            SectionDeadline(id: "weekly-reset", label: "Weekly limit", date: now.addingTimeInterval(90_000)),
            SectionDeadline(id: "five-hour-reset", label: "5-hour limit", date: now.addingTimeInterval(3_600)),
            SectionDeadline(id: "pass-expiry", label: "Next reset-pass expiry", date: now.addingTimeInterval(172_800)),
        ])
        XCTAssertEqual(section.lastUpdated, now)
    }

    func testZeroPassesOmitExpiryDeadline() {
        let snapshot = UsageSnapshot(weekly: nil, fiveHour: nil, credits: .unavailable,
                                     resets: ResetSummary(availableCount: 0), fetchedAt: Self.timestamp)
        let section = CodexUsageService.section(for: snapshot)
        XCTAssertTrue(section.meters.isEmpty)
        XCTAssertTrue(section.deadlines.isEmpty)
        XCTAssertEqual(section.rows.map(\.value), ["Unavailable", "0"])
    }

    func testMissingSignInMapsToNotDetected() async {
        let provider = CodexUsageService(transport: { _ in fatalError("must not be reached") },
                                         authInput: { throw CocoaError(.fileReadNoSuchFile) },
                                         now: { Self.timestamp })
        let state = await provider.refresh()
        XCTAssertEqual(state, .notDetected)
    }

    func testTransportFailureMapsToUnavailableWithoutLeakingDetails() async {
        let provider = CodexUsageService(
            transport: { _ in throw NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut,
                                           userInfo: [NSLocalizedDescriptionKey: "synthetic private transport error"]) },
            authInput: { Self.auth },
            now: { Self.timestamp })
        let state = await provider.refresh()
        XCTAssertEqual(state, .unavailable)
    }

    func testCancelledFetchMapsToUnavailable() async {
        let provider = CodexUsageService(transport: { _ in throw CancellationError() },
                                         authInput: { Self.auth },
                                         now: { Self.timestamp })
        let state = await provider.refresh()
        XCTAssertEqual(state, .unavailable)
    }

    private var providerSuccess: CodexUsageService {
        CodexUsageService(transport: { _ in
            (Self.primary, HTTPURLResponse(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!,
                                           statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }, authInput: { Self.auth }, now: { Self.timestamp })
    }
}
