import Foundation
import OSLog
import ServiceManagement

enum LaunchAtLoginState: Equatable, Sendable {
    case enabled, disabled, requiresApproval, unknown
    case unavailable(reason: String)
}

/// Every case carries the state re-read after the failure so callers can show the real status.
enum LaunchAtLoginError: Error, Equatable, Sendable {
    case unavailable(reason: String)
    case failed(message: String, state: LaunchAtLoginState)
    case timedOut(state: LaunchAtLoginState)

    var state: LaunchAtLoginState {
        switch self {
        case .unavailable(let reason): .unavailable(reason: reason)
        case .failed(_, let state), .timedOut(let state): state
        }
    }
}

actor LaunchAtLogin {
    struct Backend: Sendable {
        var status: @Sendable () -> SMAppService.Status
        var register: @Sendable () throws -> Void
        var unregister: @Sendable () throws -> Void
        var isWritableVolume: @Sendable (URL) -> Bool
        var homeDirectory: URL
        var timeout: TimeInterval

        static let live = Backend(
            status: { SMAppService.mainApp.status },
            register: { try SMAppService.mainApp.register() },
            unregister: { try SMAppService.mainApp.unregister() },
            isWritableVolume: { url in
                do {
                    let values = try url.resourceValues(forKeys: [.volumeIsReadOnlyKey])
                    guard let readOnly = values.volumeIsReadOnly else { return false }
                    return !readOnly
                } catch {
                    return false
                }
            },
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
            timeout: 3
        )
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LLMUsageStatus", category: "LaunchAtLogin")

    private let backend: Backend
    private let bundleURL: URL

    init(backend: Backend = .live, bundleURL: URL = Bundle.main.bundleURL) {
        self.backend = backend
        self.bundleURL = bundleURL
    }

    func state() async -> LaunchAtLoginState {
        if let reason = locationProblem() { return .unavailable(reason: reason) }
        return await readStatus()
    }

    func setEnabled(_ enabled: Bool) async -> Result<LaunchAtLoginState, LaunchAtLoginError> {
        if let reason = locationProblem() { return .failure(.unavailable(reason: reason)) }
        let current = await readStatus()
        if current == .unknown { return .failure(.timedOut(state: .unknown)) }
        // A pending approval is still a registration: enabling again is a no-op, disabling removes it.
        let registered = current == .enabled || current == .requiresApproval
        if enabled == registered { return .success(current) }

        let backend = backend
        let failure: String?? = await Self.race(timeout: backend.timeout) {
            do {
                if enabled { try backend.register() } else { try backend.unregister() }
                return nil
            } catch {
                return error.localizedDescription
            }
        }
        let reread = await readStatus()
        guard let outcome = failure else {
            Self.logger.error("Launch-at-login change timed out for \(self.bundleURL.path, privacy: .public)")
            return .failure(.timedOut(state: reread))
        }
        if let message = outcome {
            Self.logger.error("Launch-at-login change failed for \(self.bundleURL.path, privacy: .public): \(message, privacy: .public)")
            return .failure(.failed(message: message, state: reread))
        }
        return .success(reread)
    }

    func refreshRegistrationIfEnabled() async {
        guard await state() == .enabled else { return }
        let backend = backend
        let failure: String?? = await Self.race(timeout: backend.timeout) {
            do {
                try backend.register()
                return nil
            } catch {
                return error.localizedDescription
            }
        }
        if let outcome = failure, let message = outcome {
            Self.logger.error("Launch-at-login refresh failed for \(self.bundleURL.path, privacy: .public): \(message, privacy: .public)")
        } else if failure == nil {
            Self.logger.error("Launch-at-login refresh timed out for \(self.bundleURL.path, privacy: .public)")
        }
    }

    nonisolated static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: - Private

    private func readStatus() async -> LaunchAtLoginState {
        let backend = backend
        guard let status = await Self.race(timeout: backend.timeout, { backend.status() }) else {
            Self.logger.error("Launch-at-login status timed out for \(self.bundleURL.path, privacy: .public)")
            return .unknown
        }
        switch status {
        case .enabled: return .enabled
        case .notRegistered, .notFound: return .disabled
        case .requiresApproval: return .requiresApproval
        @unknown default: return .unknown
        }
    }

    /// Returns a reason when the bundle location cannot support login-item registration.
    private func locationProblem() -> String? {
        let url = bundleURL.standardizedFileURL
        let path = url.path
        if path.hasPrefix("/private/var/folders/"), path.contains("/AppTranslocation/") {
            return "Move the app out of quarantine (into Applications) to enable launch at login."
        }
        guard url.pathExtension == "app" else {
            return "Launch at login needs the packaged app."
        }
        let userApplications = backend.homeDirectory.standardizedFileURL.appendingPathComponent("Applications").path
        guard path.hasPrefix("/Applications/") || path.hasPrefix(userApplications + "/") else {
            return "Move the app to the Applications folder to enable launch at login."
        }
        guard backend.isWritableVolume(url) else {
            return "The app is on a read-only volume; copy it to the Applications folder."
        }
        return nil
    }

    /// Runs blocking work on a dispatch thread and gives up after `timeout`. A hung closure
    /// strands only its own thread, never the caller or the cooperative pool.
    private static func race<T: Sendable>(
        timeout: TimeInterval, _ work: @escaping @Sendable () -> T
    ) async -> T? {
        await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            let gate = ResumeOnce(continuation)
            DispatchQueue.global(qos: .userInitiated).async { gate.resume(work()) }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) { gate.resume(nil) }
        }
    }
}

private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T?, Never>?

    init(_ continuation: CheckedContinuation<T?, Never>) { self.continuation = continuation }

    func resume(_ value: T?) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
