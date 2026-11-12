import AppKit

enum ShortcutCommitResult: Equatable {
    case accepted
    case inUse
    case failed(OSStatus)
}

/// Window subclass for a dockless app that has no main-menu Close item: Escape and
/// Command-W close it. (Escape during recording never gets here; the recorder's local
/// monitor consumes it first.)
private final class SettingsWindow: NSWindow {
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

/// Self-managed settings window (Providers, Startup, Shortcut, Updates, About) built from AppKit controls.
///
/// Shortcut contract: the window never saves to `HotKeyShortcutStore`. Recording a chord and
/// "Reset to Default" both go through `commitShortcut`; the caller registers the hotkey and
/// persists it. The display changes only when the closure returns `.accepted`, and Reset then
/// re-reads the chord from the store.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    let window: NSWindow

    private let preferences: UsagePreferences
    private let shortcuts: HotKeyShortcutStore
    private let launchAtLogin: LaunchAtLogin
    private let commitShortcut: (HotKeyShortcut) -> ShortcutCommitResult
    private let recordingChanged: (Bool) -> Void
    private let updates: UpdateController

    private let updatesCheckbox = NSButton(checkboxWithTitle: "Check for updates automatically", target: nil, action: nil)
    private let updatesButton = NSButton(title: "Check for Updates\u{2026}", target: nil, action: nil)
    private let updatesCaption = SettingsWindowController.wrappingLabel("")

    private let recorder: ShortcutRecorderField
    private let shortcutMessage = SettingsWindowController.wrappingLabel("")
    private let launchCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let launchStatus = SettingsWindowController.wrappingLabel("Checking\u{2026}")
    private let loginItemsButton = NSButton(title: "Open Login Items\u{2026}", target: nil, action: nil)

    private var hasBeenPlaced = false
    private var loginState: LaunchAtLoginState?
    private var isReadingLogin = false
    private var isChangingLogin = false
    // Bumped by every toggle so an in-flight status read started earlier is dropped.
    private var loginGeneration = 0

    private static let contentWidth: CGFloat = 380

