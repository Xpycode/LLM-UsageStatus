import AppCitizenshipKit
import AppKit
import FeedbackKit
import OSLog
import SwiftUI

/// Window subclass for a dockless app that has no main-menu Close item: Escape and
/// Command-W close it.
private final class FeedbackWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        performClose(sender)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.type == .keyDown, modifiers == .command,
            event.charactersIgnoringModifiers?.lowercased() == "w"
        {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Feedback window and tip-page entry points. No logs, usage data or credentials are attached.
@MainActor
final class CitizenshipSupport: NSObject, NSWindowDelegate {
    static let shared = CitizenshipSupport()

    let config: CitizenshipConfig

    private let openURL: (URL) -> Bool
    private let presentAlert: (_ message: String, _ informativeText: String) -> Void
    private let logger = Logger(subsystem: "com.sim.LLM-UsageStatus", category: "Citizenship")
    private var feedbackWindow: NSWindow?

    init(
        config: CitizenshipConfig = CitizenshipConfig(
            appID: "llm-usagestatus", appName: "LLM Usage Status"),
        openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) },
        presentAlert: @escaping (_ message: String, _ informativeText: String) -> Void = {
            message, informativeText in
            let alert = NSAlert()
            alert.messageText = message
            alert.informativeText = informativeText
            alert.alertStyle = .warning
            alert.runModal()
        }
    ) {
        self.config = config
        self.openURL = openURL
        self.presentAlert = presentAlert
        super.init()
    }

    /// The reused feedback window, if currently open.
    var currentFeedbackWindow: NSWindow? { feedbackWindow }

    func showFeedback() {
        if let window = feedbackWindow {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }

        let view = FeedbackView(
            config: config.feedbackConfig,
            onClose: { [weak self] in self?.feedbackWindow?.performClose(nil) })
        let window = FeedbackWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 540),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)
        window.contentView = NSHostingView(rootView: view)
        window.setContentSize(NSSize(width: 460, height: 540))
        window.title = "Send Feedback"
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.delegate = self
        window.center()
        feedbackWindow = window

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func leaveTip() {
        let url = config.donateURL
        if openURL(url) { return }
        logger.error("Could not open tip page \(url.absoluteString, privacy: .public)")
        presentAlert("Couldn't open the tip page", url.absoluteString)
    }

    func windowWillClose(_ notification: Notification) {
        feedbackWindow = nil
    }
}
