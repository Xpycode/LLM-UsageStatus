import XCTest
@testable import LLMUsageStatus

final class UsageStoreTests: XCTestCase {
    @MainActor
    func testInitialFailureShowsSafeErrorWithoutInventingDataOrTimestamp() async throws {
        let store = UsageStore(providerID: "test", displayName: "Test") { .unavailable }

        XCTAssertNil(store.section)
        XCTAssertNil(store.error)
        XCTAssertNil(store.lastUpdated)
        XCTAssertFalse(store.loading)
        XCTAssertFalse(store.isStale)
        XCTAssertFalse(store.isNotDetected)

        let refresh = try XCTUnwrap(store.refresh())
        XCTAssertTrue(store.loading)
        await refresh.value

        XCTAssertFalse(store.loading)
        XCTAssertNil(store.section)
        XCTAssertNil(store.lastUpdated)
        XCTAssertFalse(store.isStale)
        XCTAssertFalse(store.isNotDetected)
        XCTAssertEqual(store.error, .loadFailed)
        XCTAssertFalse(store.error?.text.contains("synthetic-secret") ?? true)
        XCTAssertFalse(store.error?.text.contains("synthetic-account") ?? true)
    }

    @MainActor
    func testFailureRetainsSuccessfulDataAndTimestampUntilRecovery() async throws {
        let original = Self.section(at: 1_000)
        let recovered = Self.section(at: 2_000)
        let sequence = FetchSequence([.populated(original), .unavailable, .populated(recovered)])
        let store = UsageStore(providerID: "test", displayName: "Test") { await sequence.fetch() }

        let first = try XCTUnwrap(store.refresh())
        await first.value
        XCTAssertEqual(store.section, original)
        XCTAssertEqual(store.lastUpdated, original.lastUpdated)
        XCTAssertNil(store.error)
        XCTAssertFalse(store.isStale)
        XCTAssertFalse(store.loading)

        let failed = try XCTUnwrap(store.refresh())
        XCTAssertTrue(store.loading)
        XCTAssertEqual(store.section, original)
        XCTAssertEqual(store.lastUpdated, original.lastUpdated)
        await failed.value
        XCTAssertFalse(store.loading)
        XCTAssertEqual(store.section, original)
        XCTAssertEqual(store.lastUpdated, original.lastUpdated)
        XCTAssertTrue(store.isStale)
        XCTAssertEqual(store.error, .updateFailed)

        let retry = try XCTUnwrap(store.refresh())
        XCTAssertTrue(store.loading)
        XCTAssertTrue(store.isStale)
        XCTAssertNotNil(store.error)
        XCTAssertEqual(store.section, original)
        XCTAssertEqual(store.lastUpdated, original.lastUpdated)
        await retry.value
        XCTAssertFalse(store.loading)
        XCTAssertFalse(store.isStale)
        XCTAssertNil(store.error)
        XCTAssertEqual(store.section, recovered)
        XCTAssertEqual(store.lastUpdated, recovered.lastUpdated)
    }

    @MainActor
    func testDuplicateRefreshDoesNotStartAnotherFetchOrEndLoadingEarly() async throws {
        let gate = FetchGate()
        let store = UsageStore(providerID: "test", displayName: "Test") { await gate.fetch() }
        let expected = Self.section(at: 3_000)

        let refresh = try XCTUnwrap(store.refresh())
        XCTAssertTrue(store.loading)
        XCTAssertNil(store.refresh())
        await gate.waitUntilStarted()
        XCTAssertNil(store.refresh())
        XCTAssertTrue(store.loading)
        XCTAssertNil(store.section)
        let calls = await gate.calls
        XCTAssertEqual(calls, 1)

        await gate.finish(with: .populated(expected))
        await refresh.value
        XCTAssertFalse(store.loading)
        XCTAssertEqual(store.section, expected)
        XCTAssertEqual(store.lastUpdated, expected.lastUpdated)
        XCTAssertNil(store.error)
    }

