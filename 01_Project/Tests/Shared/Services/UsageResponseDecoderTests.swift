import Foundation
import XCTest
@testable import LLMUsageStatus

/// Synthetic direct-REST shapes only; no account responses or credentials.
final class UsageResponseDecoderTests: XCTestCase {
    private let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let firstExpiry = "2030-01-01T00:00:00Z"
    private let laterExpiry = "2031-01-01T00:00:00.500Z"

    func testWindowsAreClassifiedByExactDurationInEitherOrder() throws {
        for swapped in [false, true] {
            let weekly = window(seconds: 604_800, used: 42.25)
            let short = window(seconds: 18_000, used: 7)
            let snapshot = try decode(["rate_limit": [
                "primary_window": swapped ? short : weekly,
                "secondary_window": swapped ? weekly : short
            ]])
            XCTAssertEqual(snapshot.weekly?.usedPercentage, 42.25)
            XCTAssertEqual(snapshot.fiveHour?.usedPercentage, 7)
            XCTAssertEqual(snapshot.fetchedAt, fetchedAt)
        }
    }

    func testMissingAndUnknownDurationNeverSubstituteForWeekly() throws {
        for duration: Any in [86_400, 604_800.5, true, "604800", NSNull()] {
            let snapshot = try decode(["rate_limit": [
                "primary_window": window(seconds: duration, used: 12),
                "secondary_window": window(seconds: 18_000, used: 25)
            ]])
            XCTAssertNil(snapshot.weekly)
            XCTAssertEqual(snapshot.fiveHour?.usedPercentage, 25)
        }
        XCTAssertNil(try decode([:]).weekly)
    }

    func testMalformedWindowDoesNotDiscardIndependentFields() throws {
        for invalid: Any in [true, "25", "NaN", "Infinity", NSNull(), ["bad": 1]] {
            let snapshot = try decode(["rate_limit": [
                "primary_window": window(seconds: 604_800, used: invalid),
                "secondary_window": window(seconds: 18_000, used: 9)
            ], "credits": ["balance": "1.25"], "rate_limit_reset_credits": ["available_count": 2]])
            XCTAssertNil(snapshot.weekly)
            XCTAssertEqual(snapshot.fiveHour?.usedPercentage, 9)
            XCTAssertEqual(snapshot.credits, .available(Decimal(string: "1.25")!))
            XCTAssertEqual(snapshot.resets.availableCount, 2)
        }
    }

    func testNearDurationFractionalTokensCannotRoundIntoRecognizedWindows() throws {
        for token in ["604800.00000000000001", "604800.000000000000000000000000000000000001",
                      "18000.0000000000000001", "18000.0000000000000000000000000000000000001"] {
            let payload = Data("{\"rate_limit\":{\"primary_window\":{\"limit_window_seconds\":\(token),\"used_percent\":12}}}".utf8)
            let snapshot = try UsageResponseDecoder.decodeUsage(payload, fetchedAt: fetchedAt)
            XCTAssertNil(snapshot.weekly, token)
            XCTAssertNil(snapshot.fiveHour, token)
        }
    }

    func testInvalidMissingAndHugeResetTimestampsAreUnknown() throws {
        for invalid: Any in [true, "1800000000", NSNull(), 0, -1, 1e300] {
            let snapshot = try decode(["rate_limit": [
                "primary_window": window(seconds: 604_800, used: 12, reset: invalid)
            ]])
            XCTAssertEqual(snapshot.weekly?.usedPercentage, 12)
            XCTAssertNil(snapshot.weekly?.resetsAt)
        }
        let missing = try decode(["rate_limit": ["primary_window": [
            "limit_window_seconds": 604_800, "used_percent": 12
        ]]])
        XCTAssertNil(missing.weekly?.resetsAt)
        let future = try decode(["rate_limit": [
            "primary_window": window(seconds: 604_800, used: 12, reset: 2_000_000_000.25)
        ]])
        XCTAssertEqual(future.weekly?.resetsAt, Date(timeIntervalSince1970: 2_000_000_000.25))
    }

