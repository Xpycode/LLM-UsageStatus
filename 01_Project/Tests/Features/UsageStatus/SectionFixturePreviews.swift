import SwiftUI
@testable import LLMUsageStatus

/// Fixture-driven previews of every section state across all three
/// providers. Each preview drives a real `UsageStore` through its own
/// refresh path with scripted `ProviderSectionState` values, then renders
/// the production `ProviderSectionView` — the same scenarios the render
/// tests in `SectionFixtureRenderTests` write out as PNGs.
///
/// Pure presentation: no service, network, Keychain, or defaults access.
struct SectionFixturePreview: View {
    let scenario: SectionFixture.Scenario

    @State private var store: UsageStore?

    var body: some View {
        SectionFixture.sectionView(store: store, expanded: scenario.expanded)
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .task {
                store = await SectionFixture.makeStore(for: scenario)
            }
    }
}

// One preview per provider and section state (3 x 5 = 15), plus the
// collapsed headline variants including the Vibe monthly-budget headline.

#Preview("Codex · populated") { SectionFixturePreview(scenario: .fixture("codex", .populated)) }
#Preview("Codex · unavailable") { SectionFixturePreview(scenario: .fixture("codex", .unavailable)) }
#Preview("Codex · not detected") { SectionFixturePreview(scenario: .fixture("codex", .notDetected)) }
#Preview("Codex · stale") { SectionFixturePreview(scenario: .fixture("codex", .stale)) }
#Preview("Codex · estimate fallback") { SectionFixturePreview(scenario: .fixture("codex", .estimateFallback)) }

#Preview("Claude Code · populated") { SectionFixturePreview(scenario: .fixture("claude", .populated)) }
#Preview("Claude Code · unavailable") { SectionFixturePreview(scenario: .fixture("claude", .unavailable)) }
#Preview("Claude Code · not detected") { SectionFixturePreview(scenario: .fixture("claude", .notDetected)) }
#Preview("Claude Code · stale") { SectionFixturePreview(scenario: .fixture("claude", .stale)) }
#Preview("Claude Code · estimate fallback") { SectionFixturePreview(scenario: .fixture("claude", .estimateFallback)) }

#Preview("Mistral Vibe · populated") { SectionFixturePreview(scenario: .fixture("vibe", .populated)) }
#Preview("Mistral Vibe · unavailable") { SectionFixturePreview(scenario: .fixture("vibe", .unavailable)) }
#Preview("Mistral Vibe · not detected") { SectionFixturePreview(scenario: .fixture("vibe", .notDetected)) }
#Preview("Mistral Vibe · stale") { SectionFixturePreview(scenario: .fixture("vibe", .stale)) }
#Preview("Mistral Vibe · estimate fallback") { SectionFixturePreview(scenario: .fixture("vibe", .estimateFallback)) }

#Preview("Codex · headline") { SectionFixturePreview(scenario: SectionFixture.headlineScenarios[0]) }
#Preview("Claude Code · headline") { SectionFixturePreview(scenario: SectionFixture.headlineScenarios[1]) }
#Preview("Mistral Vibe · budget headline") { SectionFixturePreview(scenario: SectionFixture.headlineScenarios[2]) }
