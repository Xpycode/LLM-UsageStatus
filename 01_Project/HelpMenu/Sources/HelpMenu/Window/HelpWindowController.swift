import AppKit
import SwiftUI

/// Window subclass for dockless hosts that have no main-menu Close item: Escape and
/// Command-W close it. While the search field is focused, its field editor consumes
/// Escape first (clearing the query), so Escape reaches the window only when the
/// field has nothing left to cancel.
private final class HelpWindow: NSWindow {
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

/// Owns the single, reusable help `NSWindow`.
///
/// `showHelp(content:)` creates the window on first call and brings the
/// existing one to front on subsequent calls — clicks never spawn duplicates.
/// Works from both SwiftUI and AppKit hosts, including menu-bar apps with no
/// other windows.
@MainActor
public final class HelpWindowController: NSObject, NSWindowDelegate {
    public static let shared = HelpWindowController()

    private var window: NSWindow?

    /// The live view model; retained here so callers can seed `selection` on
    /// both first-open and re-open of an already-built window.
    private var viewModel: HelpViewModel?

    private override init() { super.init() }

    /// Show the help window, creating it or focusing the existing instance.
    public static func showHelp(content: HelpContent) {
        shared.present(content: content, topicID: nil)
    }

    /// Show the help window and navigate directly to the topic with the given
    /// id. If `id` is `nil` or does not match any topic in `content`, the
    /// window opens on the first topic (the default behaviour).
    public static func showHelp(content: HelpContent, selectingTopic id: String?) {
        shared.present(content: content, topicID: id)
    }

    private func present(content: HelpContent, topicID: String?) {
        NSApp.activate()

        if let window {
            // Window already exists — just bring it forward and update selection.
            window.makeKeyAndOrderFront(nil)
            applyTopicSelection(topicID, in: content)
            return
        }

        let model = HelpViewModel(content: content)
        self.viewModel = model

        let hosting = NSHostingController(rootView: HelpWindowView(model: model))
        let window = HelpWindow(contentViewController: hosting)
        window.title = content.windowTitle
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 820, height: 560))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.identifier = NSUserInterfaceItemIdentifier("HelpMenu.HelpWindow")
        window.appearance = NSAppearance(named: .darkAqua)
        window.setFrameAutosaveName("LLMUsageStatusHelpWindow")

        self.window = window
        window.makeKeyAndOrderFront(nil)

        // Seed selection after the window is built (view model already has its
        // default first-topic selection from init; override only when requested).
        applyTopicSelection(topicID, in: content)
    }

    /// Set `viewModel.selection` to `topicID` when it matches a known topic,
    /// otherwise leave the existing selection unchanged (defaults to first topic).
    private func applyTopicSelection(_ topicID: String?, in content: HelpContent) {
        guard let id = topicID,
              content.topics.contains(where: { $0.id == id }) else { return }
        viewModel?.selection = id
    }

    // MARK: NSWindowDelegate

    public func windowWillClose(_ notification: Notification) {
        // Drop both references so the next showHelp rebuilds with fresh content.
        if (notification.object as? NSWindow) === window {
            window = nil
            viewModel = nil
        }
    }
}
