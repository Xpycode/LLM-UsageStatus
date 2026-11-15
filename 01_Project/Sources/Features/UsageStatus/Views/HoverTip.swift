import AppKit
import SwiftUI

// A hover tip that works while the app is inactive.
//
// The HUD is a non-activating panel, so the app is almost never active while
// it is on screen, and AppKit tool tips (SwiftUI `.help`) only appear for the
// active app. This replacement tracks the pointer with an `.activeAlways`
// tracking area and shows its own non-activating, click-through tip panel.

extension View {
    /// Shows `text` near the pointer after a short hover, also while the app
    /// is inactive. Clicks pass through; VoiceOver reads the text as a hint.
    func hoverTip(_ text: String) -> some View {
        modifier(HoverTipModifier(text: text))
    }
}

extension EnvironmentValues {
    /// Off where no pointer exists, such as `ImageRenderer` fixture renders,
    /// which cannot draw the AppKit tracking view.
    @Entry var hoverTipsEnabled = true
}

private struct HoverTipModifier: ViewModifier {
    let text: String
    @Environment(\.hoverTipsEnabled) private var enabled

    func body(content: Content) -> some View {
        content
            .overlay {
                if enabled { HoverTipArea(text: text) }
            }
            .accessibilityHint(text)
    }
}

/// Which hovered tip to show when tip areas overlap: the innermost, i.e. the
/// smallest area under the pointer; on a tie, the most recently entered.
enum HoverTipSelection {
    static func winner<ID>(_ hovered: [(id: ID, area: CGFloat)]) -> ID? {
        var best: (id: ID, area: CGFloat)?
        for candidate in hovered {
            if let current = best, candidate.area > current.area { continue }
            best = candidate
        }
        return best?.id
    }
}

private struct HoverTipArea: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> HoverTipTrackingView {
        let view = HoverTipTrackingView()
        view.text = text
        return view
    }

    func updateNSView(_ view: HoverTipTrackingView, context: Context) {
        view.text = text
    }
}

final class HoverTipTrackingView: NSView {
    var text = "" {
        didSet {
            if text != oldValue { HoverTipController.shared.textChanged(self) }
        }
    }

    private var trackingArea: NSTrackingArea?

    /// Click-through: tap-to-expand, buttons and window dragging stay with
    /// the SwiftUI content underneath. Tracking areas do not depend on hit testing.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func isAccessibilityElement() -> Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        HoverTipController.shared.enter(self)
    }

    override func mouseExited(with event: NSEvent) {
        HoverTipController.shared.exit(self)
    }

    /// An area that appears or moves under a resting pointer (panel opening,
    /// a section expanding) gets no entered event; the next move corrects it.
    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) {
            HoverTipController.shared.enter(self)
        } else {
            HoverTipController.shared.exit(self)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { HoverTipController.shared.exit(self) }
    }
}

/// Owns the single tip panel and decides which hovered area it shows.
@MainActor final class HoverTipController {
    static let shared = HoverTipController()

    /// Close to the AppKit tool tip delay.
    static let delay: Duration = .milliseconds(600)

    /// Hovered areas in the order they were entered.
    private var hovered: [HoverTipTrackingView] = []
    /// Areas hovered when the user clicked; they stay quiet until the pointer leaves them.
    private var suppressed: [ObjectIdentifier] = []
    private weak var shown: HoverTipTrackingView?
    private var pending: Task<Void, Never>?
    private var panel: NSPanel?
    private var host: NSHostingView<HoverTipLabel>?
    private var clickMonitor: Any?

    private init() {}

    func enter(_ view: HoverTipTrackingView) {
        guard !hovered.contains(where: { $0 === view }) else { return }
        hovered.append(view)
        installClickMonitor()
        reconsider()
    }

    func exit(_ view: HoverTipTrackingView) {
        let id = ObjectIdentifier(view)
        suppressed.removeAll { $0 == id }
        guard hovered.contains(where: { $0 === view }) else { return }
        hovered.removeAll { $0 === view }
        reconsider()
    }

    func textChanged(_ view: HoverTipTrackingView) {
        if shown === view, !view.text.isEmpty {
            present(view)
        } else if shown === view || hovered.contains(where: { $0 === view }) {
            // Emptied text drops the tip; an area whose text was empty may now qualify.
            reconsider()
        }
    }

    /// Hides the tip and forgets every hovered area; the HUD calls this when it closes.
    func dismissAll() {
        hovered.removeAll()
        suppressed.removeAll()
        reconsider()
    }

    private var candidate: HoverTipTrackingView? {
        let eligible = hovered.filter { view in
            !view.text.isEmpty && view.window?.isVisible == true
                && !suppressed.contains(ObjectIdentifier(view))
        }
        let index = HoverTipSelection.winner(eligible.enumerated().map { offset, view in
            (id: offset, area: view.bounds.width * view.bounds.height)
        })
        return index.map { eligible[$0] }
    }

    private func reconsider() {
        let target = candidate
        pending?.cancel()
        pending = nil
        if let target, target === shown { return } // Already up.
        guard let target else {
            hide()
            return
        }
        if shown != nil {
            // Moving between tips, like AppKit: no second delay.
            present(target)
            return
        }
        pending = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.delay)
            } catch {
                return // Cancelled: the pointer moved on.
            }
            guard let self else { return }
            self.pending = nil
            if let target = self.candidate { self.present(target) }
        }
    }

    private func present(_ view: HoverTipTrackingView) {
        guard let anchorWindow = view.window else { return hide() }
        let panel = self.panel ?? makePanel()
        let label = HoverTipLabel(text: view.text)
        if let host {
            host.rootView = label
        } else {
            let host = NSHostingView(rootView: label)
            panel.contentView = host
            self.host = host
        }
        panel.appearance = anchorWindow.effectiveAppearance
        let size = host?.fittingSize ?? .zero
        guard size.width > 0, size.height > 0 else { return hide() }

        // Placement is fixed while one tip stays up; it moves only when a
        // different tip is shown, so live text updates do not jump around.
        let origin: NSPoint
        if shown === view, panel.isVisible {
            origin = NSPoint(x: panel.frame.minX, y: panel.frame.maxY - size.height)
        } else {
            origin = Self.origin(for: size, pointer: NSEvent.mouseLocation)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
        shown = view
    }

    /// Below and right of the pointer, kept on the pointer's screen; flips
    /// above the pointer when there is no room below.
    static func origin(for size: CGSize, pointer: NSPoint) -> NSPoint {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
        var x = pointer.x + 2
        var y = pointer.y - 22 - size.height
        if y < visible.minY { y = pointer.y + 8 }
        x = min(max(x, visible.minX), visible.maxX - size.width)
        y = min(max(y, visible.minY), visible.maxY - size.height)
        return NSPoint(x: x, y: y)
    }

    private func hide() {
        panel?.orderOut(nil)
        shown = nil
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        self.panel = panel
        return panel
    }

    /// A click or scroll hides the tip until the pointer leaves the clicked
    /// area, as AppKit tool tips do. Local monitors also see events sent to the
    /// non-activating HUD while the app is inactive.
    private func installClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        ) { event in
            MainActor.assumeIsolated {
                HoverTipController.shared.suppressHovered()
            }
            return event
        }
    }

    private func suppressHovered() {
        guard !hovered.isEmpty else { return }
        suppressed = hovered.map(ObjectIdentifier.init)
        reconsider()
    }
}

/// The tip's look: small text on the HUD's material, like a system tool tip.
struct HoverTipLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .multilineTextAlignment(.leading)
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.separator, lineWidth: 0.5))
            .padding(1)
    }
}
