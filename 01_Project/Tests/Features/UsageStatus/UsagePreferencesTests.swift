import XCTest
@testable import LLMUsageStatus

/// Preferences tests run on an injected, test-only defaults suite; the app's
/// real `.standard` domain is never touched.
@MainActor
final class UsagePreferencesTests: XCTestCase {
    private let suiteName = "LLMUsageStatusTests.UsagePreferences-\(UUID().uuidString)"
    private var defaults: UserDefaults!

    // Async overrides keep main-actor isolation on every toolchain; the
    // synchronous XCTestCase overrides are nonisolated on older SDKs.
    override func setUp() async throws {
        // XCTestCase's async setUp/tearDown are empty; calling super from a
        // @MainActor override is a sending error on the Swift 6.1 toolchain.
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
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

    // MARK: - Vibe monthly budget

    func testBudgetDefaultsToNoneAndDayOne() {
        let preferences = UsagePreferences(defaults: defaults)
        XCTAssertNil(preferences.vibeMonthlyBudgetUSD)
        XCTAssertEqual(preferences.vibeBudgetResetDay, 1)
    }

    func testBudgetPersistsAcrossInstancesAndRemoval() {
        let first = UsagePreferences(defaults: defaults)
        first.vibeMonthlyBudgetUSD = 300
        first.vibeBudgetResetDay = 15
        XCTAssertEqual(defaults.object(forKey: UsagePreferenceKeys.vibeMonthlyBudgetUSD) as? Double, 300)
        XCTAssertEqual(defaults.object(forKey: UsagePreferenceKeys.vibeBudgetResetDay) as? Int, 15)

        // A fresh instance reads the persisted value, as a restart would.
        let reloaded = UsagePreferences(defaults: defaults)
        XCTAssertEqual(reloaded.vibeMonthlyBudgetUSD, 300)
        XCTAssertEqual(reloaded.vibeBudgetResetDay, 15)

        reloaded.vibeMonthlyBudgetUSD = nil
        XCTAssertNil(defaults.object(forKey: UsagePreferenceKeys.vibeMonthlyBudgetUSD))
        XCTAssertNil(UsagePreferences(defaults: defaults).vibeMonthlyBudgetUSD)
    }

    func testBudgetResetDayClampsToOneThroughThirtyOne() {
        let preferences = UsagePreferences(defaults: defaults)
        preferences.vibeBudgetResetDay = 45
        XCTAssertEqual(preferences.vibeBudgetResetDay, 31)
        XCTAssertEqual(defaults.object(forKey: UsagePreferenceKeys.vibeBudgetResetDay) as? Int, 31)
        preferences.vibeBudgetResetDay = 0
        XCTAssertEqual(preferences.vibeBudgetResetDay, 1)
    }

    func testNonPositiveBudgetIsNotPersisted() {
        let preferences = UsagePreferences(defaults: defaults)
        preferences.vibeMonthlyBudgetUSD = -10
        XCTAssertNil(defaults.object(forKey: UsagePreferenceKeys.vibeMonthlyBudgetUSD))
    }
}
