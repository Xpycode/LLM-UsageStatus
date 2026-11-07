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

    @MainActor
    func testTwoIdsRegisterWithTheirOwnKeysAndDispatchIndependently() async {
        let calls = Calls()
        let hotKey = GlobalHotKey(backend: calls.backend)
        var fired: [String] = []
        assertSuccess(hotKey.register(id: .toggle, keyCode: 37, modifiers: 256) { fired.append("toggle") })
        assertSuccess(hotKey.register(id: .settings, keyCode: 43, modifiers: 2048) { fired.append("settings") })
        XCTAssertEqual(calls.installations, 1)
        XCTAssertEqual(calls.registered, [.init(keyCode: 37, modifiers: 256, id: 1),
                                          .init(keyCode: 43, modifiers: 2048, id: 2)])
        hotKey.dispatch(id: .settings)
        hotKey.dispatch(id: .toggle)
        XCTAssertEqual(fired, ["settings", "toggle"])
        hotKey.unregisterAll()
    }

    @MainActor
    func testPerIdUnregisterLeavesOtherIdLive() async {
        let calls = Calls()
        let hotKey = GlobalHotKey(backend: calls.backend)
        var fired: [String] = []
        hotKey.register(id: .toggle, keyCode: 37, modifiers: 256) { fired.append("toggle") }
        hotKey.register(id: .settings, keyCode: 43, modifiers: 256) { fired.append("settings") }
        hotKey.unregister(id: .toggle)
        XCTAssertEqual(calls.unregisteredRefs, [1])
        hotKey.dispatch(id: .toggle)
        hotKey.dispatch(id: .settings)
        XCTAssertEqual(fired, ["settings"])
        hotKey.unregister(id: .toggle)
        XCTAssertEqual(calls.unregistrations, 1)
        hotKey.unregisterAll()
    }

    @MainActor
    func testReRegisterUnregistersOldReferenceBeforeRegisteringNew() async {
        let calls = Calls()
        let hotKey = GlobalHotKey(backend: calls.backend)
        var fired: [String] = []
        hotKey.register(id: .toggle, keyCode: 37, modifiers: 256) { fired.append("old") }
        hotKey.register(id: .toggle, keyCode: 40, modifiers: 512) { fired.append("new") }
        XCTAssertEqual(calls.events, ["install", "register", "unregister", "register"])
        XCTAssertEqual(calls.unregisteredRefs, [1])
        hotKey.dispatch(id: .toggle)
        XCTAssertEqual(fired, ["new"])
        hotKey.unregisterAll()
        XCTAssertEqual(calls.unregisteredRefs, [1, 2])
    }

    @MainActor
    func testFailedRegisterLeavesNoReferenceOrCallback() async {
        let calls = Calls()
        let hotKey = GlobalHotKey(backend: calls.backend)
        var fired = 0
        hotKey.register(id: .settings, keyCode: 43, modifiers: 256) { fired += 1 }
        calls.registrationStatus = -9878
        assertFailure(hotKey.register(id: .settings, keyCode: 44, modifiers: 256) { fired += 10 }, .shortcut(-9878))
        hotKey.dispatch(id: .settings)
        XCTAssertEqual(fired, 0)
        hotKey.unregisterAll()
        XCTAssertEqual(calls.unregistrations, 1)
    }

    @MainActor
    func testDispatchForUnregisteredOrStaleIdIsIgnored() async {
        let calls = Calls()
        let hotKey = GlobalHotKey(backend: calls.backend)
        var fired = 0
        hotKey.dispatch(id: .toggle)
        hotKey.dispatch(rawID: 99)
        hotKey.register(id: .toggle, keyCode: 37, modifiers: 256) { fired += 1 }
        hotKey.unregister(id: .toggle)
        hotKey.dispatch(id: .toggle)
        hotKey.dispatch(rawID: 99)
        XCTAssertEqual(fired, 0)
    }

    @MainActor
    func testUnregisterAllReleasesEveryReference() async {
        let calls = Calls()
        let hotKey = GlobalHotKey(backend: calls.backend)
        var fired = 0
        hotKey.register(id: .toggle, keyCode: 37, modifiers: 256) { fired += 1 }
        hotKey.register(id: .settings, keyCode: 43, modifiers: 256) { fired += 1 }
        hotKey.unregisterAll()
        XCTAssertEqual(calls.unregistrations, 2)
        hotKey.dispatch(id: .toggle)
        hotKey.dispatch(id: .settings)
        XCTAssertEqual(fired, 0)
        hotKey.unregisterAll()
        XCTAssertEqual(calls.unregistrations, 2)
    }

    @MainActor
    func testLegacyOverloadRegistersToggleWithOldDefault() async {
        let calls = Calls()
        let hotKey = GlobalHotKey(backend: calls.backend)
        var fired = 0
        assertSuccess(hotKey.register { fired += 1 })
        XCTAssertEqual(calls.registered, [.init(keyCode: UInt32(kVK_ANSI_L),
                                                modifiers: UInt32(cmdKey | optionKey | controlKey), id: 1)])
        hotKey.dispatch(id: .toggle)
        XCTAssertEqual(fired, 1)
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
        struct Request: Equatable { let keyCode: UInt32, modifiers: UInt32, id: UInt32 }
        var registered: [Request] = []
        var nextRef = 0
        var unregisteredRefs: [UInt] = []

        var backend: GlobalHotKey.Backend {
            .init(installHandler: {
                self.installations += 1
                self.events.append("install")
                return self.handlerStatus
            }, register: { keyCode, modifiers, id in
                self.registrations += 1
                self.events.append("register")
                self.registered.append(Request(keyCode: keyCode, modifiers: modifiers, id: id))
                let hasReference = self.returnReference && (self.registrationStatus == noErr || self.referenceOnFailure)
                self.nextRef += 1
                return (self.registrationStatus, hasReference ? OpaquePointer(bitPattern: self.nextRef) : nil)
            }, unregister: { ref in
                self.unregistrations += 1
                self.events.append("unregister")
                self.unregisteredRefs.append(UInt(bitPattern: ref))
            })
        }
    }
}
