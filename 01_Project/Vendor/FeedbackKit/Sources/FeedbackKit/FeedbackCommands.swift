import SwiftUI
import AppKit

/// Adds a "Send Feedback…" item to the Help menu that presents `FeedbackView`. Drop into an app's
/// `.commands { }` block, like `HelpMenuCommands`:
///
///     .commands {
///         FeedbackCommands(config: feedbackConfig)
///     }
///
/// Presentation is **imperative** (see `FeedbackPresenter`): SwiftUI presentation modifiers
/// (`.sheet`, `.popover`) silently no-op when attached to a view inside a `Commands` builder,
/// because menu items aren't part of any window's view hierarchy — there is no window for the
/// sheet to attach to. So the button action hosts `FeedbackView` in an AppKit window itself.
/// (Apps that prefer to own presentation can still present `FeedbackView` from any
/// `.sheet(isPresented:)` — it falls back to the SwiftUI `dismiss` when no `onClose` is injected.)
public struct FeedbackCommands: Commands {
    private let config: FeedbackConfig

    public init(config: FeedbackConfig) {
        self.config = config
    }

    public var body: some Commands {
        CommandGroup(after: .help) {
            Button("Send Feedback…") {
                FeedbackPresenter.shared.present(config: config)
            }
        }
    }
}

/// Presents `FeedbackView` in a self-managed AppKit window so it works when triggered from a menu
/// command. Shows as a document-modal sheet on the key window when there is one (the usual case for
/// a document/window app), otherwise as a standalone titled window — covering menu-bar/agent apps
/// (`LSUIElement`) that may have no key window. Re-invoking while open just brings it forward.
@MainActor
final class FeedbackPresenter: NSObject, NSWindowDelegate {
    static let shared = FeedbackPresenter()
    private var window: NSWindow?

    func present(config: FeedbackConfig) {
        // Already open → bring it forward instead of stacking a second copy.
        if let window {
            if window.sheetParent == nil { window.makeKeyAndOrderFront(nil) }
            return
        }

        let root = FeedbackView(config: config, onClose: { [weak self] in self?.close() })
        let win = NSWindow(contentViewController: NSHostingController(rootView: root))
        win.title = "Send Feedback"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.setContentSize(NSSize(width: 460, height: 540))
        window = win

        if let key = NSApp.keyWindow, key !== win {
            key.beginSheet(win) { [weak self] _ in
                MainActor.assumeIsolated { self?.window = nil }
            }
        } else {
            win.center()
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func close() {
        guard let win = window else { return }
        if let parent = win.sheetParent {
            parent.endSheet(win)        // completion handler clears `window`
        } else {
            win.close()                 // `windowWillClose(_:)` clears `window`
        }
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
