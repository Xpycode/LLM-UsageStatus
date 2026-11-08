import XCTest
@testable import LLMUsageStatus

@MainActor
final class HelpSupportTests: XCTestCase {
    private let expectedIDs = [
        "getting-started", "reading-the-panel", "authoritative-vs-estimated",
        "codex", "claude-code", "mistral-vibe", "settings-and-shortcuts",
        "troubleshooting", "privacy-and-data",
    ]

    // Marker of the package's missing-markdown placeholder body.
    private let missingFileMarkers = ["could not be loaded", "is missing from the app bundle"]

    func testBundledContentLoadsAllTopics() {
        let content = HelpSupport.loadContent(bundle: .main)

        XCTAssertEqual(content.topics.map(\.id), expectedIDs)
        XCTAssertEqual(content.windowTitle, "LLM Usage Status Help")
        for topic in content.topics {
            XCTAssertNotEqual(topic.id, HelpSupport.fallbackTopicID)
            XCTAssertFalse(
                topic.markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "\(topic.id) is empty"
            )
            for marker in missingFileMarkers {
                XCTAssertFalse(topic.markdown.contains(marker), "\(topic.id) is a missing-file placeholder")
            }
        }
    }

    func testBundleWithoutManifestYieldsFallbackTopic() {
        let content = HelpSupport.loadContent(bundle: Bundle(for: HelpSupportTests.self))

        XCTAssertEqual(content.topics.map(\.id), [HelpSupport.fallbackTopicID])
        XCTAssertEqual(content.topics.first?.title, "Help Unavailable")
        XCTAssertEqual(content.windowTitle, "LLM Usage Status Help")
    }
}
