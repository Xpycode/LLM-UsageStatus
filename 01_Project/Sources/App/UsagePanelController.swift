import AppKit
import SwiftUI

private final class Host<V: View>: NSHostingView<V> {
    var menuProvider: (() -> NSMenu)?
    /// Runs after SwiftUI has laid out, inside the same AppKit layout pass and so
    /// before the frame is drawn.
    var didLayout: (() -> Void)?

    override func layout() {
        super.layout()
        didLayout?()
    }

    override func acceptsFirstMouse(for: NSEvent?) -> Bool { true }

    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menuProvider?() else { return super.rightMouseDown(with: event) }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

@MainActor private struct PanelContent<Content: View>: View {
    let content: Content

    var body: some View {
        content
            // The panel follows the content's ideal size, independently of its viewport.
            .fixedSize()
            // Pin to the top so any host/frame mismatch never centers the content.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@MainActor final class UsagePanelController {
    private var panel: NSPanel?
    private var scrollView: NSScrollView?
    private var presentationID: UUID?

    var isVisible: Bool { panel?.isVisible ?? false }
    var menuProvider: (() -> NSMenu)?

    func show<V: View>(@ViewBuilder _ view: () -> V) {
        hide()
        let cursor = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) })
            ?? NSScreen.main ?? NSScreen.screens.first else { return }

        let id = UUID()
        presentationID = id
        let host = Host(rootView: PanelContent(content: view()))
        host.menuProvider = menuProvider
        // The SwiftUI ideal size is read as the intrinsic size; the controller owns the
        // document's frame (no Auto Layout constraints position it).
        host.sizingOptions = [.intrinsicContentSize]
        let initialSize = validSize(host.intrinsicContentSize) ?? CGSize(width: 1, height: 1)
        host.autoresizingMask = []
        host.frame = NSRect(origin: .zero, size: initialSize)

        let viewport = NSScrollView(frame: .zero)
        viewport.drawsBackground = false
        viewport.borderType = .noBorder
        viewport.scrollerStyle = .overlay
        viewport.autohidesScrollers = true
        viewport.documentView = host

        let p = NSPanel(contentRect: .zero,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = viewport
        panel = p
        scrollView = viewport

        resize(to: initialSize, panel: p, screen: screen,
               preferredOrigin: NSPoint(x: cursor.x - initialSize.width / 2, y: cursor.y + 16))

        // Resize in the same layout pass that changed the content (for example a section
        // expanding), so the panel frame and its content reach the screen together.
        // A deferred resize showed one frame of new content in the old frame.
        host.didLayout = { [weak self, weak host] in
            guard let self, let host, self.presentationID == id,
                  let panel = self.panel, panel.isVisible,
                  let size = self.validSize(host.intrinsicContentSize),
                  let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
            self.resize(to: size, panel: panel, screen: screen, display: false)
        }
        p.orderFrontRegardless()
    }

    func hide() {
        // Invalidate before ordering out: a late layout pass may belong to this old host.
        presentationID = nil
        panel?.orderOut(nil)
        panel = nil
        scrollView = nil
    }

    private func validSize(_ size: CGSize) -> CGSize? {
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        // Round outward in points so fractional layout values cannot clip content or
        // repeatedly alternate the panel frame at subpoint precision.
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }

    private func resize(to naturalSize: CGSize, panel: NSPanel, screen: NSScreen,
                        preferredOrigin: NSPoint? = nil, display: Bool = true) {
        guard let viewport = scrollView, let document = viewport.documentView else { return }
        // AppKit screen coordinates: points, bottom-left origin; never Retina pixels.
        let visible = screen.visibleFrame
        guard visible.width > 0, visible.height > 0 else { return }
        let size = CGSize(width: min(naturalSize.width, visible.width),
                          height: min(naturalSize.height, visible.height))
        let origin = preferredOrigin ?? NSPoint(x: panel.frame.minX, y: panel.frame.maxY - size.height)
        let frame = NSRect(x: min(max(origin.x, visible.minX), visible.maxX - size.width),
                           y: min(max(origin.y, visible.minY), visible.maxY - size.height),
                           width: size.width, height: size.height)

        let wasVerticallyScrollable = viewport.hasVerticalScroller
        let scrollsVertically = naturalSize.height > size.height
        let scrollsHorizontally = naturalSize.width > size.width
        if viewport.hasVerticalScroller != scrollsVertically { viewport.hasVerticalScroller = scrollsVertically }
        if viewport.hasHorizontalScroller != scrollsHorizontally { viewport.hasHorizontalScroller = scrollsHorizontally }
        if document.frame.size != naturalSize { document.setFrameSize(naturalSize) }
        // Inside a layout pass, AppKit draws the new frame right after layout; never
        // force a display from there.
        if panel.frame != frame { panel.setFrame(frame, display: display) }

        // Oversized content remains reachable by scrolling instead of extending beyond
        // the visible screen. Start at its top when it first overflows vertically.
        if viewport.hasVerticalScroller && !wasVerticallyScrollable {
            let top = document.isFlipped ? 0 : max(0, naturalSize.height - size.height)
            document.scroll(NSPoint(x: 0, y: top))
        }
    }
}
