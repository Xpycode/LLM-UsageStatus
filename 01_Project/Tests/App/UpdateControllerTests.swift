import AppKit
import XCTest
@testable import LLMUsageStatus

@MainActor
final class UpdateControllerTests: XCTestCase {
    private let automaticChecksKey = "SUEnableAutomaticChecks"
    private var priorAutomaticChecks: Any?

    override func setUp() async throws {
        // Sparkle persists the toggle into the host app's real defaults domain.
        priorAutomaticChecks = UserDefaults.standard.object(forKey: automaticChecksKey)
    }

    override func tearDown() async throws {
        if let priorAutomaticChecks {
            UserDefaults.standard.set(priorAutomaticChecks, forKey: automaticChecksKey)
        } else {
            UserDefaults.standard.removeObject(forKey: automaticChecksKey)
        }
    }

    func testFeedURLMatchesRepositoryAppcast() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            "https://raw.githubusercontent.com/Xpycode/LLM-UsageStatus/main/appcast.xml")
    }

    func testPublicKeyIsA32ByteEdDSAKey() throws {
        let encoded = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)
        let data = try XCTUnwrap(Data(base64Encoded: encoded))
        XCTAssertEqual(data.count, 32)
    }

    func testAutomaticChecksEnabledInBundle() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "SUEnableAutomaticChecks") as? Bool, true)
    }

    func testAgentAppKeysSurvivePartialPlist() {
        XCTAssertNotNil(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName"))
        XCTAssertNotNil(Bundle.main.object(forInfoDictionaryKey: "LSUIElement"))
    }

    func testSparkleFrameworkIsEmbedded() {
        let framework = Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks/Sparkle.framework")
        XCTAssertTrue(FileManager.default.fileExists(atPath: framework.path))
    }

    func testNonStartingControllerTogglesAutomaticChecks() {
        let controller = UpdateController(startingUpdater: false)
        controller.automaticallyChecksForUpdates = false
        XCTAssertFalse(controller.automaticallyChecksForUpdates)
        controller.automaticallyChecksForUpdates = true
        XCTAssertTrue(controller.automaticallyChecksForUpdates)
    }
}
