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

    private func makeRecorder() -> ShortcutRecorderField {
        let probe = probe
        return ShortcutRecorderField(
            shortcut: .defaultToggle,
            commit: { shortcut in
                probe.commits.append(shortcut)
                return probe.result
            },
            recordingChanged: { probe.recording.append($0) })
    }

    private func keyDown(_ code: Int, _ flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                isARepeat: false, keyCode: UInt16(code)))
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

    func testWindowControllerSmoke() {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let controller = SettingsWindowController(
            shortcuts: HotKeyShortcutStore(defaults: defaults),
            launchAtLogin: LaunchAtLogin(),
            version: AppVersion(infoDictionary: nil),
            commitShortcut: { _ in .accepted },
            recordingChanged: { _ in })
        XCTAssertEqual(controller.window.title, "LLM Usage Status Settings")
        XCTAssertEqual(controller.window.styleMask, [.titled, .closable])
        XCTAssertFalse(controller.window.isReleasedWhenClosed)
    }
}
