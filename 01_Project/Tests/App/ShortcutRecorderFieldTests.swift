import AppKit
import Carbon.HIToolbox
import XCTest
@testable import LLMUsageStatus

@MainActor
final class ShortcutRecorderFieldTests: XCTestCase {
    private final class Probe {
        var commits: [HotKeyShortcut] = []
        var recording: [Bool] = []
        var result: ShortcutCommitResult = .accepted
    }

    private var probe = Probe()
    private var suiteName = ""

    override func setUp() async throws {
        probe = Probe()
        suiteName = "ShortcutRecorderFieldTests-\(UUID().uuidString)"
    }

    override func tearDown() async throws {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    private func makeRecorder(translator: LayoutTranslator = .usANSI) -> ShortcutRecorderField {
        let probe = probe
        return ShortcutRecorderField(
            shortcut: .defaultToggle,
            translator: { translator },
            commit: { shortcut in
                probe.commits.append(shortcut)
                return probe.result
            },
            recordingChanged: { probe.recording.append($0) })
    }

    private func keyDown(_ code: Int, _ flags: NSEvent.ModifierFlags = [], repeat isRepeat: Bool = false) throws -> NSEvent {
        try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                isARepeat: isRepeat, keyCode: UInt16(code)))
    }

    func testSystemShortcutIsRejectedAndRecordingContinues() throws {
        let recorder = makeRecorder()
        recorder.startRecording()
        XCTAssertTrue(recorder.handle(try keyDown(kVK_ANSI_C, [.command])))
        XCTAssertTrue(recorder.isRecording)
        XCTAssertTrue(probe.commits.isEmpty)
        XCTAssertEqual(recorder.message, "That shortcut is used by macOS and other apps.")
        recorder.endRecording()
    }

    func testOnlyBareNonRepeatingSpaceStartsRecording() throws {
        let recorder = makeRecorder()
        recorder.keyDown(with: try keyDown(kVK_Space, [.control]))
        recorder.keyDown(with: try keyDown(kVK_Space, repeat: true))
        XCTAssertFalse(recorder.isRecording)
        recorder.keyDown(with: try keyDown(kVK_Space))
        XCTAssertTrue(recorder.isRecording)
        recorder.endRecording()
    }

    func testStartNotifiesAndShowsPlaceholder() {
        let recorder = makeRecorder()
        recorder.startRecording()
        recorder.startRecording()
        XCTAssertTrue(recorder.isRecording)
        XCTAssertEqual(probe.recording, [true])
        recorder.endRecording()
    }

    func testEscapeCancelsWithoutCommit() throws {
        let recorder = makeRecorder()
        recorder.startRecording()
        XCTAssertTrue(recorder.handle(try keyDown(kVK_Escape)))
        XCTAssertFalse(recorder.isRecording)
        XCTAssertTrue(probe.commits.isEmpty)
        XCTAssertEqual(recorder.shortcut, .defaultToggle)
        XCTAssertEqual(probe.recording, [true, false])
    }

    func testMissingCommandOrControlStaysRecording() throws {
        let recorder = makeRecorder()
        recorder.startRecording()
        XCTAssertTrue(recorder.handle(try keyDown(kVK_ANSI_L, [.shift])))
        XCTAssertEqual(recorder.message, "Use Command or Control in the shortcut.")
        XCTAssertTrue(recorder.isRecording)
        XCTAssertTrue(probe.commits.isEmpty)
        recorder.endRecording()
    }

    func testUnsupportedKeyStaysRecording() throws {
        let recorder = makeRecorder()
        recorder.startRecording()
        XCTAssertTrue(recorder.handle(try keyDown(200, [.command])))
        XCTAssertEqual(recorder.message, "That key can't be used as a shortcut.")
        XCTAssertTrue(recorder.isRecording)
        XCTAssertTrue(probe.commits.isEmpty)
        recorder.endRecording()
    }

    func testReservedSettingsChordRejected() throws {
        let recorder = makeRecorder()
        recorder.startRecording()
        XCTAssertTrue(recorder.handle(try keyDown(kVK_ANSI_Comma, [.command])))
        XCTAssertEqual(recorder.message, "Command-Comma is reserved for Settings.")
        XCTAssertTrue(recorder.isRecording)
        XCTAssertTrue(probe.commits.isEmpty)
        recorder.endRecording()
    }

    func testReservedChordFollowsLayoutKey() throws {
        // AZERTY: "," is typed by the US M position; the US comma position types ";".
        var map = LayoutTranslator.usANSIMap
        map[UInt32(kVK_ANSI_M)] = ","
        map[UInt32(kVK_ANSI_Comma)] = ";"
        let recorder = makeRecorder(translator: LayoutTranslator(map: map))
        recorder.startRecording()
        XCTAssertTrue(recorder.handle(try keyDown(kVK_ANSI_M, [.command])))
        XCTAssertEqual(recorder.message, "Command-Comma is reserved for Settings.")
        XCTAssertTrue(recorder.isRecording)
        XCTAssertTrue(recorder.handle(try keyDown(kVK_ANSI_Comma, [.command])))
        XCTAssertEqual(recorder.message, "")
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(probe.commits.count, 1)
    }

    func testSystemShortcutFollowsLayoutKey() throws {
        // QWERTZ: the US Y position types "z".
        var map = LayoutTranslator.usANSIMap
        map[UInt32(kVK_ANSI_Y)] = "z"
        map[UInt32(kVK_ANSI_Z)] = "y"
        let recorder = makeRecorder(translator: LayoutTranslator(map: map))
        recorder.startRecording()
        XCTAssertTrue(recorder.handle(try keyDown(kVK_ANSI_Y, [.command])))
        XCTAssertEqual(recorder.message, "That shortcut is used by macOS and other apps.")
        XCTAssertTrue(recorder.isRecording)
        recorder.endRecording()
    }

    func testInUseKeepsPreviousChordAndEnds() throws {
        probe.result = .inUse
        let recorder = makeRecorder()
        recorder.startRecording()
        XCTAssertTrue(recorder.handle(try keyDown(kVK_ANSI_K, [.command])))
        XCTAssertEqual(recorder.message, "Already in use by another app.")
        XCTAssertEqual(recorder.shortcut, .defaultToggle)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(probe.recording, [true, false])
    }

    func testFailedKeepsPreviousChordAndEnds() throws {
        probe.result = .failed(-9878)
        let recorder = makeRecorder()
        recorder.startRecording()
        XCTAssertTrue(recorder.handle(try keyDown(kVK_ANSI_K, [.command])))
        XCTAssertEqual(recorder.message, "Couldn't register the shortcut (error -9878).")
        XCTAssertEqual(recorder.shortcut, .defaultToggle)
        XCTAssertEqual(probe.recording, [true, false])
    }

    func testAcceptedShowsNewChord() throws {
        let recorder = makeRecorder()
        recorder.startRecording()
        XCTAssertTrue(recorder.handle(try keyDown(kVK_ANSI_K, [.command, .shift])))
        let expected = HotKeyShortcut(
            keyCode: UInt32(kVK_ANSI_K), carbonModifiers: UInt32(cmdKey | shiftKey))
        XCTAssertEqual(probe.commits, [expected])
        XCTAssertEqual(recorder.shortcut, expected)
        XCTAssertEqual(recorder.message, "")
        XCTAssertFalse(recorder.isRecording)
    }

    func testEndIsIdempotent() throws {
        let recorder = makeRecorder()
        recorder.startRecording()
        _ = recorder.handle(try keyDown(kVK_ANSI_K, [.command]))
        recorder.endRecording()
        recorder.endRecording()
        XCTAssertEqual(probe.recording, [true, false])
    }

    func testEventsPassThroughWhenNotRecording() throws {
        let recorder = makeRecorder()
        XCTAssertFalse(recorder.handle(try keyDown(kVK_ANSI_K, [.command])))
        XCTAssertTrue(probe.recording.isEmpty)
    }

    private final class NameSource {
        var name = "Y"
    }

    private func makeLayoutRecorder(
        center: NotificationCenter, source: NameSource
    ) -> ShortcutRecorderField {
        ShortcutRecorderField(
            shortcut: HotKeyShortcut(keyCode: UInt32(kVK_ANSI_Z), carbonModifiers: UInt32(cmdKey | shiftKey)),
            notificationCenter: center,
            keyName: { _ in source.name },
            commit: { _ in .accepted },
            recordingChanged: { _ in })
    }

    func testLayoutChangeRefreshesDisplay() {
        let center = NotificationCenter()
        let source = NameSource()
        let recorder = makeLayoutRecorder(center: center, source: source)
        XCTAssertEqual(recorder.accessibilityValue() as? String, HotKeyShortcut(
            keyCode: UInt32(kVK_ANSI_Z), carbonModifiers: UInt32(cmdKey | shiftKey)
        ).displayName(keyName: { _ in "Y" }))
        XCTAssertTrue((recorder.accessibilityValue() as? String)?.hasSuffix("Y") == true)
        source.name = "Z"
        center.post(name: KeyboardLayoutNames.changedNotification, object: nil)
        XCTAssertTrue((recorder.accessibilityValue() as? String)?.hasSuffix("Z") == true)
    }

    func testLayoutChangeWhileRecordingKeepsPlaceholder() {
        let center = NotificationCenter()
        let source = NameSource()
        let recorder = makeLayoutRecorder(center: center, source: source)
        recorder.startRecording()
        source.name = "Z"
        center.post(name: KeyboardLayoutNames.changedNotification, object: nil)
        XCTAssertEqual(recorder.accessibilityValue() as? String, "Type shortcut\u{2026}")
        recorder.endRecording()
    }

    func testPostAfterDeallocationIsSafe() {
        let center = NotificationCenter()
        var recorder: ShortcutRecorderField? = makeLayoutRecorder(center: center, source: NameSource())
        XCTAssertNotNil(recorder)
        recorder = nil
        center.post(name: KeyboardLayoutNames.changedNotification, object: nil)
    }

    func testWindowControllerSmoke() {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let controller = SettingsWindowController(
            preferences: UsagePreferences(defaults: defaults),
            shortcuts: HotKeyShortcutStore(defaults: defaults),
            launchAtLogin: LaunchAtLogin(),
            version: AppVersion(infoDictionary: nil),
            updates: UpdateController(startingUpdater: false),
            commitShortcut: { _ in .accepted },
            recordingChanged: { _ in })
        XCTAssertEqual(controller.window.title, "LLM Usage Status Settings")
        XCTAssertEqual(controller.window.styleMask, [.titled, .closable])
        XCTAssertFalse(controller.window.isReleasedWhenClosed)
    }
}
