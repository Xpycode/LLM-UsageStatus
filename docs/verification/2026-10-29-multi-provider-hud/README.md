# Verification — Multi-Provider Usage HUD v1 (Task 3.2)

Evidence for task 3.2 (and Wave 4's evidence refresh, task 4.3) of
`docs/plans/2026-10-29-multi-provider-hud/IMPLEMENTATION_PLAN.md`:
full-suite verification plus fixture renders of every section state for every provider.

## What this evidence shows

### 1. Full test suite green

The plan's exact command, run against the tree after task 2.3 (baseline) and after
task 3.2's additions:

```bash
cd 01_Project && xcodebuild -project LLM-UsageStatus.xcodeproj -scheme LLM-UsageStatus \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath build/UsageHUD test
```

- Baseline (pre-3.2 files): 116 tests, 0 failures — `** TEST SUCCEEDED **`.
- After 3.2 additions: 119 tests, 0 failures — `** TEST SUCCEEDED **`.
- After Wave 4 (headline-first sections, Vibe monthly budget; task 4.3):
  129 tests, 0 failures — `** TEST SUCCEEDED **`, all 18 renders regenerated
  (15 expanded states + 3 collapsed headline variants).
- After task 4.4 (Vibe no-budget glance line): 133 tests, 0 failures —
  `** TEST SUCCEEDED **`, renders regenerated again (the Vibe fixtures now
  carry the last-24-hours glance line).
  The 3 new tests are `SectionFixtureRenderTests` (one per provider, app-hosted).

No existing test failed at any point; no app source was changed for this task.

### 2. Section-state fixture renders — `fixtures/`

15 checked-in PNGs: one per provider (Codex, Claude Code, Mistral Vibe) crossed with
the five section states. Each shows the production `ProviderSectionView` driven by a
real `UsageStore` whose refresh path replays scripted `ProviderSectionState` values.
File names are `<provider>-<state>.png`:

| State | Meaning (store/view vocabulary) | Files |
|---|---|---|
| `populated` | Fresh values; headline + rows/meters/deadlines rendered | `codex-populated.png`, `claude-populated.png`, `vibe-populated.png` |
| `unavailable` | Refresh failed before any values existed; pre-approved "Unable to load usage" copy | `codex-unavailable.png`, `claude-unavailable.png`, `vibe-unavailable.png` |
| `not-detected` | CLI absent; "Not detected on this Mac." copy | `codex-not-detected.png`, `claude-not-detected.png`, `vibe-not-detected.png` |
| `stale` | Failed refresh retained prior values; orange "Update failed · showing previous values" caption | `codex-stale.png`, `claude-stale.png`, `vibe-stale.png` |
| `estimate-fallback` | Fallback data visibly labeled "estimated" | `codex-estimate-fallback.png`, `claude-estimate-fallback.png`, `vibe-estimate-fallback.png` |
| `headline` (collapsed) | The glance state the panel opens in: percent-left headline + reset countdown + estimated per-day amount, detail hidden until clicked | `codex-headline.png`, `claude-headline.png`, `vibe-budget-headline.png` |

The populated/stale/estimate-fallback renders above show the **expanded** detail (all rows,
meters, deadlines); the three headline renders show the **collapsed** glance state, including
the Vibe monthly-budget headline (`vibe-budget-headline.png`: estimated % left, $/day quote,
estimate tag — mirrors `VibeUsageProvider`'s budget path).

Fixture provenance notes (honest labeling, per the project rule that estimates must be
visibly labeled and never confused with authoritative values):

- **Claude `estimate-fallback`** is the real production fallback: local transcript
  aggregates, every row estimate-labeled (mirrors `ClaudeUsageProvider.section(for: ClaudeLogSummary)`).
- **Vibe `estimate-fallback`** is the real production degradation: unattributed
  rolling-window rows estimate-labeled, cost line suppressed (mirrors the unattributed
  path in `VibeUsageProvider.section(for:)`).
- **Codex `estimate-fallback`** exercises the view's estimate labeling with Codex-shaped
  content; the current production Codex mapping (`CodexUsageService.section(for:)`) does
  not emit estimate flags, so this combination cannot occur in production today. It is
  included so the state's rendering is covered for every provider.

Fixture content mirrors each provider's real section shapes (ids, labels, and value
formats match the provider→section mappings and their tests). Countdowns and timestamps
are rendered against a fixed reference date (`SectionFixture.now`), so renders are
deterministic across machines and runs.

### 3. Checked-in previews

The same scenarios are available as SwiftUI previews (Xcode canvas) in
`01_Project/Tests/Features/UsageStatus/SectionFixturePreviews.swift` — one
`#Preview` per provider × state (15), plus the three headline variants
(Codex, Claude, Vibe with budget), all driven by the shared catalog in
`SectionFixtures.swift`. Previews and render tests share the catalog, so they
cannot drift.

## How to regenerate the renders

```bash
cd 01_Project && xcodegen generate
xcodebuild -project LLM-UsageStatus.xcodeproj -scheme LLM-UsageStatus \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath build/UsageHUD test
# Renders land beside the build products (never inside the .app bundle):
cp build/UsageHUD/Build/Products/Debug/SectionFixtureRenders/*.png \
  ../docs/verification/2026-10-29-multi-provider-hud/fixtures/
```

The render tests are app-hosted like the rest of the suite: running them launches a
brief instance of the app. The render path lives only in the test target
(`SectionFixtureRenderTests.swift`); nothing render-related is in the release app.
Each test asserts every PNG is non-empty (with real content, > 1,000 bytes) before
writing it.

## Scope and limits

- Renders evidence the view-layer states, not live provider data. Interactive criteria
  (hotkey toggle, live population against real CLIs, restart persistence) fold into
  external check E1 per the plan.
- Two transient codesign failures during task 3.2 development were caused by the render
  tests writing PNGs inside the app bundle; the final version writes to
  `Build/Products/Debug/SectionFixtureRenders` outside the `.app`, and the final three
  consecutive suite runs re-signed and passed without incident.
