import XCTest
@testable import LLMUsageStatus

final class UsageSnapshotTests: XCTestCase {
    func testCreditDisplayRoundsForReadabilityAndDistinguishesTinyBalances() throws {
        let locale = Locale(identifier: "en_US")
        for (text, expected) in [
            ("0.0000000000000000000000000000000000000001", "<0.01"),
            ("12345678901234567890.123456789", "12,345,678,901,234,567,890.12"),
            ("61672.731894", "61,672.73"), ("0.009", "<0.01"),
            ("0.01", "0.01"), ("1.236", "1.24"),
            ("1234.5", "1,234.5"), ("0", "0")
        ] {
            let balance = try XCTUnwrap(Decimal(string: text, locale: locale))
            XCTAssertEqual(CreditBalance.available(balance).displayLabel(locale: locale), expected)
        }
        XCTAssertEqual(CreditBalance.available(Decimal(string: "1234.5")!)
            .displayLabel(locale: Locale(identifier: "de_DE")), "1.234,5")
        XCTAssertEqual(CreditBalance.available(Decimal(string: "61672.731894")!)
            .displayLabel(locale: Locale(identifier: "de_DE")), "61.672,73")
        XCTAssertEqual(CreditBalance.available(Decimal(string: "0.001")!)
            .displayLabel(locale: Locale(identifier: "de_DE")), "<0,01")
        XCTAssertEqual(CreditBalance.unlimited.displayLabel(locale: locale), "Unlimited")
        XCTAssertEqual(CreditBalance.unavailable.displayLabel(locale: locale), "Unavailable")
    }

    func testRemainingPercentageIsComplementOfUsage() {
        let quota = QuotaWindow(usedPercentage: 35.25, resetsAt: nil)
        XCTAssertEqual(quota?.remainingPercentage, 64.75)
        XCTAssertNil(quota?.resetsAt)
    }

    func testDisplayClampingPreservesFiniteSourcePercentage() {
        let overLimit = QuotaWindow(usedPercentage: 125, resetsAt: nil)
        let negative = QuotaWindow(usedPercentage: -5, resetsAt: nil)
        XCTAssertEqual(overLimit?.usedPercentage, 125)
        XCTAssertEqual(overLimit?.clampedUsedPercentage, 100)
        XCTAssertEqual(overLimit?.remainingPercentage, 0)
        XCTAssertEqual(negative?.usedPercentage, -5)
        XCTAssertEqual(negative?.clampedUsedPercentage, 0)
        XCTAssertEqual(negative?.remainingPercentage, 100)
    }

    func testNonfiniteUsageCannotEnterSnapshot() {
        for value in [Double.nan, .infinity, -.infinity] {
            XCTAssertNil(QuotaWindow(usedPercentage: value, resetsAt: nil))
        }
    }

    func testUnknownAndZeroResetCountsRemainDistinct() {
        XCTAssertNil(ResetSummary(availableCount: nil).availableCount)
        XCTAssertEqual(ResetSummary(availableCount: nil).expiry, .unavailable)
        XCTAssertEqual(ResetSummary(availableCount: 0).expiry, .noPasses)
        XCTAssertNil(ResetSummary(availableCount: -1).availableCount)
    }

    func testUnavailableAndInconsistentDetailsCannotExposeExpiry() {
        let date = Date(timeIntervalSince1970: 2_000_000_000)
        for quality: ResetSummary.DetailQuality in [.unavailable, .inconsistent] {
            XCTAssertEqual(ResetSummary(availableCount: 2, detailQuality: quality, expiry: .next(date)).expiry,
                           .unavailable)
        }
    }
}