    func testDecimalCreditBalancePreservesPrecisionAndZero() throws {
        for text in ["0", "0.00", "12345678901234567890.123456789012345678", "0.00000000000000000001", "+0012.3400"] {
            XCTAssertEqual(try decode(["credits": ["balance": text]]).credits,
                           .available(Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!))
        }
    }

    func testInvalidBalancesAreUnavailableRatherThanRoundedOrPrefixParsed() throws {
        let tiny = "0." + String(repeating: "0", count: 200) + "1"
        let huge = "1" + String(repeating: "0", count: 200)
        for invalid: Any in ["", " 1.2", "1.2 ", "1.2\n", "1.2credits", "NaN", "Infinity", "1,234.5", "1e3",
                             "123456789012345678901234567890123456789", tiny, huge, 1.2, true, NSNull()] {
            XCTAssertEqual(try decode(["credits": ["balance": invalid, "has_credits": true]]).credits,
                           .unavailable, "Unexpected accepted balance: \(invalid)")
        }
    }

    func testUnlimitedPrecedesBalanceAndBooleanFlagsDoNotInventBalance() throws {
        XCTAssertEqual(try decode(["credits": ["unlimited": true, "balance": "2"]]).credits, .unlimited)
        XCTAssertEqual(try decode(["credits": ["unlimited": true, "balance": NSNull()]]).credits, .unlimited)
        for hasCredits in [false, true] {
            XCTAssertEqual(try decode(["credits": ["has_credits": hasCredits]]).credits, .unavailable)
        }
        XCTAssertEqual(try decode(["credits": ["unlimited": 1]]).credits, .unavailable)
    }

    func testCountIsAuthoritativeAndAcceptsGenuineZero() throws {
        for count in [0, 4] {
            let snapshot = try primary(count: count)
            XCTAssertEqual(snapshot.resets.availableCount, count)
            XCTAssertEqual(snapshot.resets.detailQuality, .unavailable)
            XCTAssertEqual(snapshot.resets.expiry, count == 0 ? .noPasses : .unavailable)
        }
        for invalid: Any in [true, -1, 1.5, "2", NSNull(), 1e300] {
            XCTAssertNil(try primary(count: invalid).resets.availableCount)
        }
    }

    func testNearIntegerCountsAreRejectedWithoutRounding() throws {
        for token in ["1.00000000000000000001", "1.0000000000000000000000000000000000000001"] {
            let primaryData = Data("{\"rate_limit_reset_credits\":{\"available_count\":\(token)}}".utf8)
            XCTAssertNil(try UsageResponseDecoder.decodeUsage(primaryData, fetchedAt: fetchedAt).resets.availableCount)
            let detailData = Data("{\"available_count\":\(token),\"credits\":[{\"id\":\"a\",\"status\":\"available\",\"reset_type\":\"codex_rate_limits\",\"expires_at\":\"2030-01-01T00:00:00Z\"}]}".utf8)
            let result = UsageResponseDecoder.addingResetDetails(detailData, to: try primary(count: 1), now: now)
            XCTAssertEqual(result.resets.detailQuality, .partial)
            XCTAssertEqual(result.resets.expiry, .earliestReported(iso(firstExpiry)))
        }
    }

    func testMalformedOptionalSectionsDoNotDiscardValidQuota() throws {
        let snapshot = try decode(["rate_limit": ["primary_window": window(seconds: 604_800, used: 20)],
                                   "credits": [1, 2], "rate_limit_reset_credits": "bad"])
        XCTAssertEqual(snapshot.weekly?.remainingPercentage, 80)
        XCTAssertEqual(snapshot.credits, .unavailable)
        XCTAssertNil(snapshot.resets.availableCount)
    }

