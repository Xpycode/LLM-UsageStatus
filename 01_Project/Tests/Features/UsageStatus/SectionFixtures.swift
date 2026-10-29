import SwiftUI
@testable import LLMUsageStatus

/// Fixture catalog for section-state visuals: one scenario per provider and
/// per section state. Pure presentation data built from the section-model
/// value types (`ProviderSection` and friends); no service, network,
/// Keychain, or defaults access happens here.
///
/// The same scenarios drive the `#Preview` declarations in
/// `SectionFixturePreviews` and the ImageRenderer render tests in
/// `SectionFixtureRenderTests`, so previews and checked-in PNGs cannot drift.

/// The five section states the HUD can show for any provider. The first three
/// come from `ProviderSectionState`; stale and estimate-fallback are store /
/// model level: a failed refresh retaining prior values, and fallback data
/// carrying the visible estimate label.
enum SectionFixtureState: String, CaseIterable {
    /// Fresh authoritative values (store: section set, nothing flagged).
    case populated
    /// Refresh failed before any values existed (store: `loadFailed` copy).
    case unavailable
    /// The provider's CLI or sign-in is absent (store: not-detected copy).
    case notDetected
    /// A failed refresh retained prior values (store: section + isStale).
    case stale
    /// Values came from a fallback source; rows/meters carry the estimate tag.
    case estimateFallback

    /// File-name slug shared by renders, preview titles, and fixtures/.
    var slug: String {
        switch self {
        case .estimateFallback: return "estimate-fallback"
        case .notDetected: return "not-detected"
        default: return rawValue
        }
    }
}

enum SectionFixture {
    /// Fixed reference clock so countdowns and captions render identically
    /// on every machine and every run.
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    struct Scenario: Identifiable {
        let providerID: String
        let displayName: String
        let state: SectionFixtureState
        /// Content shown for populated/stale/estimate-fallback; nil for the
        /// pure failure states, which never display section content.
        let section: ProviderSection?
        /// Collapsed renders show the headline only (the glance state the
        /// panel opens in); expanded renders show the full detail.
        var expanded: Bool = true
        /// Render file name when it differs from the state-derived default.
        var fileNameOverride: String? = nil

        var id: String { "\(providerID)-\(state.slug)\(expanded ? "" : "-collapsed")" }
        var fileName: String {
            if let fileNameOverride { return fileNameOverride }
            return expanded ? "\(providerID)-\(state.slug).png" : "\(providerID)-headline.png"
        }
        var title: String { "\(displayName) · \(expanded ? state.slug : state.slug + " (headline)")" }
    }

    /// The canonical 15 scenarios: three providers crossed with five section
    /// states, rendered expanded (full detail).
    static let scenarios: [Scenario] = codexScenarios + claudeScenarios + vibeScenarios

    /// Collapsed-headline variants: the glance state the panel opens in,
    /// including the Vibe monthly-budget headline.
    static let headlineScenarios: [Scenario] = [
        Scenario(providerID: "codex", displayName: "Codex", state: .populated,
                  section: codexPopulatedSection, expanded: false),
        Scenario(providerID: "claude", displayName: "Claude Code", state: .populated,
                  section: claudeEndpointSection, expanded: false),
        Scenario(providerID: "vibe", displayName: "Mistral Vibe", state: .populated,
                  section: vibeBudgetSection, expanded: false,
                  fileNameOverride: "vibe-budget-headline.png"),
    ]

    /// Every scenario, expanded detail and collapsed headlines alike.
    static var allScenarios: [Scenario] { scenarios + headlineScenarios }

    static func scenario(_ providerID: String, _ state: SectionFixtureState) -> Scenario {
        guard let match = scenarios.first(where: { $0.providerID == providerID && $0.state == state }) else {
            fatalError("Missing fixture scenario \(providerID)/\(state.slug)")
        }
        return match
    }

    /// The single-section visual used by previews and render tests alike:
    /// panel-width framing around the production `ProviderSectionView`.
    @ViewBuilder
    static func sectionView(store: UsageStore?, expanded: Bool = true) -> some View {
        if let store {
            ProviderSectionView(store: store, now: now, showFiveHourLimit: true, expanded: expanded)
                .frame(width: 320, alignment: .topLeading)
        } else {
            ProgressView().frame(width: 320)
        }
    }

    /// Builds a `UsageStore` in the scenario's display state by driving the
    /// store's own refresh path with the scripted states and settling before
    /// returning, so the state is complete before rendering.
    @MainActor
    static func makeStore(for scenario: Scenario) async -> UsageStore {
        let fetch = SectionFixtureFetch(states: states(for: scenario))
        let store = UsageStore(providerID: scenario.providerID,
                               displayName: scenario.displayName,
                               fetch: { fetch.next() })
        await store.refresh()?.value
        if scenario.state == .stale {
            await store.refresh()?.value
        }
        return store
    }

    private static func states(for scenario: Scenario) -> [ProviderSectionState] {
        switch scenario.state {
        case .populated, .estimateFallback:
            return [scenario.section.map { .populated($0) } ?? .unavailable]
        case .unavailable:
            return [.unavailable]
        case .notDetected:
            return [.notDetected]
        case .stale:
            return [scenario.section.map { .populated($0) } ?? .unavailable, .unavailable]
        }
    }

