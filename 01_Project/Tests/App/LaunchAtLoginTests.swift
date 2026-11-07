import ServiceManagement
import XCTest
@testable import LLMUsageStatus

final class LaunchAtLoginTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/Users/tester")
    private let goodBundle = URL(fileURLWithPath: "/Applications/App.app")

    private final class Fake: @unchecked Sendable {
        private let lock = NSLock()
        private var _status: SMAppService.Status
        private var _registers = 0, _unregisters = 0
        var writable = true
        var registerError: Error?
        var unregisterError: Error?
        var statusDelay: TimeInterval = 0
        /// Status applied after a failing call, to model the real state changing underneath.
        var statusAfterFailure: SMAppService.Status?

        init(_ status: SMAppService.Status) { _status = status }

        var registers: Int { lock.withLock { _registers } }
        var unregisters: Int { lock.withLock { _unregisters } }

        func backend(home: URL, timeout: TimeInterval = 1) -> LaunchAtLogin.Backend {
            LaunchAtLogin.Backend(
                status: { [self] in
                    if statusDelay > 0 { Thread.sleep(forTimeInterval: statusDelay) }
                    return lock.withLock { _status }
                },
                register: { [self] in
                    lock.withLock { _registers += 1 }
                    if let registerError {
                        if let s = statusAfterFailure { lock.withLock { _status = s } }
                        throw registerError
                    }
                    lock.withLock { _status = .enabled }
                },
                unregister: { [self] in
                    lock.withLock { _unregisters += 1 }
                    if let unregisterError {
                        if let s = statusAfterFailure { lock.withLock { _status = s } }
                        throw unregisterError
                    }
                    lock.withLock { _status = .notRegistered }
                },
                isWritableVolume: { [self] _ in writable },
                homeDirectory: home,
                timeout: timeout)
        }
    }

    private struct Boom: Error, LocalizedError { var errorDescription: String? { "boom" } }

    private func service(_ fake: Fake, at path: String? = nil, timeout: TimeInterval = 1) -> LaunchAtLogin {
        LaunchAtLogin(backend: fake.backend(home: home, timeout: timeout),
                      bundleURL: path.map { URL(fileURLWithPath: $0) } ?? goodBundle)
    }

    private func isUnavailable(_ state: LaunchAtLoginState) -> Bool {
        if case .unavailable = state { return true }
        return false
    }

    // MARK: Status mapping

    func testStatusMapping() async {
        let cases: [(SMAppService.Status, LaunchAtLoginState)] = [
            (.enabled, .enabled), (.notRegistered, .disabled),
            (.requiresApproval, .requiresApproval), (.notFound, .disabled),
        ]
        for (status, expected) in cases {
            let state = await service(Fake(status)).state()
            XCTAssertEqual(state, expected)
        }
    }

    // MARK: Location guard

    func testRejectedLocations() async {
        let paths = [
            "/Users/tester/Library/Developer/Xcode/DerivedData/App-abc/Build/Products/Debug/App.app",
            "/Users/tester/Downloads/App.app",
            "/Volumes/X/App.app",
            "/private/var/folders/ab/cd/T/AppTranslocation/UUID/d/App.app",
            "/Applications/App",
            "/Applications/../tmp/App.app",
        ]
        for path in paths {
            let fake = Fake(.notRegistered)
            let launch = service(fake, at: path)
            let state = await launch.state()
            XCTAssertTrue(isUnavailable(state), path)
            let result = await launch.setEnabled(true)
            guard case .failure(.unavailable) = result else { XCTFail(path); continue }
            XCTAssertEqual(fake.registers, 0, path)
        }
    }

    func testAcceptedLocations() async {
        for path in ["/Applications/X/App.app", "/Applications/App.app", "/Users/tester/Applications/App.app"] {
            let state = await service(Fake(.notRegistered), at: path).state()
            XCTAssertEqual(state, .disabled, path)
        }
    }

    func testReadOnlyVolumeRejected() async {
        let fake = Fake(.notRegistered)
        fake.writable = false
        let state = await service(fake).state()
        XCTAssertTrue(isUnavailable(state))
    }

    // MARK: Idempotency

    func testEnableWhenAlreadyEnabledDoesNotRegister() async {
        let fake = Fake(.enabled)
        let result = await service(fake).setEnabled(true)
        XCTAssertEqual(result, .success(.enabled))
        XCTAssertEqual(fake.registers, 0)
    }

    func testDisableWhenNotEnabledDoesNotUnregister() async {
        for status in [SMAppService.Status.notRegistered, .notFound] {
            let fake = Fake(status)
            _ = await service(fake).setEnabled(false)
            XCTAssertEqual(fake.unregisters, 0)
        }
    }

    func testPendingApprovalCountsAsRegistered() async {
        let enabling = Fake(.requiresApproval)
        let enableResult = await service(enabling).setEnabled(true)
        XCTAssertEqual(enableResult, .success(.requiresApproval))
        XCTAssertEqual(enabling.registers, 0)

        let disabling = Fake(.requiresApproval)
        let disableResult = await service(disabling).setEnabled(false)
        XCTAssertEqual(disableResult, .success(.disabled))
        XCTAssertEqual(disabling.unregisters, 1)
    }

    func testEnableAndDisableCallBackendOnce() async {
        let fake = Fake(.notRegistered)
        let launch = service(fake)
        let enabled = await launch.setEnabled(true)
        XCTAssertEqual(enabled, .success(.enabled))
        XCTAssertEqual(fake.registers, 1)
        let disabled = await launch.setEnabled(false)
        XCTAssertEqual(disabled, .success(.disabled))
        XCTAssertEqual(fake.unregisters, 1)
    }

    func testNotFoundStillAllowsRegistering() async {
        let fake = Fake(.notFound)
        let result = await service(fake).setEnabled(true)
        XCTAssertEqual(result, .success(.enabled))
        XCTAssertEqual(fake.registers, 1)
    }

    // MARK: Errors

    func testRegisterErrorCarriesRereadState() async {
        let fake = Fake(.notRegistered)
        fake.registerError = Boom()
        fake.statusAfterFailure = .requiresApproval
        let result = await service(fake).setEnabled(true)
        XCTAssertEqual(result, .failure(.failed(message: "boom", state: .requiresApproval)))
    }

    func testUnregisterErrorCarriesRereadState() async {
        let fake = Fake(.enabled)
        fake.unregisterError = Boom()
        let result = await service(fake).setEnabled(false)
        XCTAssertEqual(result, .failure(.failed(message: "boom", state: .enabled)))
        XCTAssertEqual(fake.unregisters, 1)
    }

    // MARK: Timeout

    func testHungStatusYieldsUnknown() async {
        let fake = Fake(.enabled)
        fake.statusDelay = 0.6
        let state = await service(fake, timeout: 0.1).state()
        XCTAssertEqual(state, .unknown)
    }

    func testUnknownStateBlocksChange() async {
        let fake = Fake(.notRegistered)
        fake.statusDelay = 0.6
        let result = await service(fake, timeout: 0.1).setEnabled(true)
        XCTAssertEqual(result, .failure(.timedOut(state: .unknown)))
        XCTAssertEqual(fake.registers, 0)
    }

    // MARK: Refresh

    func testRefreshRegistersOnlyWhenEnabled() async {
        let enabled = Fake(.enabled)
        await service(enabled).refreshRegistrationIfEnabled()
        XCTAssertEqual(enabled.registers, 1)
        for status in [SMAppService.Status.notRegistered, .requiresApproval, .notFound] {
            let fake = Fake(status)
            await service(fake).refreshRegistrationIfEnabled()
            XCTAssertEqual(fake.registers, 0)
        }
        let misplaced = Fake(.enabled)
        await service(misplaced, at: "/Users/tester/Downloads/App.app").refreshRegistrationIfEnabled()
        XCTAssertEqual(misplaced.registers, 0)
    }
}