    func testNonobjectAndInvalidPrimaryJSONThrow() {
        for text in ["[]", "null", "not json"] {
            XCTAssertThrowsError(try UsageResponseDecoder.decodeUsage(Data(text.utf8), fetchedAt: fetchedAt))
        }
    }

    func testCompleteUnsortedUniqueDetailsProduceNextExpiry() throws {
        let rows = [row("later", expiry: laterExpiry), row("first", expiry: firstExpiry), row("first", expiry: firstExpiry)]
        let result = try enriched(count: 2, rows: rows)
        XCTAssertEqual(result.resets.availableCount, 2)
        XCTAssertEqual(result.resets.detailQuality, .complete)
        XCTAssertEqual(result.resets.expiry, .next(iso(firstExpiry)))
        XCTAssertEqual(result.weekly?.usedPercentage, 20)
        XCTAssertEqual(result.credits, .available(Decimal(string: "12.5")!))
        XCTAssertEqual(result.fetchedAt, fetchedAt)
    }

    func testFractionalISOExpiryIsAccepted() throws {
        XCTAssertEqual(try enriched(count: 1, rows: [row("a", expiry: laterExpiry)]).resets.expiry,
                       .next(iso(laterExpiry)))
    }

    func testCappedDetailsUseEarliestReportedWithoutChangingCount() throws {
        let result = try enriched(count: 5, rows: [row("b", expiry: laterExpiry), row("a", expiry: firstExpiry)])
        XCTAssertEqual(result.resets.availableCount, 5)
        XCTAssertEqual(result.resets.detailQuality, .partial)
        XCTAssertEqual(result.resets.expiry, .earliestReported(iso(firstExpiry)))
    }

    func testNullMissingAndMalformedExpiryPreventGuaranteedNext() throws {
        for expiry: Any in [NSNull(), "not a date", "2030-01-01T00:00:00Zjunk", "2030-02-30T00:00:00Z", 1_893_456_000] {
            let result = try enriched(count: 2, rows: [row("a", expiry: firstExpiry), row("unknown", expiry: expiry)])
            XCTAssertEqual(result.resets.detailQuality, .partial)
            XCTAssertEqual(result.resets.expiry, .earliestReported(iso(firstExpiry)))
        }
        var missing = row("missing", expiry: firstExpiry)
        missing.removeValue(forKey: "expires_at")
        XCTAssertEqual(try enriched(count: 1, rows: [missing]).resets.expiry, .unavailable)
        XCTAssertEqual(try enriched(count: 1, rows: [row("a", expiry: NSNull())]).resets.detailQuality, .partial)
    }

    func testExpiredRedeemedAndUnknownRowsCannotSupplyExpiry() throws {
        let excluded = [
            row("old", expiry: "2020-01-01T00:00:00Z"),
            row("redeemed", expiry: firstExpiry, status: "redeemed"),
            row("expired", expiry: firstExpiry, status: "expired"),
            row("future-status", expiry: firstExpiry, status: "future_status"),
            row("future-type", expiry: firstExpiry, type: "future_type")
        ]
        let result = try enriched(count: 1, rows: excluded + [row("valid", expiry: laterExpiry)])
        XCTAssertEqual(result.resets.detailQuality, .complete)
        XCTAssertEqual(result.resets.expiry, .next(iso(laterExpiry)))
        XCTAssertEqual(try enriched(count: 1, rows: excluded).resets.expiry, .unavailable)
    }

    func testEndpointCountMismatchAndExcessRowsSuppressExpiry() throws {
        let primary = try primary(count: 2)
        for reported in [0, 1, 3] {
            let result = UsageResponseDecoder.addingResetDetails(
                try data(["available_count": reported, "credits": [row("a", expiry: firstExpiry)]]), to: primary, now: now)
            XCTAssertEqual(result.resets.availableCount, 2)
            XCTAssertEqual(result.resets.detailQuality, .inconsistent)
            XCTAssertEqual(result.resets.expiry, .unavailable)
        }
        let tooMany = try enriched(count: 1, rows: [row("a", expiry: firstExpiry), row("b", expiry: laterExpiry)])
        XCTAssertEqual(tooMany.resets.detailQuality, .inconsistent)
        XCTAssertEqual(tooMany.resets.expiry, .unavailable)
    }

