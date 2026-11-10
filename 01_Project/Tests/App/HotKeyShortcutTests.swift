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

    private let usOnly: (UInt32) -> String? = { _ in nil }

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
        XCTAssertEqual(HotKeyShortcut.defaultToggle.displayName(keyName: usOnly), "Control\u{2013}Option\u{2013}Command\u{2013}L")
        XCTAssertEqual(HotKeyShortcut.settings.displayName(keyName: usOnly), "Command\u{2013},")
        let all = HotKeyShortcut(keyCode: UInt32(kVK_ANSI_A), carbonModifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey))
        XCTAssertEqual(all.displayName(keyName: usOnly), "Control\u{2013}Option\u{2013}Shift\u{2013}Command\u{2013}A")
    }

    func testDisplayNameKeyTable() {
        let cmd = UInt32(cmdKey)
        func name(_ code: Int) -> String { HotKeyShortcut(keyCode: UInt32(code), carbonModifiers: cmd).displayName(keyName: usOnly) }
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

    func testLayoutNameReplacesUSName() {
        let german: [UInt32: String] = [UInt32(kVK_ANSI_Y): "z", UInt32(kVK_ANSI_Z): "y"]
        let shortcut = HotKeyShortcut(keyCode: UInt32(kVK_ANSI_Y), carbonModifiers: UInt32(controlKey | cmdKey))
        XCTAssertEqual(shortcut.displayName(keyName: { german[$0] }), "Control\u{2013}Command\u{2013}Z")
        let other = HotKeyShortcut(keyCode: UInt32(kVK_ANSI_Z), carbonModifiers: UInt32(controlKey))
        XCTAssertEqual(other.displayName(keyName: { german[$0] }), "Control\u{2013}Y")
        // Keys the fake does not know keep their US name.
        XCTAssertEqual(HotKeyShortcut.defaultToggle.displayName(keyName: { german[$0] }), "Control\u{2013}Option\u{2013}Command\u{2013}L")
    }

    func testUnusableLayoutNamesFallBackToUSName() {
        for bad in [nil, "", " ", "\u{10}"] as [String?] {
            XCTAssertEqual(
                HotKeyShortcut.defaultToggle.displayName(keyName: { _ in bad }),
                "Control\u{2013}Option\u{2013}Command\u{2013}L", "layout name \(String(describing: bad))")
        }
    }

    func testNonCharacterKeysNeverAskForLayoutName() {
        var asked: [UInt32] = []
        let recording: (UInt32) -> String? = { asked.append($0); return "?" }
        for code in [kVK_F5, kVK_Space, kVK_ANSI_Keypad1, kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow,
                     kVK_DownArrow, kVK_Return, kVK_Tab, kVK_Delete, kVK_ForwardDelete, kVK_Escape,
                     kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown, kVK_Help, kVK_ANSI_KeypadPlus] {
            _ = HotKeyShortcut(keyCode: UInt32(code), carbonModifiers: UInt32(cmdKey)).displayName(keyName: recording)
        }
        XCTAssertTrue(asked.isEmpty, "asked for \(asked)")
    }

    func testLiveDefaultToggleName() {
        // L sits on the same key on US, QWERTZ and AZERTY layouts.
        XCTAssertEqual(HotKeyShortcut.defaultToggle.displayName, "Control\u{2013}Option\u{2013}Command\u{2013}L")
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

    // MARK: Fake layouts

    private func fake(_ overrides: [Int: Character]) -> LayoutTranslator {
        var map = LayoutTranslator.usANSIMap
        for (code, char) in overrides { map[UInt32(code)] = char }
        return LayoutTranslator(map: map)
    }

    private var qwertz: LayoutTranslator { fake([kVK_ANSI_Y: "z", kVK_ANSI_Z: "y"]) }
    private var azerty: LayoutTranslator {
        fake([kVK_ANSI_A: "q", kVK_ANSI_Q: "a", kVK_ANSI_Z: "w", kVK_ANSI_W: "z",
              kVK_ANSI_Semicolon: "m", kVK_ANSI_M: ",", kVK_ANSI_Comma: ";"])
    }
    private var dvorak: LayoutTranslator { fake([kVK_ANSI_I: "c", kVK_ANSI_C: "j", kVK_ANSI_J: "h"]) }
    /// Dvorak whose Command map is QWERTY: characters are the US letters.
    private var commandQwerty: LayoutTranslator { .usANSI }
    private let noLayout = LayoutTranslator(character: { _ in nil }, keyCode: { _ in nil })

    private func cmd(_ code: Int, shift: Bool = false) -> HotKeyShortcut {
        HotKeyShortcut(keyCode: UInt32(code), carbonModifiers: UInt32(shift ? cmdKey | shiftKey : cmdKey))
    }

    func testValidateRejectsReservedSettingsShortcut() {
        XCTAssertNil(HotKeyShortcut.settings.validate())
        XCTAssertEqual(HotKeyShortcut.settings.validate(using: .usANSI), .reserved)
    }

    func testValidateRejectsStandardSystemShortcuts() {
        let us = LayoutTranslator.usANSI
        XCTAssertEqual(cmd(kVK_ANSI_C).validate(using: us), .systemShortcut)
        XCTAssertEqual(cmd(kVK_ANSI_Q).validate(using: us), .systemShortcut)
        XCTAssertEqual(cmd(kVK_Space).validate(using: us), .systemShortcut)
        XCTAssertEqual(cmd(kVK_ANSI_Z, shift: true).validate(using: us), .systemShortcut)
        // Adding Control or Option makes the same keys fine; other Command-only keys stay allowed.
        XCTAssertNil(HotKeyShortcut(keyCode: UInt32(kVK_ANSI_C), carbonModifiers: UInt32(cmdKey | optionKey)).validate(using: us))
        XCTAssertNil(HotKeyShortcut(keyCode: UInt32(kVK_ANSI_C), carbonModifiers: UInt32(controlKey)).validate(using: us))
        XCTAssertNil(cmd(kVK_ANSI_K).validate(using: us))
    }

    func testQWERTZRefusesKeyTypingZAndAcceptsKeyTypingY() {
        // Physical Y position types "z" on QWERTZ.
        XCTAssertEqual(cmd(kVK_ANSI_Y).validate(using: qwertz), .systemShortcut)
        XCTAssertEqual(cmd(kVK_ANSI_Y, shift: true).validate(using: qwertz), .systemShortcut)
        XCTAssertNil(cmd(kVK_ANSI_Z).validate(using: qwertz))
    }

    func testDvorakRefusesKeyTypingC() {
        XCTAssertEqual(cmd(kVK_ANSI_I).validate(using: dvorak), .systemShortcut)
        XCTAssertNil(cmd(kVK_ANSI_C).validate(using: dvorak))
    }

    func testCommandQwertyLayoutFollowsUSLetters() {
        XCTAssertEqual(cmd(kVK_ANSI_C).validate(using: commandQwerty), .systemShortcut)
        XCTAssertNil(cmd(kVK_ANSI_K).validate(using: commandQwerty))
    }

    func testAZERTYReservedFollowsKeyTypingComma() {
        XCTAssertEqual(cmd(kVK_ANSI_M).validate(using: azerty), .reserved)
        // The US comma position types ";" on AZERTY, so it is free.
        XCTAssertNil(cmd(kVK_ANSI_Comma).validate(using: azerty))
        // The key typing "m" is a system shortcut even at the US semicolon position.
        XCTAssertEqual(cmd(kVK_ANSI_Semicolon).validate(using: azerty), .systemShortcut)
    }

    func testSettingsUsingTranslator() {
        XCTAssertEqual(HotKeyShortcut.settings(using: azerty).keyCode, UInt32(kVK_ANSI_M))
        XCTAssertEqual(HotKeyShortcut.settings(using: azerty).carbonModifiers, UInt32(cmdKey))
        XCTAssertEqual(HotKeyShortcut.settings(using: .usANSI), .settings)
    }

    func testNilTranslatorUsesUSBehaviour() {
        XCTAssertEqual(HotKeyShortcut.settings(using: noLayout), .settings)
        XCTAssertEqual(HotKeyShortcut.settings.validate(using: noLayout), .reserved)
        XCTAssertEqual(cmd(kVK_ANSI_C).validate(using: noLayout), .systemShortcut)
        XCTAssertEqual(cmd(kVK_ANSI_Z, shift: true).validate(using: noLayout), .systemShortcut)
        XCTAssertNil(cmd(kVK_ANSI_K).validate(using: noLayout))
        XCTAssertNil(cmd(kVK_ANSI_Y).validate(using: noLayout))
    }

    func testISOSectionKeySupport() {
        let iso = UInt32(kVK_ISO_Section)
        XCTAssertNil(HotKeyShortcut(keyCode: iso, carbonModifiers: UInt32(controlKey | cmdKey)).validate())
        XCTAssertNil(HotKeyShortcut(keyCode: iso, carbonModifiers: UInt32(controlKey | cmdKey)).validate(using: .usANSI))
        XCTAssertNil(HotKeyShortcut(keyCode: iso, carbonModifiers: UInt32(cmdKey)).validate())
        XCTAssertEqual(cmd(kVK_ISO_Section).validate(using: .usANSI), .systemShortcut)
        XCTAssertEqual(cmd(kVK_ISO_Section, shift: true).validate(using: azerty), .systemShortcut)
        XCTAssertEqual(cmd(kVK_ANSI_Grave).validate(using: azerty), .systemShortcut)
    }

    func testISOSectionDisplayNameUsesLayout() {
        let shortcut = HotKeyShortcut(keyCode: UInt32(kVK_ISO_Section), carbonModifiers: UInt32(controlKey))
        XCTAssertEqual(shortcut.displayName(keyName: { _ in "<" }), "Control\u{2013}<")
        XCTAssertEqual(shortcut.displayName(keyName: { _ in "\u{00A7}" }), "Control\u{2013}\u{00A7}")
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

    func testStoredShortcutTheLayoutWouldRefuseStillLoads() throws {
        // Only the structural check applies, so switching layouts never resets a saved chord.
        let stored = try JSONEncoder().encode(HotKeyShortcut.settings)
        defaults.set(stored, forKey: "hotkey.toggleShortcut")
        XCTAssertEqual(HotKeyShortcutStore(defaults: defaults).current, .settings)
        XCTAssertEqual(defaults.data(forKey: "hotkey.toggleShortcut"), stored)
    }

    func testStructurallyInvalidStoredShortcutFallsBack() throws {
        let stored = try JSONEncoder().encode(HotKeyShortcut(keyCode: UInt32(kVK_ANSI_L), carbonModifiers: UInt32(shiftKey)))
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