    @MainActor
    func testInitialNotDetectedPublishesNoErrorOrInventedData() async throws {
        let store = UsageStore(providerID: "test", displayName: "Test") { .notDetected }

        let refresh = try XCTUnwrap(store.refresh())
        await refresh.value

        XCTAssertTrue(store.isNotDetected)
        XCTAssertNil(store.section)
        XCTAssertNil(store.lastUpdated)
        XCTAssertNil(store.error)
        XCTAssertFalse(store.isStale)
        XCTAssertFalse(store.loading)
    }

    @MainActor
    func testNotDetectedRetainsPriorValuesAndRecoveryClearsFlag() async throws {
        let original = Self.section(at: 4_000)
        let recovered = Self.section(at: 5_000)
        let sequence = FetchSequence([.populated(original), .notDetected, .populated(recovered)])
        let store = UsageStore(providerID: "test", displayName: "Test") { await sequence.fetch() }

        let first = try XCTUnwrap(store.refresh())
        await first.value
        XCTAssertFalse(store.isNotDetected)

        let second = try XCTUnwrap(store.refresh())
        await second.value
        XCTAssertTrue(store.isNotDetected)
        XCTAssertNil(store.error)
        XCTAssertTrue(store.isStale)
        XCTAssertEqual(store.section, original)
        XCTAssertEqual(store.lastUpdated, original.lastUpdated)

        let third = try XCTUnwrap(store.refresh())
        await third.value
        XCTAssertFalse(store.isNotDetected)
        XCTAssertFalse(store.isStale)
        XCTAssertNil(store.error)
        XCTAssertEqual(store.section, recovered)
        XCTAssertEqual(store.lastUpdated, recovered.lastUpdated)
    }

    @MainActor
    func testProviderInitCarriesIdentityAndRefreshState() async throws {
        let store = UsageStore(provider: TestProvider())
        XCTAssertEqual(store.providerID, "test")
        XCTAssertEqual(store.displayName, "Test")
        XCTAssertNil(store.section)

        let refresh = try XCTUnwrap(store.refresh())
        await refresh.value
        XCTAssertEqual(store.section, Self.expectedProviderSection)
        XCTAssertFalse(store.isNotDetected)
        XCTAssertFalse(store.isStale)
        XCTAssertNil(store.error)
    }

    private static func section(at timestamp: TimeInterval) -> ProviderSection {
        let date = Date(timeIntervalSince1970: timestamp)
        return ProviderSection(
            rows: [SectionRow(id: "credits", label: "Credits", value: "12.75")],
            meters: [SectionMeter(id: "weekly", label: "Weekly limit", fraction: 0.2)!],
            deadlines: [SectionDeadline(id: "weekly-reset", label: "Weekly limit resets",
                                         date: date.addingTimeInterval(604_800))],
            lastUpdated: date
        )
    }

    private static var expectedProviderSection: ProviderSection {
        ProviderSection(rows: [SectionRow(id: "tokens", label: "Tokens", value: "1,234")],
                         lastUpdated: Date(timeIntervalSince1970: 6_000))
    }
}

private struct TestProvider: Provider {
    let id = "test"
    let displayName = "Test"

    func refresh() async -> ProviderSectionState {
        .populated(ProviderSection(rows: [SectionRow(id: "tokens", label: "Tokens", value: "1,234")],
                                   lastUpdated: Date(timeIntervalSince1970: 6_000)))
    }
}

private actor FetchSequence {
    private var results: [ProviderSectionState]

    init(_ results: [ProviderSectionState]) {
        self.results = results
    }

    func fetch() -> ProviderSectionState {
        results.isEmpty ? .unavailable : results.removeFirst()
    }
}

private actor FetchGate {
    private(set) var calls = 0
    private var continuation: CheckedContinuation<ProviderSectionState, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func fetch() async -> ProviderSectionState {
        calls += 1
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        guard continuation == nil else { return }
        await withCheckedContinuation { started = $0 }
    }

    func finish(with state: ProviderSectionState) {
        continuation?.resume(returning: state)
        continuation = nil
    }
}
