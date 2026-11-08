import Foundation
import HelpMenu
import os

@MainActor
enum HelpSupport {
    static let fallbackTopicID = "help-unavailable"

    private static let logger = Logger(subsystem: "com.sim.LLM-UsageStatus", category: "Help")
    private static var cachedContent: HelpContent?

    static func loadContent(bundle: Bundle = .main) -> HelpContent {
        do {
            let content = try HelpContent(manifest: "help-manifest", in: bundle)
            if content.topics.isEmpty {
                logger.error("Help manifest loaded but contains no topics")
                return fallbackContent()
            }
            return content
        } catch {
            logger.error("Help content failed to load: \(error.localizedDescription, privacy: .public)")
            return fallbackContent()
        }
    }

    /// Bundled help, loaded once and shared by the menus and `HelpMenuCommands`.
    static var content: HelpContent {
        if let cachedContent { return cachedContent }
        let loaded = loadContent()
        cachedContent = loaded
        return loaded
    }

    static func show() {
        HelpWindowController.showHelp(content: content)
    }

    private static func fallbackContent() -> HelpContent {
        let topic = HelpTopic(
            id: fallbackTopicID,
            title: "Help Unavailable",
            markdown: """
            # Help Unavailable

            The help content could not be loaded.

            Reinstalling LLM Usage Status should restore it.
            """
        )
        return HelpContent(topics: [topic], windowTitle: "LLM Usage Status Help")
    }
}
