import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private let stores: [UsageStore]
    private let panel = UsagePanelController(); private var clickAway: Any?
    private var shortcutFallback: NSStatusItem?

    override init() {
        // Composition root: services conforming to `Provider`, one store per section.
        let providers: [any Provider] = [
            CodexUsageService(),
        ]
        stores = providers.map { UsageStore(provider: $0) }
        super.init()
    }

    func applicationDidFinishLaunching(_: Notification) {
        registerHotKey()
        panel.menuProvider = { [weak self] in self?.makeMenu() ?? NSMenu() }
        clickAway = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in Task { @MainActor in self?.panel.hide() } }
        // A Dockless agent otherwise offers no confirmation that it launched.
        // A failed hotkey registration also exposes a menu-bar fallback.
        toggle()
    }
    func applicationWillTerminate(_: Notification) { GlobalHotKey.shared.unregister(); if let clickAway { NSEvent.removeMonitor(clickAway) } }
    private func toggle() { if panel.isVisible { panel.hide() } else { showHUD() } }

    @objc private func showHUD() {
        panel.show { [stores] in UsageStatusView(stores: stores) }
        // Refresh on open: every provider fetches current values independently.
        stores.forEach { $0.refresh() }
    }

    @objc private func registerHotKey() {
        switch GlobalHotKey.shared.register({ [weak self] in self?.toggle() }) {
        case .success:
            if let shortcutFallback { NSStatusBar.system.removeStatusItem(shortcutFallback) }
            shortcutFallback = nil
        case .failure(let failure):
            showShortcutFallback(for: failure)
        }
    }

    private func showShortcutFallback(for failure: GlobalHotKey.RegistrationFailure) {
        let item = shortcutFallback ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        shortcutFallback = item
        let image = NSImage(systemSymbolName: "exclamationmark.triangle",
                            accessibilityDescription: "LLM Usage Status: shortcut unavailable")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.title = image == nil ? "!" : ""
        item.button?.toolTip = "LLM Usage Status: shortcut unavailable. Click for Show HUD and Retry Shortcut."

        let menu = NSMenu()
        menu.autoenablesItems = false
        let messages: [String]
        switch failure {
        case .shortcut(let status) where status == eventHotKeyExistsErr:
            messages = ["Control–Option–Command–L is already in use.",
                        "Free this shortcut in the other app, then retry."]
        default:
            messages = ["macOS could not enable Control–Option–Command–L.",
                        "Use Show HUD below, or try Retry Shortcut."]
        }
        for message in messages {
            let explanation = menu.addItem(withTitle: message, action: nil, keyEquivalent: "")
            explanation.isEnabled = false
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Show HUD", action: #selector(showHUD), keyEquivalent: "")
        menu.addItem(withTitle: "Retry Shortcut", action: #selector(registerHotKey), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit LLM Usage Status", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show HUD", action: #selector(showHUD), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit LLM Usage Status", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        return menu
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
