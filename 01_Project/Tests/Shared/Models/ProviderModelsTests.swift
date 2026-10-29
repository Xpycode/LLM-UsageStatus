import XCTest
@testable import LLMUsageStatus

final class ProviderModelsTests: XCTestCase {
    private let referenceDate = Date(timeIntervalSince1970: 2_000_000_000)

    func testMeterClampsFiniteFractionsAndRejectsNonFinite() {
        XCTAssertEqual(SectionMeter(id: "weekly", label: "Weekly limit", fraction: 0.25)?.fraction, 0.25)
        XCTAssertEqual(SectionMeter(id: "over", label: "Over", fraction: 1.25)?.fraction, 1)
        XCTAssertEqual(SectionMeter(id: "negative", label: "Negative", fraction: -0.5)?.fraction, 0)
        for bad in [Double.nan, .infinity, -.infinity] {
            XCTAssertNil(SectionMeter(id: "bad", label: "Bad", fraction: bad))
        }
    }

    func testEstimateFlagsDefaultToAuthoritativeAndParticipateInEquality() {
        XCTAssertEqual(SectionRow(id: "tokens", label: "7-day tokens", value: "1,234").isEstimate, false)
        XCTAssertNotEqual(
            SectionRow(id: "tokens", label: "7-day tokens", value: "1,234"),
            SectionRow(id: "tokens", label: "7-day tokens", value: "1,234", isEstimate: true))
        XCTAssertNotEqual(
            SectionMeter(id: "util", label: "5-hour", fraction: 0.4),
            SectionMeter(id: "util", label: "5-hour", fraction: 0.4, isEstimate: true))
        XCTAssertNotEqual(
            SectionDeadline(id: "reset", label: "Resets", date: referenceDate),
            SectionDeadline(id: "reset", label: "Resets", date: referenceDate, isEstimate: true))
    }

    func testSectionCarriesRowsMetersDeadlinesAndTimestamp() throws {
        let row = SectionRow(id: "credits", label: "Credits", value: "12.75")
        let meter = try XCTUnwrap(SectionMeter(id: "weekly", label: "Weekly limit", fraction: 0.2))
        let section = ProviderSection(rows: [row], meters: [meter], lastUpdated: referenceDate)
        XCTAssertEqual(section.rows, [row])
        XCTAssertEqual(section.meters, [meter])
        XCTAssertTrue(section.deadlines.isEmpty)
        XCTAssertEqual(section.lastUpdated, referenceDate)

        let later = ProviderSection(rows: [row], meters: [meter], lastUpdated: referenceDate.addingTimeInterval(1))
        XCTAssertNotEqual(section, later)
    }

    func testDeadlinesRetainLabelsDatesAndOrder() {
        let first = SectionDeadline(id: "five-hour", label: "5-hour window resets",
                                    date: Date(timeIntervalSince1970: 1_000))
        let second = SectionDeadline(id: "seven-day", label: "7-day window resets",
                                     date: Date(timeIntervalSince1970: 2_000))
        let section = ProviderSection(deadlines: [first, second], lastUpdated: referenceDate)
        XCTAssertEqual(section.deadlines, [first, second])
    }

    func testSectionStatesRemainDistinct() {
        let section = ProviderSection(rows: [SectionRow(id: "credits", label: "Credits", value: "1")],
                                      lastUpdated: referenceDate)
        XCTAssertNotEqual(ProviderSectionState.notDetected, .unavailable)
        XCTAssertNotEqual(ProviderSectionState.populated(section), .notDetected)
        XCTAssertNotEqual(ProviderSectionState.populated(section), .unavailable)
        if case .populated(let payload) = ProviderSectionState.populated(section) {
            XCTAssertEqual(payload, section)
        } else {
            XCTFail("Expected populated payload to round-trip")
        }
    }

    func testFailureAndNotDetectedCopyIsPreApprovedAndLeaksNoErrorDetail() {
        XCTAssertEqual(SectionFailureMessage.loadFailed.text, "Unable to load usage. Please try again.")
        XCTAssertEqual(SectionFailureMessage.updateFailed.text, "Unable to update usage. Please try again.")
        XCTAssertEqual(ProviderSectionState.notDetectedCopy, "Not detected on this Mac.")
        let texts = [SectionFailureMessage.loadFailed.text,
                     SectionFailureMessage.updateFailed.text,
                     ProviderSectionState.notDetectedCopy]
        for text in texts {
            for leak in ["synthetic-secret", "synthetic-account", "Bearer", "http", "token", "path"] {
                XCTAssertFalse(text.contains(leak), "Published copy must not contain \(leak)")
            }
        }
    }
}
