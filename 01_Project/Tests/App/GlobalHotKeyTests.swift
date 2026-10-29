import Carbon.HIToolbox
import XCTest
@testable import LLMUsageStatus

final class GlobalHotKeyTests: XCTestCase {
    #if DEBUG
    @MainActor
    func testMarkerKeepsConflictUntilRemovedThenRetriesUnderlyingBackend() async throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: marker)
        defer { try? FileManager.default.removeItem(at: marker) }
        let calls = Calls()
        let hotKey = GlobalHotKey(backend: calls.backend.simulatingConflict(whileFileExists: marker))
        assertFailure(hotKey.register {}, .shortcut(OSStatus(eventHotKeyExistsErr)))
        assertFailure(hotKey.register {}, .shortcut(OSStatus(eventHotKeyExistsErr)))
        XCTAssertEqual(calls.installations, 1)
        XCTAssertEqual(calls.registrations, 0)
        try FileManager.default.removeItem(at: marker)
        assertSuccess(hotKey.register {})
        XCTAssertEqual(calls.registrations, 1)
        hotKey.unregister()
        XCTAssertEqual(calls.unregistrations, 1)
    }
    #endif

    @MainActor
    func testHandlerFailureStopsBeforeRegistrationAndCanRetry() async {
        let calls = Calls()
        calls.handlerStatus = -50
        let hotKey = GlobalHotKey(backend: calls.backend)
        assertFailure(hotKey.register {}, .eventHandler(-50))
        XCTAssertEqual(calls.registrations, 0)
        calls.handlerStatus = noErr
        assertSuccess(hotKey.register {})
        XCTAssertEqual(calls.installations, 2)
        XCTAssertEqual(calls.registrations, 1)
        hotKey.unregister()
        XCTAssertEqual(calls.unregistrations, 1)
    }

    @MainActor
    func testShortcutConflictCanRetryWithoutInstallingAnotherHandler() async {
        let calls = Calls()
        calls.registrationStatus = -9878
        let hotKey = GlobalHotKey(backend: calls.backend)
        assertFailure(hotKey.register {}, .shortcut(-9878))
        calls.registrationStatus = noErr
        assertSuccess(hotKey.register {})
        XCTAssertEqual(calls.installations, 1)
        XCTAssertEqual(calls.registrations, 2)
        hotKey.unregister()
    }

    @MainActor
    func testReplacementReleasesOldRegistrationBeforeRetry() async {
        let calls = Calls()
        let hotKey = GlobalHotKey(backend: calls.backend)
        assertSuccess(hotKey.register {})
        calls.registrationStatus = -9878
        assertFailure(hotKey.register {}, .shortcut(-9878))
        XCTAssertEqual(calls.events, ["install", "register", "unregister", "register"])
        hotKey.unregister()
        XCTAssertEqual(calls.unregistrations, 1)
    }

    @MainActor
    func testSuccessWithoutReferenceIsFailure() async {
        let calls = Calls()
        calls.returnReference = false
        let hotKey = GlobalHotKey(backend: calls.backend)
        assertFailure(hotKey.register {}, .shortcut(OSStatus(paramErr)))
        hotKey.unregister()
        XCTAssertEqual(calls.unregistrations, 0)
    }

    @MainActor
    func testPartiallyReturnedReferenceIsReleasedOnFailure() async {
        let calls = Calls()
        calls.registrationStatus = -50
        calls.referenceOnFailure = true
        let hotKey = GlobalHotKey(backend: calls.backend)
        assertFailure(hotKey.register {}, .shortcut(-50))
        hotKey.unregister()
        XCTAssertEqual(calls.unregistrations, 1)
    }

    @MainActor private func assertFailure(_ result: Result<Void, GlobalHotKey.RegistrationFailure>,
                                           _ expected: GlobalHotKey.RegistrationFailure,
                                           file: StaticString = #filePath, line: UInt = #line) {
        guard case .failure(let error) = result else {
            return XCTFail("Expected registration failure", file: file, line: line)
        }
        XCTAssertEqual(error, expected, file: file, line: line)
    }

    @MainActor private func assertSuccess(_ result: Result<Void, GlobalHotKey.RegistrationFailure>,
                                           file: StaticString = #filePath, line: UInt = #line) {
        if case .failure(let error) = result { XCTFail("Unexpected failure: \(error)", file: file, line: line) }
    }

    /// No live Carbon functions, UI, network, defaults or credentials are accessed.
    @MainActor private final class Calls {
        var handlerStatus: OSStatus = noErr
        var registrationStatus: OSStatus = noErr
        var returnReference = true
        var referenceOnFailure = false
        var installations = 0
        var registrations = 0
        var unregistrations = 0
        var events: [String] = []

        var backend: GlobalHotKey.Backend {
            .init(installHandler: {
                self.installations += 1
                self.events.append("install")
                return self.handlerStatus
            }, register: {
                self.registrations += 1
                self.events.append("register")
                let hasReference = self.returnReference && (self.registrationStatus == noErr || self.referenceOnFailure)
                return (self.registrationStatus, hasReference ? OpaquePointer(bitPattern: 1) : nil)
            }, unregister: { _ in
                self.unregistrations += 1
                self.events.append("unregister")
            })
        }
    }
}
