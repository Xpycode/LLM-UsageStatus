import AppKit
import Carbon.HIToolbox

/// Click-to-record control for the global toggle shortcut.
///
/// While recording, a local key monitor forwards events to `handle(_:)` and swallows them.
/// `recordingChanged(false)` fires exactly once per session however recording ends.
@MainActor
final class ShortcutRecorderField: NSView {
    private(set) var shortcut: HotKeyShortcut
    private(set) var isRecording = false

    /// Inline feedback text for the owner to display; empty when there is nothing to say.
    var message = "" {
        didSet {
            if message != oldValue { onMessageChange?(message) }
        }
    }
    var onMessageChange: ((String) -> Void)?

    private let commit: (HotKeyShortcut) -> ShortcutCommitResult
    private let recordingChanged: (Bool) -> Void
    private let label = NSTextField(labelWithString: "")
    // Only written on the main actor; nonisolated(unsafe) lets deinit remove the monitor.
    nonisolated(unsafe) private var monitor: Any?

    init(
        shortcut: HotKeyShortcut,
        commit: @escaping (HotKeyShortcut) -> ShortcutCommitResult,
        recordingChanged: @escaping (Bool) -> Void
    ) {
        self.shortcut = shortcut
        self.commit = commit
        self.recordingChanged = recordingChanged
        super.init(frame: NSRect(x: 0, y: 0, width: 190, height: 26))
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        label.alignment = .center
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 6),
            widthAnchor.constraint(equalToConstant: 190),
            heightAnchor.constraint(equalToConstant: 26),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Show/hide shortcut")
        refreshDisplay()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    // MARK: Public seams

    func setShortcut(_ newValue: HotKeyShortcut) {
        shortcut = newValue
        refreshDisplay()
    }

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        message = ""
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            let consumed = MainActor.assumeIsolated { self?.handle(event) ?? false }
            return consumed ? nil : event
        }
        refreshDisplay()
        recordingChanged(true)
    }

    func endRecording() {
        guard isRecording else { return }
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        refreshDisplay()
        recordingChanged(false)
    }

    /// Returns true when the event was consumed by the recorder.
    func handle(_ event: NSEvent) -> Bool {
        guard isRecording else { return false }
        if event.type == .flagsChanged { return true }
        guard event.type == .keyDown else { return false }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.keyCode == UInt16(kVK_Escape) && modifiers.isEmpty {
            message = ""
            endRecording()
            return true
        }
        guard let candidate = HotKeyShortcut(event: event) else { return true }
        if let rejection = candidate.validate() {
            message = Self.message(for: rejection)
            return true
        }
        switch commit(candidate) {
        case .accepted:
            shortcut = candidate
            message = ""
        case .inUse:
            message = Self.message(for: .inUse)
        case .failed(let status):
            message = Self.message(for: .failed(status))
        }
        endRecording()
        return true
    }

    static func message(for rejection: HotKeyShortcut.Rejection) -> String {
        switch rejection {
        case .needsCommandOrControl: "Use Command or Control in the shortcut."
        case .unsupportedKey: "That key can't be used as a shortcut."
        case .reserved: "Command-Comma is reserved for Settings."
        case .systemShortcut: "That shortcut is used by macOS and other apps."
        }
    }

    static func message(for result: ShortcutCommitResult) -> String {
        switch result {
        case .accepted: ""
        case .inUse: "Already in use by another app."
        case .failed(let status): "Couldn't register the shortcut (error \(status))."
        }
    }

    // MARK: NSView / NSResponder

    override var acceptsFirstResponder: Bool { true }
    override var wantsUpdateLayer: Bool { true }

    override func resignFirstResponder() -> Bool {
        endRecording()
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        startRecording()
    }

    override func keyDown(with event: NSEvent) {
        // Keyboard activation when focused but not recording.
        // Bare, non-repeating presses only: holding a just-recorded Control-Space must not restart.
        let bare = event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
        if !isRecording, !event.isARepeat, bare,
           event.keyCode == UInt16(kVK_Space) || event.keyCode == UInt16(kVK_Return) {
            startRecording()
        } else {
            super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        window?.makeFirstResponder(self)
        startRecording()
        return true
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            let border: NSColor = isRecording ? .controlAccentColor : .separatorColor
            layer?.borderColor = border.cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        needsDisplay = true
    }

    private func refreshDisplay() {
        label.stringValue = isRecording ? "Type shortcut\u{2026}" : shortcut.displayName
        label.textColor = isRecording ? .secondaryLabelColor : .labelColor
        setAccessibilityValue(label.stringValue)
        needsDisplay = true
    }
}
