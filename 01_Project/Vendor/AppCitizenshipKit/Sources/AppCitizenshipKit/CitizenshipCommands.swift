import SwiftUI
import AppKit
import FeedbackKit

/// Drop the whole citizenship menu set in with one line:
///
/// ```swift
/// .commands {
///     CitizenshipCommands(
///         CitizenshipConfig(appID: "diskverdict", appName: "DiskVerdict", accent: .blue)
///     )
/// }
/// ```
///
/// Adds to the **Help** menu: "Send Feedback…" (FeedbackKit) and "Leave a Tip" (the optional
/// tip jar), and replaces the standard **About** item with one that opens a native About panel
/// carrying Website / Tip Jar / Privacy links.
///
/// "Leave a Tip" (not "Donate"/"Support") is deliberate: "Donate" reads as charity, and "Support"
/// collides with a help-desk meaning — the tip-jar framing says "optional, no pressure" and matches
/// the Ko-fi-style backend (cookbook #100). It carries **no ellipsis** (cookbook #104): an ellipsis
/// signals "needs further in-app input" (as "Send Feedback…" does), but this hands off to the
/// browser. It also emits a leading `Divider()` so it reads as its own section under Feedback.
public struct CitizenshipCommands: Commands {
    private let config: CitizenshipConfig
    private let includeDonate: Bool
    private let includeAbout: Bool

    /// - Parameters:
    ///   - includeDonate: add "Leave a Tip" to the Help menu (default `true`).
    ///   - includeAbout: replace the App-menu About item with the link-rich panel (default `true`).
    ///     Set `false` if the app already ships its own custom About.
    public init(_ config: CitizenshipConfig, includeDonate: Bool = true, includeAbout: Bool = true) {
        self.config = config
        self.includeDonate = includeDonate
        self.includeAbout = includeAbout
    }

    public var body: some Commands {
        // Help › Send Feedback…  (FeedbackKit installs into CommandGroup(after: .help))
        FeedbackCommands(config: config.feedbackConfig)

        if includeDonate {
            CommandGroup(after: .help) {
                // Leading divider separates the tip jar from the Feedback item above it (cookbook
                // #104); a divider between groups renders, only a true menu-edge divider collapses.
                Divider()
                // No ellipsis: hands off to the browser, not an in-app sheet (HIG / cookbook #104).
                Button("Leave a Tip") {
                    NSWorkspace.shared.open(config.donateURL)
                }
            }
        }

        if includeAbout {
            CommandGroup(replacing: .appInfo) {
                Button("About \(config.appName)") {
                    CitizenshipAbout.show(config)
                }
            }
        }
    }
}