    // MARK: - Codex
    // Shapes mirror CodexUsageService.section(for:), the production snapshot
    // mapping (see CodexUsageProviderTests for the real mapping tests).

    private static var codexPopulatedSection: ProviderSection {
        ProviderSection(
            rows: [
                SectionRow(id: "credits", label: "Credits", value: "12.75"),
                SectionRow(id: "reset-passes", label: "Reset passes", value: "3"),
            ],
            meters: [
                SectionMeter(id: "weekly-limit", label: "Weekly limit", fraction: 0.32)!,
                SectionMeter(id: "five-hour-limit", label: "5-hour limit", fraction: 0.18)!,
            ],
            deadlines: [
                SectionDeadline(id: "weekly-reset", label: "Weekly limit", date: now.addingTimeInterval(90_000)),
                SectionDeadline(id: "five-hour-reset", label: "5-hour limit", date: now.addingTimeInterval(4_500)),
                SectionDeadline(id: "pass-expiry", label: "Next reset-pass expiry", date: now.addingTimeInterval(172_800)),
            ],
            headline: SectionHeadline(windowLabel: "Weekly limit", fractionLeft: 0.68,
                                     resetsAt: now.addingTimeInterval(90_000),
                                     dailyBudget: SectionDailyBudget(amount: Decimal(string: "7417273")!,
                                                                     unitText: "credits", isEstimate: false)),
            lastUpdated: now)
    }

    /// The production Codex mapping does not currently emit estimate flags;
    /// this fixture exercises the view's estimate labeling with Codex-shaped
    /// content so the state's rendering is covered for every provider.
    private static var codexEstimateSection: ProviderSection {
        ProviderSection(
            rows: [
                SectionRow(id: "credits", label: "Credits", value: "12.75"),
                SectionRow(id: "reset-passes", label: "Reset passes", value: "3", isEstimate: true),
            ],
            meters: [
                SectionMeter(id: "weekly-limit", label: "Weekly limit", fraction: 0.32)!,
                SectionMeter(id: "five-hour-limit", label: "5-hour limit", fraction: 0.18, isEstimate: true)!,
            ],
            deadlines: [
                SectionDeadline(id: "weekly-reset", label: "Weekly limit", date: now.addingTimeInterval(90_000)),
                SectionDeadline(id: "five-hour-reset", label: "5-hour limit", date: now.addingTimeInterval(4_500), isEstimate: true),
                SectionDeadline(id: "pass-expiry", label: "Next reset-pass expiry", date: now.addingTimeInterval(172_800)),
            ],
            lastUpdated: now)
    }

    private static var codexScenarios: [Scenario] {
        let populated = codexPopulatedSection
        return [
            Scenario(providerID: "codex", displayName: "Codex", state: .populated, section: populated),
            Scenario(providerID: "codex", displayName: "Codex", state: .unavailable, section: nil),
            Scenario(providerID: "codex", displayName: "Codex", state: .notDetected, section: nil),
            Scenario(providerID: "codex", displayName: "Codex", state: .stale, section: populated),
            Scenario(providerID: "codex", displayName: "Codex", state: .estimateFallback, section: codexEstimateSection),
        ]
    }

    // MARK: - Claude Code
    // Populated mirrors ClaudeUsageProvider.section(for: ClaudeOAuthUsage)
    // (endpoint meters, no rows); estimate-fallback mirrors section(for:
    // ClaudeLogSummary) (local aggregates, every row estimate-labeled).

    private static var claudeEndpointSection: ProviderSection {
        ProviderSection(
            meters: [
                SectionMeter(id: "five-hour-limit", label: "5-hour limit", fraction: 0.42)!,
                SectionMeter(id: "seven-day-limit", label: "7-day limit", fraction: 0.81)!,
            ],
            deadlines: [
                SectionDeadline(id: "five-hour-reset", label: "5-hour limit", date: now.addingTimeInterval(4_500)),
                SectionDeadline(id: "seven-day-reset", label: "7-day limit", date: now.addingTimeInterval(90_000)),
            ],
            headline: SectionHeadline(windowLabel: "5-hour limit", fractionLeft: 0.58,
                                     resetsAt: now.addingTimeInterval(4_500)),
            lastUpdated: now)
    }

    private static var claudeLocalFallbackSection: ProviderSection {
        ProviderSection(
            rows: [
                SectionRow(id: "sessions", label: "Sessions (7 days)", value: "3", isEstimate: true),
                SectionRow(id: "input-tokens", label: "Input tokens (7 days)", value: "18,402", isEstimate: true),
                SectionRow(id: "output-tokens", label: "Output tokens (7 days)", value: "9,217", isEstimate: true),
                SectionRow(id: "cache-creation-tokens", label: "Cache creation (7 days)", value: "4,102", isEstimate: true),
                SectionRow(id: "cache-read-tokens", label: "Cache read (7 days)", value: "12,940", isEstimate: true),
                SectionRow(id: "malformed-lines", label: "Skipped malformed lines", value: "2", isEstimate: true),
            ],
            lastUpdated: now.addingTimeInterval(-3_600))
    }

