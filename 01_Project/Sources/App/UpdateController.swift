import AppKit
import Sparkle

/// Owns the Sparkle updater for this dockless app and exposes the small surface the menus and
/// Settings need. Checks run on Sparkle's default interval (SUEnableAutomaticChecks in Info.plist);
/// updates install only after the user accepts the alert.
@MainActor final class UpdateController: NSObject {
    private var standardController: SPUStandardUpdaterController!
    private var canCheckObservation: NSKeyValueObservation?
    private(set) var canCheckForUpdates = false
    var canCheckForUpdatesChanged: ((Bool) -> Void)?

    /// `startingUpdater: false` builds the controller without scheduling or performing any check
    /// (app-hosted tests).
    init(startingUpdater: Bool) {
        super.init()
        let controller = SPUStandardUpdaterController(
            startingUpdater: startingUpdater, updaterDelegate: nil, userDriverDelegate: self)
        standardController = controller
        canCheckForUpdates = controller.updater.canCheckForUpdates
        // Sparkle flips this on the main thread, but the observer closure is nonisolated and
        // Sendable: it hops to the main actor and re-reads the current value from the updater
        // instead of trusting a captured change payload, so a late hop can never apply a stale value.
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) {
            [weak self] _, _ in
            Task { @MainActor [weak self] in self?.syncCanCheckForUpdates() }
        }
    }

    var automaticallyChecksForUpdates: Bool {
        get { standardController.updater.automaticallyChecksForUpdates }
        set { standardController.updater.automaticallyChecksForUpdates = newValue }
    }

    var lastUpdateCheckDate: Date? { standardController.updater.lastUpdateCheckDate }

    func checkForUpdates() {
        // An agent app is never frontmost; without this the alert can open behind other windows.
        NSApp.activate(ignoringOtherApps: true)
        standardController.checkForUpdates(nil)
    }

    private func syncCanCheckForUpdates() {
        let value = standardController.updater.canCheckForUpdates
        guard value != canCheckForUpdates else { return }
        canCheckForUpdates = value
        canCheckForUpdatesChanged?(value)
    }
}

// Sparkle calls these on the main thread; @preconcurrency turns that into a runtime check
// instead of a Swift 6 isolation error against its nonisolated protocol requirements.
extension UpdateController: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        // Since Sparkle 2.2.0 a scheduled alert for an LSUIElement app opens behind other apps.
        guard handleShowingUpdate else { return }
        NSApp.activate(ignoringOtherApps: true)
    }
}
