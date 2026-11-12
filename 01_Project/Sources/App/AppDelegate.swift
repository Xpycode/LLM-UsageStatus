import AppKit
import Combine
import Carbon.HIToolbox
import SwiftUI
import os

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, NSMenuDelegate {
    private static let logger = Logger(subsystem: "com.sim.LLM-UsageStatus", category: "App")
    private let stores: [UsageStore]
    private let preferences = UsagePreferences()
    private let panel = UsagePanelController(); private var clickAway: Any?
    private var shortcutFallback: NSStatusItem?
    private let shortcutStore = HotKeyShortcutStore()
    private let launchAtLogin = LaunchAtLogin()
    private var enabledObservation: AnyCancellable?
    private var knownEnabled: Set<String> = []
    private var layoutObserver: NSObjectProtocol?
    // No updater inside the app-hosted test process: tests must not touch the network.
    private let updates = UpdateController(
        startingUpdater: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil)
    private var fallbackUpdateItem: NSMenuItem?
    private lazy var settings = SettingsWindowController(
        preferences: preferences, shortcuts: shortcutStore, launchAtLogin: launchAtLogin, version: .current,
        updates: updates,
        commitShortcut: { [unowned self] in self.commitShortcut($0) },
        recordingChanged: { [unowned self] in self.shortcutRecordingChanged($0) })

    override init() {
        // Composition root: services conforming to `Provider`, one store per section.
        let providers: [any Provider] = [
            CodexUsageService(),
            ClaudeUsageProvider(),
            VibeUsageProvider(),
        ]
        let sectionCache = SectionStateCache()
        stores = providers.map { UsageStore(provider: $0, cache: sectionCache) }
        super.init()
    }

    func applicationDidFinishLaunching(_: Notification) {
        registerHotKey()
        knownEnabled = preferences.enabledProviderIDs
        // The sink receives the new value (willSet timing), so it diffs against `knownEnabled`
        // rather than reading the property back.
        enabledObservation = preferences.$enabledProviderIDs.sink { [weak self] enabled in
            self?.enabledProvidersChanged(enabled)
        }
        // After an app update the login item can point at the old copy; re-registering fixes it.
        Task { [launchAtLogin] in await launchAtLogin.refreshRegistrationIfEnabled() }
        panel.menuProvider = { [weak self] in self?.makeMenu() ?? NSMenu() }
        clickAway = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in Task { @MainActor in self?.hidePanel() } }
        // A Dockless agent otherwise offers no confirmation that it launched.
        // A failed hotkey registration also exposes a menu-bar fallback.
        toggle()
    }
    func applicationWillTerminate(_: Notification) {
        GlobalHotKey.shared.unregisterAll()
        stopObservingLayout()
        if let clickAway { NSEvent.removeMonitor(clickAway) }
    }
    private func toggle() { if panel.isVisible { hidePanel() } else { showHUD() } }

    /// A provider turned on while the panel is open shows its cached section at once and refreshes.
    private func enabledProvidersChanged(_ enabled: Set<String>) {
        let added = enabled.subtracting(knownEnabled)
        knownEnabled = enabled
        guard panel.isVisible, !added.isEmpty else { return }
        enabledStores(in: added).forEach { $0.refresh() }
    }

    private func enabledStores(in enabled: Set<String>) -> [UsageStore] {
        UsagePreferences.enabledStores(stores, enabled: enabled)
    }

    @objc private func showHUD() {
        let shortcutName = shortcutStore.current.displayName
        panel.show { [stores, preferences] in
            UsageStatusView(stores: stores, preferences: preferences, shortcutName: shortcutName)
        }
        // Refresh on open: every enabled provider fetches current values independently;
        // a disabled provider is never read or fetched.
        enabledStores(in: preferences.enabledProviderIDs).forEach { $0.refresh() }
        registerSettingsShortcut()
    }

    /// The panel never becomes key, so Command-Comma is a Carbon hotkey that exists only
    /// while the panel is showing; other apps keep their own Command-Comma otherwise.
    /// It binds the key that types "," on the current layout (on AZERTY that is the M position)
    /// and moves with the layout while the panel shows.
    private func registerSettingsShortcut() {
        startObservingLayout()
        let chord = HotKeyShortcut.settings(using: .current)
        let result = GlobalHotKey.shared.register(id: .settings, keyCode: chord.keyCode,
                                                  modifiers: chord.carbonModifiers) { [weak self] in
            self?.openSettings()
        }
        if case .failure(let failure) = result {
            // Not fatal: Settings… stays reachable from the right-click menu.
            Self.logger.notice("Settings shortcut unavailable: \(String(describing: failure), privacy: .public)")
        }
    }

    private func hidePanel() {
        panel.hide()
        GlobalHotKey.shared.unregister(id: .settings)
        stopObservingLayout()
    }

    /// Same notification the shortcut recorder follows; posted on the distributed center.
    private func startObservingLayout() {
        guard layoutObserver == nil else { return }
        layoutObserver = DistributedNotificationCenter.default().addObserver(
            forName: KeyboardLayoutNames.changedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.panel.isVisible else { return }
                self.registerSettingsShortcut()
            }
        }
    }

    private func stopObservingLayout() {
        guard let layoutObserver else { return }
        DistributedNotificationCenter.default().removeObserver(layoutObserver)
        self.layoutObserver = nil
    }

    @objc private func openSettings() {
        hidePanel()
        settings.show()
    }

    // Like Settings…, these windows come to the front, so the HUD gets out of the way first.
    @objc private func checkForUpdates() {
        hidePanel()
        updates.checkForUpdates()
    }

    // The right-click menu auto-enables items, so Check for Updates… follows Sparkle here.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(checkForUpdates) { return updates.canCheckForUpdates }
        return true
    }

    // The fallback menu opts out of auto-enabling, so refresh its update item as it opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        fallbackUpdateItem?.isEnabled = updates.canCheckForUpdates
    }

    @objc private func openHelp() {
        hidePanel()
        HelpSupport.show()
    }

    @objc private func sendFeedback() {
        hidePanel()
        CitizenshipSupport.shared.showFeedback()
    }

    @objc private func leaveTip() {
        hidePanel()
        CitizenshipSupport.shared.leaveTip()
    }

    @objc private func registerHotKey() {
        let chord = shortcutStore.current
        let result = GlobalHotKey.shared.register(id: .toggle, keyCode: chord.keyCode,
                                                  modifiers: chord.carbonModifiers) { [weak self] in
            self?.toggle()
        }
        applyToggleRegistration(result)
    }

    private func applyToggleRegistration(_ result: Result<Void, GlobalHotKey.RegistrationFailure>) {
        switch result {
        case .success:
            if let shortcutFallback { NSStatusBar.system.removeStatusItem(shortcutFallback) }
            shortcutFallback = nil
        case .failure(let failure):
            showShortcutFallback(for: failure)
        }
    }

    /// Registers `chord` as the toggle; only a successful registration is persisted.
    /// On failure the stored chord is registered again so the previous shortcut keeps working.
    private func commitShortcut(_ chord: HotKeyShortcut) -> ShortcutCommitResult {
        let result = GlobalHotKey.shared.register(id: .toggle, keyCode: chord.keyCode,
                                                  modifiers: chord.carbonModifiers) { [weak self] in
            self?.toggle()
        }
        switch result {
        case .success:
            shortcutStore.save(chord)
            applyToggleRegistration(result)
            return .accepted
        case .failure(let failure):
            registerHotKey()
            switch failure {
            case .shortcut(let status) where status == eventHotKeyExistsErr: return .inUse
            case .shortcut(let status), .eventHandler(let status): return .failed(status)
            }
        }
    }

    /// The live toggle is suspended while the recorder listens, so pressing the current
    /// chord records it instead of hiding/showing the panel.
    private func shortcutRecordingChanged(_ recording: Bool) {
        if recording { GlobalHotKey.shared.unregister(id: .toggle) } else { registerHotKey() }
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
        let chordName = shortcutStore.current.displayName
        switch failure {
        case .shortcut(let status) where status == eventHotKeyExistsErr:
            messages = ["\(chordName) is already in use.",
                        "Free this shortcut in the other app, or choose another in Settings."]
        default:
            messages = ["macOS could not enable \(chordName).",
                        "Use Show HUD below, or try Retry Shortcut."]
        }
        for message in messages {
            let explanation = menu.addItem(withTitle: message, action: nil, keyEquivalent: "")
            explanation.isEnabled = false
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Show HUD", action: #selector(showHUD), keyEquivalent: "")
        menu.addItem(withTitle: "Retry Shortcut", action: #selector(registerHotKey), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        let updateItem = menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.isEnabled = updates.canCheckForUpdates
        fallbackUpdateItem = updateItem
        menu.delegate = self
        menu.addItem(withTitle: "LLM Usage Status Help", action: #selector(openHelp), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit LLM Usage Status", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        // Rebuilt on every right-click (menuProvider), so provider toggles apply immediately.
        var providerItems = 0
        if preferences.isEnabled("codex") {
            let displayOption = menu.addItem(withTitle: "Show 5-hour limit", action: #selector(toggleCodexFiveHourLimit), keyEquivalent: "")
            displayOption.state = preferences.showCodexFiveHourLimit ? .on : .off
            providerItems += 1
        }
        if preferences.isEnabled("vibe") {
            menu.addItem(withTitle: "Set Vibe Monthly Budget…", action: #selector(editVibeBudget), keyEquivalent: "")
            providerItems += 1
        }
        if providerItems > 0 { menu.addItem(.separator()) }
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        menu.addItem(withTitle: "LLM Usage Status Help", action: #selector(openHelp), keyEquivalent: "")
        menu.addItem(withTitle: "Restart LLM Usage Status", action: #selector(restart), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Send Feedback…", action: #selector(sendFeedback), keyEquivalent: "")
        menu.addItem(withTitle: "Leave a Tip", action: #selector(leaveTip), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit LLM Usage Status", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        return menu
    }

    @objc private func toggleCodexFiveHourLimit(_ sender: NSMenuItem) {
        preferences.showCodexFiveHourLimit.toggle()
        sender.state = preferences.showCodexFiveHourLimit ? .on : .off
    }

    @objc private func editVibeBudget() {
        VibeBudgetEditor.shared.present(
            amount: preferences.vibeMonthlyBudgetUSD,
            resetDay: preferences.vibeBudgetResetDay
        ) { [weak self] amount, resetDay in
            guard let self else { return }
            self.preferences.vibeMonthlyBudgetUSD = amount
            self.preferences.vibeBudgetResetDay = resetDay
            // The open panel picks the new headline up through the stores.
            self.enabledStores(in: self.preferences.enabledProviderIDs).forEach { $0.refresh() }
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func restart() {
        let configuration = NSWorkspace.OpenConfiguration()
        // Reusing this process would make Restart merely quit. Release the hotkey
        // before the replacement starts so its registration cannot collide.
        configuration.createsNewApplicationInstance = true
        GlobalHotKey.shared.unregisterAll()
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] _, error in
            Task { @MainActor in
                if error != nil {
                    // unregisterAll() also dropped Command-Comma; restore it while the panel shows.
                    self?.registerHotKey()
                    if self?.panel.isVisible == true { self?.registerSettingsShortcut() }
                    return
                }
                NSApp.terminate(nil)
            }
        }
    }
}