    private static var claudeScenarios: [Scenario] {
        let endpoint = claudeEndpointSection
        return [
            Scenario(providerID: "claude", displayName: "Claude Code", state: .populated, section: endpoint),
            Scenario(providerID: "claude", displayName: "Claude Code", state: .unavailable, section: nil),
            Scenario(providerID: "claude", displayName: "Claude Code", state: .notDetected, section: nil),
            Scenario(providerID: "claude", displayName: "Claude Code", state: .stale, section: endpoint),
            Scenario(providerID: "claude", displayName: "Claude Code", state: .estimateFallback, section: claudeLocalFallbackSection),
        ]
    }

    // MARK: - Mistral Vibe
    // Populated mirrors VibeUsageProvider.section(for:) with a resolvable
    // model (cost line present); estimate-fallback mirrors the unattributed
    // window degradation (window rows estimate-labeled, cost line suppressed).

    private static var vibePopulatedSection: ProviderSection {
        ProviderSection(
            rows: [
                SectionRow(id: "sessions", label: "Sessions", value: "3"),
                SectionRow(id: "tokens-24h", label: "Tokens (24 hours)", value: "5,300"),
                SectionRow(id: "tokens-7d", label: "Tokens (7 days)", value: "18,204"),
                SectionRow(id: "tokens-total", label: "Tokens (all time)", value: "9,876,543"),
                SectionRow(id: "estimated-cost", label: "Estimated cost", value: "$2.41", isEstimate: true),
            ],
            glanceLine: SectionGlanceLine("≈ $2.41 · 5.3K tokens · 24 hours", isEstimate: true),
            lastUpdated: now)
    }

    private static var vibeUnattributedSection: ProviderSection {
        ProviderSection(
            rows: [
                SectionRow(id: "sessions", label: "Sessions", value: "1"),
                SectionRow(id: "tokens-24h", label: "Tokens (24 hours)", value: "1,500", isEstimate: true),
                SectionRow(id: "tokens-7d", label: "Tokens (7 days)", value: "1,500", isEstimate: true),
                SectionRow(id: "tokens-total", label: "Tokens (all time)", value: "1,500"),
            ],
            glanceLine: SectionGlanceLine("1.5K tokens · 24 hours", isEstimate: true),
            lastUpdated: now)
    }

    /// Populated plus a configured monthly budget: mirrors
    /// VibeUsageProvider's budget headline (estimated % left + $/day).
    private static var vibeBudgetSection: ProviderSection {
        ProviderSection(
            rows: [
                SectionRow(id: "sessions", label: "Sessions", value: "3"),
                SectionRow(id: "tokens-24h", label: "Tokens (24 hours)", value: "5,300"),
                SectionRow(id: "tokens-7d", label: "Tokens (7 days)", value: "18,204"),
                SectionRow(id: "tokens-total", label: "Tokens (all time)", value: "9,876,543"),
                SectionRow(id: "estimated-cost", label: "Estimated cost", value: "$17.47", isEstimate: true),
            ],
            headline: SectionHeadline(windowLabel: "Monthly budget", fractionLeft: 0.94,
                                     resetsAt: now.addingTimeInterval(172_800),
                                     dailyBudget: SectionDailyBudget(amount: Decimal(string: "282.53")!,
                                                                     unitText: "$", isEstimate: true),
                                     isEstimate: true),
            lastUpdated: now)
    }

    private static var vibeScenarios: [Scenario] {
        let populated = vibePopulatedSection
        return [
            Scenario(providerID: "vibe", displayName: "Mistral Vibe", state: .populated, section: populated),
            Scenario(providerID: "vibe", displayName: "Mistral Vibe", state: .unavailable, section: nil),
            Scenario(providerID: "vibe", displayName: "Mistral Vibe", state: .notDetected, section: nil),
            Scenario(providerID: "vibe", displayName: "Mistral Vibe", state: .stale, section: populated),
            Scenario(providerID: "vibe", displayName: "Mistral Vibe", state: .estimateFallback, section: vibeUnattributedSection),
        ]
    }
}

extension SectionFixture.Scenario {
    /// Member-style lookup so preview declarations can read
    /// `.fixture("codex", .populated)`.
    static func fixture(_ providerID: String, _ state: SectionFixtureState) -> SectionFixture.Scenario {
        SectionFixture.scenario(providerID, state)
    }
}

/// A fetch closure replaying a scripted state sequence, shared by every
/// fixture store. Thread-safe because `UsageStore.fetch` is `@Sendable`.
final class SectionFixtureFetch: @unchecked Sendable {
    private let lock = NSLock()
    private var remaining: [ProviderSectionState]

    init(states: [ProviderSectionState]) {
        remaining = states
    }

    /// Returns the next scripted state; the last one repeats if the store is
    /// refreshed more often than scripted (previews can re-run tasks).
    func next() -> ProviderSectionState {
        lock.lock()
        defer { lock.unlock() }
        if remaining.count > 1 { remaining.removeFirst() }
        return remaining[0]
    }
}
