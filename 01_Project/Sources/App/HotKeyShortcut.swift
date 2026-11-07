import AppKit
import Carbon.HIToolbox
import os

struct HotKeyShortcut: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let defaultToggle = HotKeyShortcut(
        keyCode: UInt32(kVK_ANSI_L),
        carbonModifiers: UInt32(controlKey | optionKey | cmdKey)
    )
    static let settings = HotKeyShortcut(
        keyCode: UInt32(kVK_ANSI_Comma),
        carbonModifiers: UInt32(cmdKey)
    )

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    init?(event: NSEvent) {
        guard event.type == .keyDown || event.type == .keyUp else { return nil }
        let code = UInt32(event.keyCode)
        guard !Self.modifierKeyCodes.contains(code) else { return nil }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        self.init(keyCode: code, carbonModifiers: modifiers)
    }

    var displayName: String {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("Control") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("Option") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("Shift") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("Command") }
        parts.append(Self.keyNames[keyCode] ?? "Key \(keyCode)")
        return parts.joined(separator: "\u{2013}")
    }

    enum Rejection: Equatable {
        case needsCommandOrControl
        case unsupportedKey
        case reserved
    }

    func validate() -> Rejection? {
        guard Self.keyNames[keyCode] != nil else { return .unsupportedKey }
        guard carbonModifiers & UInt32(cmdKey | controlKey) != 0 else { return .needsCommandOrControl }
        if self == Self.settings { return .reserved }
        return nil
    }

    private static let modifierKeyCodes: Set<UInt32> = [
        UInt32(kVK_Command), UInt32(kVK_RightCommand), UInt32(kVK_Shift), UInt32(kVK_RightShift),
        UInt32(kVK_Option), UInt32(kVK_RightOption), UInt32(kVK_Control), UInt32(kVK_RightControl),
        UInt32(kVK_CapsLock), UInt32(kVK_Function),
    ]

    private static let keyNames: [UInt32: String] = {
        let table: [(Int, String)] = [
            (kVK_ANSI_A, "A"), (kVK_ANSI_B, "B"), (kVK_ANSI_C, "C"), (kVK_ANSI_D, "D"),
            (kVK_ANSI_E, "E"), (kVK_ANSI_F, "F"), (kVK_ANSI_G, "G"), (kVK_ANSI_H, "H"),
            (kVK_ANSI_I, "I"), (kVK_ANSI_J, "J"), (kVK_ANSI_K, "K"), (kVK_ANSI_L, "L"),
            (kVK_ANSI_M, "M"), (kVK_ANSI_N, "N"), (kVK_ANSI_O, "O"), (kVK_ANSI_P, "P"),
            (kVK_ANSI_Q, "Q"), (kVK_ANSI_R, "R"), (kVK_ANSI_S, "S"), (kVK_ANSI_T, "T"),
            (kVK_ANSI_U, "U"), (kVK_ANSI_V, "V"), (kVK_ANSI_W, "W"), (kVK_ANSI_X, "X"),
            (kVK_ANSI_Y, "Y"), (kVK_ANSI_Z, "Z"),
            (kVK_ANSI_0, "0"), (kVK_ANSI_1, "1"), (kVK_ANSI_2, "2"), (kVK_ANSI_3, "3"),
            (kVK_ANSI_4, "4"), (kVK_ANSI_5, "5"), (kVK_ANSI_6, "6"), (kVK_ANSI_7, "7"),
            (kVK_ANSI_8, "8"), (kVK_ANSI_9, "9"),
            (kVK_ANSI_Keypad0, "Keypad 0"), (kVK_ANSI_Keypad1, "Keypad 1"),
            (kVK_ANSI_Keypad2, "Keypad 2"), (kVK_ANSI_Keypad3, "Keypad 3"),
            (kVK_ANSI_Keypad4, "Keypad 4"), (kVK_ANSI_Keypad5, "Keypad 5"),
            (kVK_ANSI_Keypad6, "Keypad 6"), (kVK_ANSI_Keypad7, "Keypad 7"),
            (kVK_ANSI_Keypad8, "Keypad 8"), (kVK_ANSI_Keypad9, "Keypad 9"),
            (kVK_ANSI_KeypadDecimal, "Keypad ."), (kVK_ANSI_KeypadMultiply, "Keypad *"),
            (kVK_ANSI_KeypadPlus, "Keypad +"), (kVK_ANSI_KeypadClear, "Keypad Clear"),
            (kVK_ANSI_KeypadDivide, "Keypad /"), (kVK_ANSI_KeypadEnter, "Keypad Enter"),
            (kVK_ANSI_KeypadMinus, "Keypad -"), (kVK_ANSI_KeypadEquals, "Keypad ="),
            (kVK_F1, "F1"), (kVK_F2, "F2"), (kVK_F3, "F3"), (kVK_F4, "F4"), (kVK_F5, "F5"),
            (kVK_F6, "F6"), (kVK_F7, "F7"), (kVK_F8, "F8"), (kVK_F9, "F9"), (kVK_F10, "F10"),
            (kVK_F11, "F11"), (kVK_F12, "F12"), (kVK_F13, "F13"), (kVK_F14, "F14"),
            (kVK_F15, "F15"), (kVK_F16, "F16"), (kVK_F17, "F17"), (kVK_F18, "F18"),
            (kVK_F19, "F19"), (kVK_F20, "F20"),
            (kVK_LeftArrow, "Left Arrow"), (kVK_RightArrow, "Right Arrow"),
            (kVK_UpArrow, "Up Arrow"), (kVK_DownArrow, "Down Arrow"),
            (kVK_Space, "Space"), (kVK_Return, "Return"), (kVK_Tab, "Tab"),
            (kVK_Delete, "Delete"), (kVK_ForwardDelete, "Forward Delete"), (kVK_Escape, "Escape"),
            (kVK_Home, "Home"), (kVK_End, "End"), (kVK_PageUp, "Page Up"),
            (kVK_PageDown, "Page Down"), (kVK_Help, "Help"),
            (kVK_ANSI_Minus, "-"), (kVK_ANSI_Equal, "="), (kVK_ANSI_LeftBracket, "["),
            (kVK_ANSI_RightBracket, "]"), (kVK_ANSI_Backslash, "\\"), (kVK_ANSI_Semicolon, ";"),
            (kVK_ANSI_Quote, "'"), (kVK_ANSI_Comma, ","), (kVK_ANSI_Period, "."),
            (kVK_ANSI_Slash, "/"), (kVK_ANSI_Grave, "`"),
        ]
        return Dictionary(uniqueKeysWithValues: table.map { (UInt32($0.0), $0.1) })
    }()
}

@MainActor
final class HotKeyShortcutStore {
    nonisolated private static let logger = Logger(subsystem: "com.sim.LLM-UsageStatus", category: "HotKeyShortcut")
    static let defaultsKey = "hotkey.toggleShortcut"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var current: HotKeyShortcut {
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return .defaultToggle }
        do {
            return try JSONDecoder().decode(HotKeyShortcut.self, from: data)
        } catch {
            // Stored bytes are left untouched so a later build can still read them.
            Self.logger.error("Stored toggle shortcut is undecodable; using default")
            return .defaultToggle
        }
    }

    func save(_ shortcut: HotKeyShortcut) {
        do {
            defaults.set(try JSONEncoder().encode(shortcut), forKey: Self.defaultsKey)
        } catch {
            Self.logger.error("Toggle shortcut could not be encoded; not saved")
        }
    }

    func reset() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
