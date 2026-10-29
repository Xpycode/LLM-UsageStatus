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
    private var callback: (() -> Void)?

    enum RegistrationFailure: Error, Equatable {
        case eventHandler(OSStatus)
        case shortcut(OSStatus)
    }

    /// Injectable Carbon boundary lets failure/retry checks run without registering
    /// a real shortcut or installing an event handler in the user's session.
    struct Backend {
        var installHandler: () -> OSStatus
        var register: () -> (OSStatus, EventHotKeyRef?)
        var unregister: (EventHotKeyRef) -> Void

        static var live: Backend {
            Backend(installHandler: {
                var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                         eventKind: UInt32(kEventHotKeyPressed))
                let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                    Task { @MainActor in GlobalHotKey.shared.callback?() }
                    return noErr
                }, 1, &type, nil, nil)
                logger.notice("Carbon handler status=\(status) executable=\(Bundle.main.executablePath ?? "unknown", privacy: .public)")
                return status
            }, register: {
                var reference: EventHotKeyRef?
                let id = EventHotKeyID(signature: OSType(0x4C554853), id: 1) // "LUHS"
                let status = RegisterEventHotKey(UInt32(kVK_ANSI_L),
                                                UInt32(cmdKey | optionKey | controlKey),
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
            backend.register = {
                if FileManager.default.fileExists(atPath: marker.path) {
                    logger.notice("SIMULATED shortcut conflict; Carbon registration skipped")
                    return (OSStatus(eventHotKeyExistsErr), nil)
                }
                return self.register()
            }
            return backend
        }
        #endif
    }

    private let backend: Backend
    private var handlerInstalled = false
    private var reference: EventHotKeyRef?

    init(backend: Backend) { self.backend = backend }

    @discardableResult
    func register(_ action: @escaping () -> Void) -> Result<Void, RegistrationFailure> {
        unregister()
        if !handlerInstalled {
            let status = backend.installHandler()
            guard status == noErr else { return .failure(.eventHandler(status)) }
            handlerInstalled = true
        }
        let (status, reference) = backend.register()
        guard status == noErr, let reference else {
            // Do not keep a partially returned registration after a failed call.
            if let reference { backend.unregister(reference) }
            return .failure(.shortcut(status == noErr ? OSStatus(paramErr) : status))
        }
        self.reference = reference
        callback = action
        return .success(())
    }

    func unregister() {
        if let reference { backend.unregister(reference) }
        reference = nil
        callback = nil
    }
}
