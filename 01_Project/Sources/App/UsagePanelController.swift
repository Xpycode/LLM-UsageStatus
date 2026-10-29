import AppKit
import SwiftUI

private final class Host<V: View>: NSHostingView<V> {
    var menuProvider: (() -> NSMenu)?

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

@MainActor private struct MeasuredPanelContent<Content: View>: View {
    let content: Content
    let sizeChanged: @MainActor (CGSize) -> Void

    var body: some View {
        content
            // Measure the content's ideal size, independently of the panel's viewport.
            .fixedSize()
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { sizeChanged(geometry.size) }
                        .onChange(of: geometry.size) { _, size in sizeChanged(size) }
                }
            }
    }
}

@MainActor final class UsagePanelController {
    private var panel: NSPanel?
    private var scrollView: NSScrollView?
    private var presentationID: UUID?
    private var pendingSize: CGSize?
    private var sizeUpdateScheduled = false

    var isVisible: Bool { panel?.isVisible ?? false }
    var menuProvider: (() -> NSMenu)?

    func show<V: View>(@ViewBuilder _ view: () -> V) {
        hide()
        let cursor = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) })
            ?? NSScreen.main ?? NSScreen.screens.first else { return }

        let id = UUID()
        presentationID = id
        let host = Host(rootView: MeasuredPanelContent(content: view()) { [weak self] size in
            self?.scheduleResize(to: size, presentation: id)
        })
        host.menuProvider = menuProvider
        let initialSize = validSize(host.fittingSize) ?? CGSize(width: 1, height: 1)
        // The document keeps its natural size; the controller owns its frame.
        host.sizingOptions = []
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
        p.orderFrontRegardless()
    }

    func hide() {
        // Invalidate before ordering out: queued callbacks may belong to this old host.
        presentationID = nil
        pendingSize = nil
        sizeUpdateScheduled = false
        panel?.orderOut(nil)
        panel = nil
        scrollView = nil
    }

    private func scheduleResize(to size: CGSize, presentation id: UUID) {
        guard presentationID == id, let size = validSize(size) else { return }
        pendingSize = size
        guard !sizeUpdateScheduled else { return }
        sizeUpdateScheduled = true

        // Do not change AppKit frames inside SwiftUI's layout callback. Coalesce changes
        // and recheck identity after the hop, including hide -> show replacements.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.presentationID == id else { return }
            self.sizeUpdateScheduled = false
            guard let panel = self.panel, panel.isVisible,
                  let size = self.pendingSize,
                  let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
            self.pendingSize = nil
            self.resize(to: size, panel: panel, screen: screen)
        }
    }

    private func validSize(_ size: CGSize) -> CGSize? {
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        // Round outward in points so fractional layout values cannot clip content or
        // repeatedly alternate the panel frame at subpoint precision.
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }

    private func resize(to naturalSize: CGSize, panel: NSPanel, screen: NSScreen,
                        preferredOrigin: NSPoint? = nil) {
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
        if panel.frame != frame { panel.setFrame(frame, display: true) }

        // Oversized content remains reachable by scrolling instead of extending beyond
        // the visible screen. Start at its top when it first overflows vertically.
        if viewport.hasVerticalScroller && !wasVerticallyScrollable {
            let top = document.isFlipped ? 0 : max(0, naturalSize.height - size.height)
            document.scroll(NSPoint(x: 0, y: top))
        }
    }
}
