import Carbon.HIToolbox
import Foundation
import os

@MainActor final class GlobalHotKey {
    nonisolated private static let logger = Logger(subsystem: "com.sim.LLM-UsageStatus", category: "HotKey")
    static let shared: GlobalHotKey = {
        var backend = Backend.live
        #if DEBUG
        // Opt-in, process-local acceptance fixture; Release ignores this variable.
        if let path = ProcessInfo.processInfo.environment["LUHS_HOTKEY_CONFLICT_FILE"], path.hasPrefix("/") {
            backend = backend.simulatingConflict(whileFileExists: URL(fileURLWithPath: path))
        }
        #endif
        return GlobalHotKey(backend: backend)
    }()

    enum RegistrationFailure: Error, Equatable {
        case eventHandler(OSStatus)
        case shortcut(OSStatus)
    }

    enum HotKeyID: UInt32 { case toggle = 1, settings = 2 }

    /// Injectable Carbon boundary lets failure/retry checks run without registering
    /// a real shortcut or installing an event handler in the user's session.
    struct Backend {
        var installHandler: () -> OSStatus
        var register: (_ keyCode: UInt32, _ modifiers: UInt32, _ id: UInt32) -> (OSStatus, EventHotKeyRef?)
        var unregister: (EventHotKeyRef) -> Void

        static var live: Backend {
            Backend(installHandler: {
                var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                         eventKind: UInt32(kEventHotKeyPressed))
                let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
                    var hotKeyID = EventHotKeyID()
                    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                                   EventParamType(typeEventHotKeyID), nil,
                                                   MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                    guard status == noErr, hotKeyID.signature == GlobalHotKey.signature else { return noErr }
                    let rawID = hotKeyID.id
                    Task { @MainActor in GlobalHotKey.shared.dispatch(rawID: rawID) }
                    return noErr
                }, 1, &type, nil, nil)
                logger.notice("Carbon handler status=\(status) executable=\(Bundle.main.executablePath ?? "unknown", privacy: .public)")
                return status
            }, register: { keyCode, modifiers, rawID in
                var reference: EventHotKeyRef?
                let id = EventHotKeyID(signature: GlobalHotKey.signature, id: rawID)
                let status = RegisterEventHotKey(keyCode, modifiers,
                                                // Shared registration: other processes may also succeed.
                                                id, GetApplicationEventTarget(), 0, &reference)
                logger.notice("Carbon shortcut status=\(status) hasReference=\(reference != nil) executable=\(Bundle.main.executablePath ?? "unknown", privacy: .public)")
                return (status, reference)
            }, unregister: { UnregisterEventHotKey($0) })
        }

        #if DEBUG
        /// Synthetic failure enters the real fallback UI, without reserving a live shortcut.
        /// Removing the marker lets the next retry use the actual Carbon backend.
        func simulatingConflict(whileFileExists marker: URL) -> Backend {
            var backend = self
            backend.register = { keyCode, modifiers, id in
                if FileManager.default.fileExists(atPath: marker.path) {
                    logger.notice("SIMULATED shortcut conflict; Carbon registration skipped")
                    return (OSStatus(eventHotKeyExistsErr), nil)
                }
                return self.register(keyCode, modifiers, id)
            }
            return backend
        }
        #endif
    }

    nonisolated static let signature = OSType(0x4C554853) // "LUHS"

    private struct Registration {
        let reference: EventHotKeyRef
        let action: () -> Void
    }

    private let backend: Backend
    private var handlerInstalled = false
    private var registrations: [UInt32: Registration] = [:]

    init(backend: Backend) { self.backend = backend }

    /// Registers `id`, replacing any previous registration of the same id first.
    /// A failure leaves no reference or callback for `id`.
    @discardableResult
    func register(id: HotKeyID, keyCode: UInt32, modifiers: UInt32,
                  _ action: @escaping () -> Void) -> Result<Void, RegistrationFailure> {
        unregister(id: id)
        if !handlerInstalled {
            let status = backend.installHandler()
            guard status == noErr else { return .failure(.eventHandler(status)) }
            handlerInstalled = true
        }
        let (status, reference) = backend.register(keyCode, modifiers, id.rawValue)
        guard status == noErr, let reference else {
            // Do not keep a partially returned registration after a failed call.
            if let reference { backend.unregister(reference) }
            return .failure(.shortcut(status == noErr ? OSStatus(paramErr) : status))
        }
        registrations[id.rawValue] = Registration(reference: reference, action: action)
        return .success(())
    }

    func unregister(id: HotKeyID) {
        if let registration = registrations.removeValue(forKey: id.rawValue) {
            backend.unregister(registration.reference)
        }
    }

    func unregisterAll() {
        for registration in registrations.values { backend.unregister(registration.reference) }
        registrations.removeAll()
    }

    /// Events for an id with no live registration are dropped.
    func dispatch(id: HotKeyID) { dispatch(rawID: id.rawValue) }

    func dispatch(rawID: UInt32) { registrations[rawID]?.action() }
}
