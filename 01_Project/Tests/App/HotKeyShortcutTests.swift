import AppKit
import Carbon.HIToolbox
import XCTest
@testable import LLMUsageStatus

@MainActor
final class HotKeyShortcutTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "HotKeyShortcutTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
    }

    private func keyEvent(_ code: Int, _ flags: NSEvent.ModifierFlags, type: NSEvent.EventType = .keyDown) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: type, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
            context: nil, characters: "x", charactersIgnoringModifiers: "x",
            isARepeat: false, keyCode: UInt16(code)))
    }

    func testEventMapsAllFourModifiers() throws {
        let event = try keyEvent(kVK_ANSI_L, [.command, .option, .control, .shift])
        let shortcut = try XCTUnwrap(HotKeyShortcut(event: event))
        XCTAssertEqual(shortcut.keyCode, UInt32(kVK_ANSI_L))
        XCTAssertEqual(shortcut.carbonModifiers, UInt32(cmdKey | optionKey | controlKey | shiftKey))
    }

    func testEventIgnoresCapsLockAndFunction() throws {
        let event = try keyEvent(kVK_ANSI_L, [.control, .option, .command, .capsLock, .function])
        XCTAssertEqual(HotKeyShortcut(event: event), .defaultToggle)
    }

    func testBareModifierEventsReturnNil() throws {
        for code in [kVK_Command, kVK_Shift, kVK_Option, kVK_Control, kVK_CapsLock, kVK_Function, kVK_RightCommand] {
            XCTAssertNil(HotKeyShortcut(event: try keyEvent(code, [.command])), "keyCode \(code)")
        }
    }

    func testDisplayNameDefaultsAndOrdering() {
        XCTAssertEqual(HotKeyShortcut.defaultToggle.displayName, "Control\u{2013}Option\u{2013}Command\u{2013}L")
        XCTAssertEqual(HotKeyShortcut.settings.displayName, "Command\u{2013},")
        let all = HotKeyShortcut(keyCode: UInt32(kVK_ANSI_A), carbonModifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey))
        XCTAssertEqual(all.displayName, "Control\u{2013}Option\u{2013}Shift\u{2013}Command\u{2013}A")
    }

    func testDisplayNameKeyTable() {
        let cmd = UInt32(cmdKey)
        func name(_ code: Int) -> String { HotKeyShortcut(keyCode: UInt32(code), carbonModifiers: cmd).displayName }
        XCTAssertEqual(name(kVK_ANSI_1), "Command\u{2013}1")
        XCTAssertEqual(name(kVK_ANSI_Keypad1), "Command\u{2013}Keypad 1")
        XCTAssertNotEqual(name(kVK_ANSI_1), name(kVK_ANSI_Keypad1))
        XCTAssertEqual(name(kVK_F5), "Command\u{2013}F5")
        XCTAssertEqual(name(kVK_LeftArrow), "Command\u{2013}Left Arrow")
        XCTAssertEqual(name(kVK_Space), "Command\u{2013}Space")
        XCTAssertEqual(name(kVK_Return), "Command\u{2013}Return")
        XCTAssertEqual(name(kVK_Tab), "Command\u{2013}Tab")
        XCTAssertEqual(name(kVK_Delete), "Command\u{2013}Delete")
        XCTAssertEqual(name(kVK_ANSI_Slash), "Command\u{2013}/")
    }

    func testValidateAcceptsDefault() {
        XCTAssertNil(HotKeyShortcut.defaultToggle.validate())
    }

    func testValidateRejectsMissingCommandOrControl() {
        let optionShift = HotKeyShortcut(keyCode: UInt32(kVK_ANSI_L), carbonModifiers: UInt32(optionKey | shiftKey))
        XCTAssertEqual(optionShift.validate(), .needsCommandOrControl)
        XCTAssertEqual(HotKeyShortcut(keyCode: UInt32(kVK_ANSI_L), carbonModifiers: 0).validate(), .needsCommandOrControl)
        XCTAssertNil(HotKeyShortcut(keyCode: UInt32(kVK_ANSI_L), carbonModifiers: UInt32(controlKey)).validate())
    }

    func testValidateRejectsUnsupportedKeys() {
        let cmd = UInt32(cmdKey)
        XCTAssertEqual(HotKeyShortcut(keyCode: UInt32(kVK_Shift), carbonModifiers: cmd).validate(), .unsupportedKey)
        XCTAssertEqual(HotKeyShortcut(keyCode: UInt32(kVK_Command), carbonModifiers: cmd).validate(), .unsupportedKey)
        XCTAssertEqual(HotKeyShortcut(keyCode: 0x90, carbonModifiers: cmd).validate(), .unsupportedKey)
        XCTAssertEqual(HotKeyShortcut(keyCode: 200, carbonModifiers: 0).validate(), .unsupportedKey)
    }

    func testValidateRejectsReservedSettingsShortcut() {
        XCTAssertEqual(HotKeyShortcut.settings.validate(), .reserved)
    }

    func testValidateRejectsStandardSystemShortcuts() {
        let cmd = UInt32(cmdKey), cmdShift = UInt32(cmdKey | shiftKey)
        XCTAssertEqual(HotKeyShortcut(keyCode: UInt32(kVK_ANSI_C), carbonModifiers: cmd).validate(), .systemShortcut)
        XCTAssertEqual(HotKeyShortcut(keyCode: UInt32(kVK_ANSI_Q), carbonModifiers: cmd).validate(), .systemShortcut)
        XCTAssertEqual(HotKeyShortcut(keyCode: UInt32(kVK_Space), carbonModifiers: cmd).validate(), .systemShortcut)
        XCTAssertEqual(HotKeyShortcut(keyCode: UInt32(kVK_ANSI_Z), carbonModifiers: cmdShift).validate(), .systemShortcut)
        // Adding Control or Option makes the same keys fine; other Command-only keys stay allowed.
        XCTAssertNil(HotKeyShortcut(keyCode: UInt32(kVK_ANSI_C), carbonModifiers: UInt32(cmdKey | optionKey)).validate())
        XCTAssertNil(HotKeyShortcut(keyCode: UInt32(kVK_ANSI_C), carbonModifiers: UInt32(controlKey)).validate())
        XCTAssertNil(HotKeyShortcut(keyCode: UInt32(kVK_ANSI_K), carbonModifiers: cmd).validate())
    }

    func testStoreDefaultsWhenMissing() {
        XCTAssertEqual(HotKeyShortcutStore(defaults: defaults).current, .defaultToggle)
    }

    func testStoreRoundTripAndReset() {
        let store = HotKeyShortcutStore(defaults: defaults)
        let custom = HotKeyShortcut(keyCode: UInt32(kVK_F5), carbonModifiers: UInt32(cmdKey | shiftKey))
        store.save(custom)
        XCTAssertEqual(store.current, custom)
        XCTAssertEqual(HotKeyShortcutStore(defaults: defaults).current, custom)
        store.reset()
        XCTAssertEqual(store.current, .defaultToggle)
        XCTAssertNil(defaults.object(forKey: "hotkey.toggleShortcut"))
    }

    func testCorruptDataFallsBackAndIsPreserved() {
        let corrupt = Data("not json".utf8)
        defaults.set(corrupt, forKey: "hotkey.toggleShortcut")
        let store = HotKeyShortcutStore(defaults: defaults)
        XCTAssertEqual(store.current, .defaultToggle)
        XCTAssertEqual(defaults.data(forKey: "hotkey.toggleShortcut"), corrupt)
    }

    func testDisallowedStoredShortcutFallsBack() throws {
        let stored = try JSONEncoder().encode(HotKeyShortcut.settings)
        defaults.set(stored, forKey: "hotkey.toggleShortcut")
        XCTAssertEqual(HotKeyShortcutStore(defaults: defaults).current, .defaultToggle)
        XCTAssertEqual(defaults.data(forKey: "hotkey.toggleShortcut"), stored)
    }

    func testWrongTypeDataFallsBackAndIsPreserved() {
        defaults.set("a string", forKey: "hotkey.toggleShortcut")
        XCTAssertEqual(HotKeyShortcutStore(defaults: defaults).current, .defaultToggle)
        XCTAssertEqual(defaults.string(forKey: "hotkey.toggleShortcut"), "a string")
    }
}
