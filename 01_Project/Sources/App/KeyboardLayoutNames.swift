import Carbon.HIToolbox
import Foundation

/// Names keys the way the user's keyboard labels them.
@MainActor
enum KeyboardLayoutNames {
    static let changedNotification = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)

    /// Uses the ASCII-capable layout rather than the current input source: Russian, Greek and
    /// IME sources yield non-Latin characters or no layout data, while the ASCII-capable layout
    /// is the one that produces the Latin letters shortcuts are written with.
    /// Returns the raw characters the key produces without modifiers, or nil without layout data.
    static func current(_ keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)

        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(
            layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, chars.count, &length, &chars)
        guard status == noErr, length > 0 else { return nil }

        // Raw characters; HotKeyShortcut.displayName(keyName:) uppercases and filters them.
        return String(utf16CodeUnits: chars, count: length)
    }
}

/// Maps key codes to the characters they type with Command held, and back.
/// Shortcuts such as Copy or Settings are defined by character, so validation follows the key
/// that types the letter rather than a US physical position.
struct LayoutTranslator: Sendable {
    /// Character typed by `keyCode` with Command held (Command-specific maps, e.g. "Dvorak – QWERTY ⌘");
    /// nil when the layout is unavailable or the result is empty / multi-character.
    var character: @Sendable (_ keyCode: UInt32) -> Character?
    /// Key code that types `character` (scan 0…127), nil when none.
    var keyCode: @Sendable (_ character: Character) -> UInt32?
}

extension LayoutTranslator {
    /// Builds a translator from a key code to character table; the lowest key code wins when
    /// two keys type the same character.
    init(map: [UInt32: Character]) {
        let reverse = Dictionary(
            map.sorted { $0.key < $1.key }.map { (String($0.value).lowercased(), $0.key) },
            uniquingKeysWith: { first, _ in first })
        self.init(
            character: { map[$0] },
            keyCode: { reverse[String($0).lowercased()] })
    }

    /// Without layout data every lookup misses, so callers fall back to US key positions.
    static let unavailable = LayoutTranslator(character: { _ in nil }, keyCode: { _ in nil })

    static let usANSIMap: [UInt32: Character] = {
        let table: [(Int, Character)] = [
            (kVK_ANSI_A, "a"), (kVK_ANSI_B, "b"), (kVK_ANSI_C, "c"), (kVK_ANSI_D, "d"),
            (kVK_ANSI_E, "e"), (kVK_ANSI_F, "f"), (kVK_ANSI_G, "g"), (kVK_ANSI_H, "h"),
            (kVK_ANSI_I, "i"), (kVK_ANSI_J, "j"), (kVK_ANSI_K, "k"), (kVK_ANSI_L, "l"),
            (kVK_ANSI_M, "m"), (kVK_ANSI_N, "n"), (kVK_ANSI_O, "o"), (kVK_ANSI_P, "p"),
            (kVK_ANSI_Q, "q"), (kVK_ANSI_R, "r"), (kVK_ANSI_S, "s"), (kVK_ANSI_T, "t"),
            (kVK_ANSI_U, "u"), (kVK_ANSI_V, "v"), (kVK_ANSI_W, "w"), (kVK_ANSI_X, "x"),
            (kVK_ANSI_Y, "y"), (kVK_ANSI_Z, "z"),
            (kVK_ANSI_0, "0"), (kVK_ANSI_1, "1"), (kVK_ANSI_2, "2"), (kVK_ANSI_3, "3"),
            (kVK_ANSI_4, "4"), (kVK_ANSI_5, "5"), (kVK_ANSI_6, "6"), (kVK_ANSI_7, "7"),
            (kVK_ANSI_8, "8"), (kVK_ANSI_9, "9"),
            (kVK_ANSI_Minus, "-"), (kVK_ANSI_Equal, "="), (kVK_ANSI_LeftBracket, "["),
            (kVK_ANSI_RightBracket, "]"), (kVK_ANSI_Backslash, "\\"), (kVK_ANSI_Semicolon, ";"),
            (kVK_ANSI_Quote, "'"), (kVK_ANSI_Comma, ","), (kVK_ANSI_Period, "."),
            (kVK_ANSI_Slash, "/"), (kVK_ANSI_Grave, "`"),
        ]
        return Dictionary(uniqueKeysWithValues: table.map { (UInt32($0.0), $0.1) })
    }()

    /// Fallback when the layout is unavailable, and the baseline for tests.
    static let usANSI = LayoutTranslator(map: usANSIMap)

    /// ASCII-capable layout, translated with Command held. Layout data is copied at creation so the
    /// closures never touch Text Input Sources from another thread.
    @MainActor static var current: LayoutTranslator {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return .unavailable }
        let layout = LayoutData(
            data: Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue(),
            keyboardType: UInt32(LMGetKbdType()))
        let character: @Sendable (UInt32) -> Character? = { layout.character(for: $0) }
        return LayoutTranslator(
            character: character,
            keyCode: { target in
                let wanted = String(target).lowercased()
                return (UInt32(0)...127).first { code in
                    character(code).map { String($0).lowercased() == wanted } ?? false
                }
            })
    }

    /// CFData is immutable, so sharing it across threads is safe.
    private struct LayoutData: @unchecked Sendable {
        let data: CFData
        let keyboardType: UInt32

        func character(for keyCode: UInt32) -> Character? {
            guard let code = UInt16(exactly: keyCode), let bytes = CFDataGetBytePtr(data) else { return nil }
            let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKeyState: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let commandState = UInt32((cmdKey >> 8) & 0xFF)
            let status = UCKeyTranslate(
                layout, code, UInt16(kUCKeyActionDown), commandState, keyboardType,
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, chars.count, &length, &chars)
            guard status == noErr, length > 0 else { return nil }
            let text = String(utf16CodeUnits: chars, count: length)
            return text.count == 1 ? text.first : nil
        }
    }
}