    func testDuplicateIDsCannotManufactureCompletenessAndConflictsSuppressExpiry() throws {
        let duplicate = try enriched(count: 2, rows: [row("a", expiry: firstExpiry), row("a", expiry: firstExpiry)])
        XCTAssertEqual(duplicate.resets.detailQuality, .partial)
        let conflict = try enriched(count: 1, rows: [row("a", expiry: firstExpiry), row("a", expiry: laterExpiry)])
        XCTAssertEqual(conflict.resets.detailQuality, .inconsistent)
        XCTAssertEqual(conflict.resets.expiry, .unavailable)
    }

    func testMissingIDsAndMalformedRowsCannotEstablishCompleteness() throws {
        var missingID = row("unused", expiry: firstExpiry)
        missingID.removeValue(forKey: "id")
        let result = try enriched(count: 1, rows: [row("a", expiry: firstExpiry), missingID, "bad"])
        XCTAssertEqual(result.resets.detailQuality, .partial)
        XCTAssertEqual(result.resets.expiry, .earliestReported(iso(firstExpiry)))
    }

    func testMissingOrMalformedDetailCountCanOnlyGivePartialEvidence() throws {
        for invalid: Any in [NSNull(), true, -1, "1"] {
            let result = UsageResponseDecoder.addingResetDetails(
                try data(["available_count": invalid, "credits": [row("a", expiry: firstExpiry)]]),
                to: try primary(count: 1), now: now)
            XCTAssertEqual(result.resets.detailQuality, .partial)
            XCTAssertEqual(result.resets.expiry, .earliestReported(iso(firstExpiry)))
        }
    }

    func testMalformedDetailsPreservePrimaryAndMakeExpiryUnavailable() throws {
        let primary = try primary(count: 3)
        for payload in [Data("bad".utf8), try data(["credits": "bad"]), try data(["available_count": 3])] {
            XCTAssertEqual(UsageResponseDecoder.addingResetDetails(payload, to: primary, now: now), primary)
        }
    }

    func testDetailsNeverInventUnknownCountAndZeroNeverHasExpiry() throws {
        for count: Any in [NSNull(), 0] {
            let primary = try primary(count: count)
            let result = UsageResponseDecoder.addingResetDetails(
                try data(["available_count": 1, "credits": [row("a", expiry: firstExpiry)]]), to: primary, now: now)
            XCTAssertEqual(result, primary)
        }
    }

    private func decode(_ object: [String: Any]) throws -> UsageSnapshot {
        try UsageResponseDecoder.decodeUsage(data(object), fetchedAt: fetchedAt)
    }

    private func data(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) }

    private func window(seconds: Any, used: Any, reset: Any = NSNull()) -> [String: Any] {
        ["limit_window_seconds": seconds, "used_percent": used, "reset_at": reset]
    }

    private func primary(count: Any) throws -> UsageSnapshot {
        try decode(["rate_limit": ["primary_window": window(seconds: 604_800, used: 20)],
                    "credits": ["balance": "12.5"], "rate_limit_reset_credits": ["available_count": count]])
    }

    private func row(_ id: String, expiry: Any, status: String = "available", type: String = "codex_rate_limits") -> [String: Any] {
        ["id": id, "reset_type": type, "status": status, "expires_at": expiry, "granted_at": "2025-01-01T00:00:00Z"]
    }

    private func enriched(count: Int, rows: [Any]) throws -> UsageSnapshot {
        UsageResponseDecoder.addingResetDetails(try data(["available_count": count, "credits": rows]),
                                               to: try primary(count: count), now: now)
    }

    private func iso(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = text.contains(".") ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter.date(from: text)!
    }
}
