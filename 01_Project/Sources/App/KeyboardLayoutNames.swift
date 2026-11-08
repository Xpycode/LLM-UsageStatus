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
