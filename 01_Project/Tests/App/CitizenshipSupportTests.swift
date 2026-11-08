import XCTest

@testable import LLMUsageStatus

@MainActor
final class CitizenshipSupportTests: XCTestCase {
    func testConfigValues() {
        let support = CitizenshipSupport.shared
        XCTAssertTrue(support.config.donateURL.absoluteString.contains("app=llm-usagestatus"))
        XCTAssertEqual(support.config.feedbackConfig.appID, "llm-usagestatus")
        XCTAssertEqual(support.config.appName, "LLM Usage Status")
    }

    func testLeaveTipAlertsWhenOpenFails() {
        var opened: [URL] = []
        var alerts: [(String, String)] = []
        let support = CitizenshipSupport(
            openURL: { opened.append($0); return false },
            presentAlert: { alerts.append(($0, $1)) })
        support.leaveTip()
        XCTAssertEqual(opened, [support.config.donateURL])
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts.first?.0, "Couldn't open the tip page")
        XCTAssertEqual(alerts.first?.1, support.config.donateURL.absoluteString)
    }

    func testLeaveTipNoAlertWhenOpenSucceeds() {
        var alertCount = 0
        let support = CitizenshipSupport(
            openURL: { _ in true },
            presentAlert: { _, _ in alertCount += 1 })
        support.leaveTip()
        XCTAssertEqual(alertCount, 0)
    }

    func testShowFeedbackReusesWindow() {
        let support = CitizenshipSupport(openURL: { _ in true }, presentAlert: { _, _ in })
        support.showFeedback()
        let first = support.currentFeedbackWindow
        XCTAssertNotNil(first)
        support.showFeedback()
        XCTAssertTrue(support.currentFeedbackWindow === first)
        first?.close()
        XCTAssertNil(support.currentFeedbackWindow)
    }
}