    init(
        preferences: UsagePreferences,
        shortcuts: HotKeyShortcutStore,
        launchAtLogin: LaunchAtLogin,
        version: AppVersion,
        updates: UpdateController,
        commitShortcut: @escaping (HotKeyShortcut) -> ShortcutCommitResult,
        recordingChanged: @escaping (Bool) -> Void
    ) {
        self.preferences = preferences
        self.shortcuts = shortcuts
        self.launchAtLogin = launchAtLogin
        self.commitShortcut = commitShortcut
        self.recordingChanged = recordingChanged
        self.updates = updates
        self.recorder = ShortcutRecorderField(
            shortcut: shortcuts.current, commit: commitShortcut, recordingChanged: recordingChanged)
        self.window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable], backing: .buffered, defer: true)
        super.init()

        window.title = "LLM Usage Status Settings"
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.delegate = self

        launchCheckbox.target = self
        launchCheckbox.action = #selector(toggleLaunchAtLogin)
        loginItemsButton.target = self
        loginItemsButton.action = #selector(openLoginItems)
        loginItemsButton.isHidden = true
        launchCheckbox.isEnabled = false
        updatesCheckbox.target = self
        updatesCheckbox.action = #selector(toggleAutomaticUpdates)
        updatesButton.target = self
        updatesButton.action = #selector(checkForUpdates)
        // canCheckForUpdates flips back when a check ends, so the "Last checked" caption follows too.
        updates.canCheckForUpdatesChanged = { [weak self] _ in self?.refreshUpdates() }
        refreshUpdates()
        recorder.onMessageChange = { [weak self] text in self?.shortcutMessage.stringValue = text }

        buildContent(version: version)
    }

    func show() {
        if !hasBeenPlaced {
            window.center()
            hasBeenPlaced = true
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: Layout

    private func buildContent(version: AppVersion) {
        let resetButton = NSButton(title: "Reset to Default", target: self, action: #selector(resetShortcut))
        let shortcutTitle = NSTextField(labelWithString: "Show or hide the panel")
        let shortcutRow = NSStackView(views: [recorder, resetButton])
        shortcutRow.orientation = .horizontal
        shortcutRow.spacing = 8
        shortcutRow.alignment = .centerY
        shortcutMessage.textColor = .systemOrange

        let name = NSTextField(labelWithString: "LLM Usage Status")
        name.font = .boldSystemFont(ofSize: 13)
        let description = Self.wrappingLabel("Usage at a glance for Codex, Claude Code and Mistral Vibe.")
        let versionLabel = NSTextField(labelWithString: version.displayString)
        let copyright = NSTextField(labelWithString: version.copyright)
        copyright.textColor = .secondaryLabelColor

        let providerRows: [NSView] = [
            ("codex", "Codex"), ("claude", "Claude Code"), ("vibe", "Mistral Vibe"),
        ].map { id, title in
            let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(toggleProvider))
            checkbox.identifier = NSUserInterfaceItemIdentifier(id)
            checkbox.state = preferences.isEnabled(id) ? .on : .off
            return checkbox
        }

        let sections: [NSView] = [
            section("Providers", providerRows),
            section("Startup", [launchCheckbox, launchStatus, loginItemsButton]),
            section("Shortcut", [shortcutTitle, shortcutRow, shortcutMessage]),
            section("Updates", [updatesCheckbox, updatesButton, updatesCaption]),
            section("About", [name, description, versionLabel, copyright]),
        ]
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        for (index, view) in sections.enumerated() {
            if index > 0 {
                let separator = NSBox()
                separator.boxType = .separator
                stack.addArrangedSubview(separator)
                separator.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true
            }
            stack.addArrangedSubview(view)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalToConstant: Self.contentWidth),
        ])
        window.contentView = container
        container.layoutSubtreeIfNeeded()
        window.setContentSize(container.fittingSize)
    }

    private func section(_ title: String, _ rows: [NSView]) -> NSView {
        let header = NSTextField(labelWithString: title)
        header.font = .systemFont(ofSize: 11, weight: .semibold)
        header.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [header] + rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }

    private static func wrappingLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.preferredMaxLayoutWidth = contentWidth
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    // MARK: Shortcut

    @objc private func resetShortcut() {
        recorder.endRecording()
        switch commitShortcut(.defaultToggle) {
        case .accepted:
            recorder.message = ""
            recorder.setShortcut(shortcuts.current)
        case let result:
            recorder.message = ShortcutRecorderField.message(for: result)
        }
    }

    // MARK: Providers

    @objc private func toggleProvider(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        preferences.setEnabled(sender.state == .on, for: id)
    }

    // MARK: Updates

    private func refreshUpdates() {
        updatesCheckbox.state = updates.automaticallyChecksForUpdates ? .on : .off
        updatesButton.isEnabled = updates.canCheckForUpdates
        if let date = updates.lastUpdateCheckDate {
            updatesCaption.stringValue = "Last checked \(date.formatted(date: .abbreviated, time: .shortened))"
        } else {
            updatesCaption.stringValue = "Never checked"
        }
    }

    @objc private func toggleAutomaticUpdates() {
        updates.automaticallyChecksForUpdates = updatesCheckbox.state == .on
    }

    @objc private func checkForUpdates() {
        updates.checkForUpdates()
    }

    // MARK: Launch at login

    private func refreshLoginState() {
        guard !isReadingLogin, !isChangingLogin else { return }
        isReadingLogin = true
        let generation = loginGeneration
        showChecking()
        Task { [weak self, launchAtLogin] in
            let state = await launchAtLogin.state()
            guard let self else { return }
            self.isReadingLogin = false
            guard generation == self.loginGeneration, !self.isChangingLogin else { return }
            self.applyLogin(state, errorMessage: nil)
        }
    }

    private func showChecking() {
        launchCheckbox.isEnabled = false
        launchStatus.stringValue = "Checking\u{2026}"
        loginItemsButton.isHidden = true
    }

    @objc private func toggleLaunchAtLogin() {
        guard !isChangingLogin else { return }
        let wanted = launchCheckbox.state == .on
        isChangingLogin = true
        loginGeneration += 1
        launchCheckbox.isEnabled = false
        launchStatus.stringValue = "Updating\u{2026}"
        Task { [weak self, launchAtLogin] in
            let result = await launchAtLogin.setEnabled(wanted)
            guard let self else { return }
            self.isChangingLogin = false
            self.loginGeneration += 1
            switch result {
            case .success(let state):
                self.applyLogin(state, errorMessage: nil)
            case .failure(let error):
                self.applyLogin(error.state, errorMessage: Self.errorMessage(error))
            }
        }
    }

    private func applyLogin(_ state: LaunchAtLoginState, errorMessage: String?) {
        loginState = state
        switch state {
        case .enabled, .requiresApproval: launchCheckbox.state = .on
        case .disabled, .unknown, .unavailable: launchCheckbox.state = .off
        }
        if case .unavailable = state {
            launchCheckbox.isEnabled = false
        } else {
            launchCheckbox.isEnabled = true
        }
        loginItemsButton.isHidden = state != .requiresApproval
        let stateText = Self.statusText(state)
        launchStatus.stringValue = errorMessage.map { "\($0) \(stateText)" } ?? stateText
    }

    private static func statusText(_ state: LaunchAtLoginState) -> String {
        switch state {
        case .enabled: "Opens automatically when you log in."
        case .disabled: "Doesn't open automatically at login."
        case .requiresApproval: "Needs approval in System Settings, Login Items."
        case .unknown: "Status unknown."
        case .unavailable(let reason): reason
        }
    }

    private static func errorMessage(_ error: LaunchAtLoginError) -> String {
        switch error {
        case .unavailable(let reason): reason
        case .failed(let message, _): "Couldn't change the setting: \(message)"
        case .timedOut: "The system didn't respond in time."
        }
    }

    @objc private func openLoginItems() {
        LaunchAtLogin.openSystemSettings()
    }

    // MARK: NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        if !recorder.isRecording {
            recorder.setShortcut(shortcuts.current)
            recorder.message = ""  // An earlier failure is not news when the window comes back.
        }
        refreshLoginState()
        refreshUpdates()
    }

    func windowDidResignKey(_ notification: Notification) {
        recorder.endRecording()
    }

    func windowWillClose(_ notification: Notification) {
        recorder.endRecording()
    }
}
