import Combine
import Foundation

/// Owns one provider's section state: the last populated values, loading
/// progress, and pre-approved failure copy. One store serves one provider;
/// composing stores into the multi-section panel happens at a higher level.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var section: ProviderSection?
    @Published private(set) var loading = false
    @Published private(set) var error: SectionFailureMessage?
    @Published private(set) var lastUpdated: Date?
    /// A failed or not-detected refresh makes retained data stale until a fetch succeeds.
    @Published private(set) var isStale = false
    /// The provider's CLI or sign-in was absent at the latest refresh.
    @Published private(set) var isNotDetected = false

    /// Immutable identity for composition and section headers.
    let providerID: String
    let displayName: String

    private let fetch: @Sendable () async -> ProviderSectionState

    init(provider: any Provider) {
        self.providerID = provider.id
        self.displayName = provider.displayName
        self.fetch = { await provider.refresh() }
    }

    init(providerID: String, displayName: String, fetch: @escaping @Sendable () async -> ProviderSectionState) {
        self.providerID = providerID
        self.displayName = displayName
        self.fetch = fetch
    }

    /// Returns nil when a refresh is already in flight. The returned task can be
    /// awaited by callers that need completion; ordinary UI actions can ignore it.
    @discardableResult
    func refresh() -> Task<Void, Never>? {
        guard !loading else { return nil }
        loading = true

        return Task {
            defer { loading = false }

            switch await fetch() {
            case .populated(let updated):
                section = updated
                lastUpdated = updated.lastUpdated
                error = nil
                isStale = false
                isNotDetected = false
            case .notDetected:
                // Retain prior values: they may be stale but are not wrong.
                isNotDetected = true
                isStale = section != nil
                error = nil
            case .unavailable:
                // The fetch closure cannot throw and providers never surface raw
                // errors; publish pre-approved copy only. Prior values remain.
                error = section == nil ? .loadFailed : .updateFailed
                isStale = section != nil
                isNotDetected = false
            }
        }
    }
}
