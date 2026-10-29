import XCTest
@testable import LLMUsageStatus

/// Preferences tests run on an injected, test-only defaults suite; the app's
/// real `.standard` domain is never touched.
@MainActor
final class UsagePreferencesTests: XCTestCase {
    private let suiteName = "LLMUsageStatusTests.UsagePreferences-\(UUID().uuidString)"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testFiveHourToggleDefaultsToOffForNewInstalls() {
        let preferences = UsagePreferences(defaults: defaults)
        XCTAssertFalse(preferences.showCodexFiveHourLimit)
    }

    func testTogglePersistsAcrossInstances() {
        let first = UsagePreferences(defaults: defaults)
        first.showCodexFiveHourLimit = true
        XCTAssertEqual(defaults.bool(forKey: "codex.showFiveHourLimit"), true)

        // A fresh instance reads the persisted value, as a restart would.
        let reloaded = UsagePreferences(defaults: defaults)
        XCTAssertTrue(reloaded.showCodexFiveHourLimit)
    }

    func testToggleBackPersistsOff() {
        let first = UsagePreferences(defaults: defaults)
        first.showCodexFiveHourLimit = true
        let reloaded = UsagePreferences(defaults: defaults)
        reloaded.showCodexFiveHourLimit = false

        XCTAssertFalse(UsagePreferences(defaults: defaults).showCodexFiveHourLimit)
        XCTAssertEqual(defaults.object(forKey: "codex.showFiveHourLimit") as? Bool, false)
    }

    func testLegacyNonBooleanValueIsIgnored() {
        defaults.set("not a boolean", forKey: "codex.showFiveHourLimit")
        XCTAssertFalse(UsagePreferences(defaults: defaults).showCodexFiveHourLimit)
    }
}
