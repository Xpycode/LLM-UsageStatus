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

    func testHeadlineKeepsIdClampsFractionAndDefaultsSubMeters() {
        let headline = SectionHeadline(id: "five-hour", windowLabel: "5-hour limit", fractionLeft: 1.4)
        XCTAssertEqual(headline?.id, "five-hour")
        XCTAssertEqual(headline?.fractionLeft, 1)
        XCTAssertEqual(headline?.subMeters, [])
        XCTAssertEqual(SectionHeadline(id: "weekly", windowLabel: "Weekly limit", fractionLeft: -2)?.fractionLeft, 0)
        for bad in [Double.nan, .infinity, -.infinity] {
            XCTAssertNil(SectionHeadline(id: "weekly", windowLabel: "Weekly limit", fractionLeft: bad))
        }
    }

    func testHeadlineCarriesSubMeters() throws {
        let fable = try XCTUnwrap(SectionMeter(id: "fable", label: "Fable", fraction: 0.25))
        let headline = try XCTUnwrap(SectionHeadline(id: "seven-day", windowLabel: "7-day limit",
                                                     fractionLeft: 0.6, subMeters: [fable]))
        XCTAssertEqual(headline.subMeters, [fable])
        XCTAssertNotEqual(headline, SectionHeadline(id: "seven-day", windowLabel: "7-day limit", fractionLeft: 0.6))
    }

    func testSectionKeepsHeadlinesInGivenOrder() throws {
        let first = try XCTUnwrap(SectionHeadline(id: "five-hour", windowLabel: "5-hour limit", fractionLeft: 0.5))
        let second = try XCTUnwrap(SectionHeadline(id: "seven-day", windowLabel: "7-day limit", fractionLeft: 0.2))
        XCTAssertEqual(ProviderSection(headlines: [first, second], lastUpdated: referenceDate).headlines,
                       [first, second])
        XCTAssertTrue(ProviderSection(lastUpdated: referenceDate).headlines.isEmpty)
    }

    func testCodexFiveHourToggleNeverChangesTheClaudeSection() throws {
        let five = try XCTUnwrap(SectionHeadline(id: "five-hour", windowLabel: "5-hour limit", fractionLeft: 0.5))
        let seven = try XCTUnwrap(SectionHeadline(id: "seven-day", windowLabel: "7-day limit", fractionLeft: 0.2))
        let section = ProviderSection(
            meters: [try XCTUnwrap(SectionMeter(id: "five-hour-limit", label: "5-hour limit", fraction: 0.5)),
                     try XCTUnwrap(SectionMeter(id: "seven-day-limit", label: "7-day limit", fraction: 0.8))],
            deadlines: [SectionDeadline(id: "five-hour-reset", label: "5-hour limit", date: referenceDate)],
            headlines: [five, seven], lastUpdated: referenceDate)

        XCTAssertEqual(SectionVisibility.headlines(section, providerID: "claude", showFiveHourLimit: false),
                       [five, seven])
        XCTAssertEqual(SectionVisibility.meters(section, providerID: "claude", showFiveHourLimit: false),
                       section.meters)
        XCTAssertEqual(SectionVisibility.deadlines(section, providerID: "claude", showFiveHourLimit: false),
                       section.deadlines)

        XCTAssertEqual(SectionVisibility.headlines(section, providerID: "codex", showFiveHourLimit: false),
                       [seven])
        XCTAssertEqual(SectionVisibility.meters(section, providerID: "codex", showFiveHourLimit: false).map(\.id),
                       ["seven-day-limit"])
        XCTAssertTrue(SectionVisibility.deadlines(section, providerID: "codex", showFiveHourLimit: false).isEmpty)
        XCTAssertEqual(SectionVisibility.headlines(section, providerID: "codex", showFiveHourLimit: true),
                       [five, seven])
    }

    func testSecondaryMetersExcludeThoseWithAHeadline() throws {
        let five = try XCTUnwrap(SectionHeadline(id: "five-hour", windowLabel: "5-hour limit", fractionLeft: 0.5))
        let extra = try XCTUnwrap(SectionMeter(id: "extra", label: "Extra", fraction: 0.1))
        let section = ProviderSection(
            meters: [try XCTUnwrap(SectionMeter(id: "five-hour-limit", label: "5-hour limit", fraction: 0.5)), extra],
            headlines: [five], lastUpdated: referenceDate)
        XCTAssertEqual(SectionVisibility.secondaryMeters(section, providerID: "claude",
                                                         showFiveHourLimit: true), [extra])
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

    // MARK: - Pace gauge: time left and countdown

    func testTimeFractionLeftIsRemainingOverWindowLength() {
        let resetsAt = referenceDate.addingTimeInterval(9_000)
        XCTAssertEqual(ResetWindow.timeFractionLeft(resetsAt: resetsAt, windowDuration: 18_000,
                                                    now: referenceDate), 0.5)
        // A reset further out than one window length clamps to a full window.
        XCTAssertEqual(ResetWindow.timeFractionLeft(resetsAt: referenceDate.addingTimeInterval(20_000),
                                                    windowDuration: 18_000, now: referenceDate), 1)
    }

    func testTimeFractionLeftIsUnknownWithoutLengthResetOrFutureReset() {
        let resetsAt = referenceDate.addingTimeInterval(60)
        XCTAssertNil(ResetWindow.timeFractionLeft(resetsAt: resetsAt, windowDuration: nil, now: referenceDate))
        XCTAssertNil(ResetWindow.timeFractionLeft(resetsAt: nil, windowDuration: 18_000, now: referenceDate))
        XCTAssertNil(ResetWindow.timeFractionLeft(resetsAt: referenceDate, windowDuration: 18_000,
                                                  now: referenceDate))
        XCTAssertNil(ResetWindow.timeFractionLeft(resetsAt: referenceDate.addingTimeInterval(-1),
                                                  windowDuration: 18_000, now: referenceDate))
        for bad in [0, -5, Double.nan, .infinity] {
            XCTAssertNil(ResetWindow.timeFractionLeft(resetsAt: resetsAt, windowDuration: bad, now: referenceDate))
        }
    }

    func testPaceComparesTheShownWholePercentages() {
        XCTAssertTrue(ResetWindow.isBehindPace(usageLeft: 0.35, timeLeft: 0.60))
        XCTAssertFalse(ResetWindow.isBehindPace(usageLeft: 0.68, timeLeft: 0.50))
        // 49.6% and 50.4% both read as 50%: on pace, so the colour matches the numbers.
        XCTAssertFalse(ResetWindow.isBehindPace(usageLeft: 0.496, timeLeft: 0.504))
    }

    func testCountdownAppendsTimeLeftOnlyWhenTheWindowLengthIsKnown() {
        let resetsAt = referenceDate.addingTimeInterval(302_400)  // 3d 12h 0m
        XCTAssertEqual(ResetWindow.countdownText(resetsAt, now: referenceDate),
                       "Resets in 3d 12h 0m")
        XCTAssertEqual(ResetWindow.countdownText(resetsAt, now: referenceDate, windowDuration: ResetWindow.sevenDays),
                       "Resets in 3d 12h 0m (50% time left)")
        XCTAssertEqual(ResetWindow.countdownText(referenceDate.addingTimeInterval(9_000), now: referenceDate,
                                                 windowDuration: ResetWindow.fiveHours),
                       "Resets in 2h 30m (50% time left)")
        XCTAssertEqual(ResetWindow.countdownText(referenceDate.addingTimeInterval(30), now: referenceDate,
                                                 windowDuration: ResetWindow.fiveHours),
                       "Resets in less than a minute (0% time left)")
        XCTAssertEqual(ResetWindow.countdownText(referenceDate, now: referenceDate,
                                                 windowDuration: ResetWindow.fiveHours),
                       "Reset time passed · awaiting updated usage")
    }

    func testHeadlineWindowDurationIsValidatedAndRoundTrips() throws {
        let headline = try XCTUnwrap(SectionHeadline(id: "seven-day", windowLabel: "7-day limit", fractionLeft: 0.68,
                                                     resetsAt: referenceDate, windowDuration: ResetWindow.sevenDays))
        XCTAssertEqual(headline.windowDuration, 604_800)
        XCTAssertEqual(headline.timeFractionLeft(now: referenceDate.addingTimeInterval(-302_400)), 0.5)
        XCTAssertNil(SectionHeadline(id: "x", windowLabel: "X", fractionLeft: 0.5, windowDuration: -1)?.windowDuration)

        let decoded = try JSONDecoder().decode(SectionHeadline.self, from: JSONEncoder().encode(headline))
        XCTAssertEqual(decoded, headline)
    }

    func testCachedHeadlineWithoutWindowDurationDecodesAsUnknown() throws {
        let legacy = Data(#"{"id":"weekly","windowLabel":"Weekly limit","fractionLeft":0.5}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(SectionHeadline.self, from: legacy).windowDuration)
        let invalid = Data(#"{"windowLabel":"Weekly limit","fractionLeft":0.5,"windowDuration":0}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(SectionHeadline.self, from: invalid).windowDuration)
    }

    func testDeadlineTakesWindowLengthFromTheSameLabelHeadline() throws {
        let weekly = try XCTUnwrap(SectionHeadline(id: "weekly", windowLabel: "Weekly limit", fractionLeft: 0.5,
                                                   windowDuration: ResetWindow.sevenDays))
        let section = ProviderSection(rows: [], deadlines: [], headlines: [weekly], lastUpdated: referenceDate)
        XCTAssertEqual(section.windowDuration(for: SectionDeadline(id: "weekly-reset", label: "Weekly limit",
                                                                   date: referenceDate)), 604_800)
        XCTAssertNil(section.windowDuration(for: SectionDeadline(id: "pass-expiry", label: "Next reset-pass expiry",
                                                                 date: referenceDate)))
    }
}
