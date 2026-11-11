# Implementation Plan — 0.2.2 (correct Vibe numbers, layout-aware shortcut refusals, provider on/off, cache logging)

> **Persists across sessions.** Execute using the shared `commands/execute.md` procedure.
> Repair scheduling errors while preserving task IDs, completed evidence and approved scope.
> Task state/evidence is authoritative here; TASKS links here and holds backlog/inbox.
> Follow the master's `reference/task-state.md` for legacy reconciliation and archival.

**Progress:** 6/8 tasks complete (1.1, 1.2, 1.3, 2.1, 2.2, 3.1); 3.2 done except the E1 build handoff (built, not launched); 1.4 Settings screenshot pending at E1; external checks E1–E4 pending.
**Task states:** unchecked = pending / implemented-unverified / blocked (name gate);
checked = complete with required evidence. Task identity includes this plan path plus ID.

## Goal

Ship a Developer ID–notarized **0.2.2 (202)** maintenance release. Its four outcomes:

1. **Vibe numbers are right and never fall.** "Tokens (all time)", the cost row and the budget
   headline stop double-counting cached and reasoning tokens. Totals come from Vibe's own per-session
   counters, so they no longer drop when Vibe rotates old journal segments.
2. **Shortcut refusals follow the keyboard layout.** Copy, Undo and the other refusals apply to the
   key that types the letter, not its US position. Command-Comma opens Settings from the key that
   types `,`. The ISO `<` key can be used.
3. **Providers can be turned on and off in Settings.** A provider that is off is hidden from the
   panel and is never read or fetched.
4. **Cache failures are logged.** No `try?` in `SectionStateCache`.

Journeys:
- **Vibe:** open the panel twice, minutes apart, across a Vibe rotation. "Tokens (all time)" stays
  the same or rises. A session's total matches Vibe's own `tokenUsage.totalTokens`. The cost row is
  roughly 7–8× lower than in 0.2.1, and the CHANGELOG explains why.
- **Shortcut (German QWERTZ):** in Settings, record Command plus the key labelled Z. It is refused
  as "used by macOS and other apps". Command plus the key labelled Y is accepted. **AZERTY:** with
  the panel showing, Command plus the key that types `,` opens Settings.
- **Providers:** Settings → Providers → untick Claude Code → reopen the panel. It has no Claude
  section, and no Keychain read or endpoint call happens. With all three off, the panel shows "All
  providers are off. Turn them on in Settings."
- **Release:** `scripts/notarize-release.sh 0.2.2` then `scripts/package-dmg.sh 0.2.2` give Accepted
  and stapled results. The DMG and the website are updated, as for 0.2.1.

Research: `research/findings.md` (R1 shortcuts, R2 Vibe, R3 cache), with sources.

## Scope decisions

Confirmed by the user on 2026-11-10 unless marked otherwise.

- **D1 — Vibe totals come from session snapshots** (research R2), not from summing journal rows.
  - **Source:** per-session `snapshot.session.tokenUsage`, overridden by the newest complete
    `projection_delta` `set_envelope` `tokenUsage` in the recovery journal segment.
  - **Fallback:** sessions with no `tokenUsage` fall back to journal sums.
  - **Planner decision, inside the approved item's scope:** the 24-hour and 7-day windows stay
    journal-based, because only journal rows carry timestamps. They still get the inclusive-field
    fix and stay labelled as estimates.
  - The label "Tokens (all time)" stays.
- **D2 — Inclusive token semantics.** Cached tokens are part of input and reasoning tokens are part
  of output (verified on all 776 local rows).
  - Total = input + output.
  - Cost = (input − cached) × input price + cached × cached price + output × output price.
  - `cache_write_tokens`: task 1.3 checks how mistral-vibe derives it and records the result.
    Default: treat it as already included in input, since it is 0 in every local row.
- **D3 — Child (sub-agent) sessions fold into their root** (`snapshot.session.rootSessionId`) for
  the **session count** only (user).
  - Token and cost totals still sum every session, because a root's counter excludes its children:
    root 77e752bb has 2.79M while its children have 4.98M.
  - A child whose root is missing from the store counts as its own session.
  - A child is priced by its own model when that resolves, otherwise by its root's model.
- **D4 — Layout-aware refusals live only in the recorder** (research R1).
  - The stored-value read stays structural (supported key, Command or Control), so switching
    layouts never silently resets a saved shortcut.
  - When the translator returns nothing, the US-position set is used.
- **D5 — Settings hotkey follows the layout.** Register Command plus the key that types `,`, and
  re-register on input-source change while the panel shows.
- **D6 — Provider on/off (UI-changes protocol, confirmed by the user 2026-11-10).**
  - **Settings layout:** a new **Providers** section comes **first**, above Startup, with three
    `NSButton` checkboxes (same control as "Launch at login"), all on by default:

    ```
    PROVIDERS
    [x] Codex
    [x] Claude Code
    [x] Mistral Vibe
    ─────────────
    STARTUP …  ─  SHORTCUT …  ─  ABOUT …
    ```

  - **When a provider is off:** its panel section is hidden, and it gets no refresh on open, no
    renewal refresh and no menu items. "Show 5-hour limit" and "Set Vibe Monthly Budget…" are hidden
    while their provider is off.
  - **All three off is allowed.** The panel shows one secondary line: "All providers are off. Turn
    them on in Settings."
  - **Turning a provider on while the panel shows:** its cached section appears and it refreshes.
- **D7 — Version 0.2.2, build 202** (monotonic).
- **Not in scope** (the user deferred both on 2026-11-10; new Backlog items):
  - the monthly budget counting only usage since the reset day;
  - refusing enabled `CopySymbolicHotKeys` system hotkeys.
  - Also out of scope: Sparkle and provider logos.

## Acceptance Criteria

- [ ] Vibe "Tokens (all time)" equals the sum of every session's snapshot or live `tokenUsage.totalTokens`
      (journal sums only for sessions with no snapshot). It does not decrease when a rotation
      deletes a journal segment (fixture), and a truncated last journal line is ignored.
- [ ] No Vibe total or cost counts cached or reasoning tokens twice. The rate-card cost charges
      cached tokens once, at the cached price.
- [ ] Vibe "Sessions" counts root sessions. Child usage is still in the totals.
- [ ] On QWERTZ, the recorder refuses Command plus the key that types z (physical Y position) and
      accepts the key that types y. On Dvorak, it refuses the key that types c. On AZERTY, Command
      plus the key that types `,` is reserved and the US Comma position is accepted. The ISO Section
      key (0x0A) is accepted. A stored chord that the current layout would refuse still loads.
- [ ] With the panel showing on AZERTY, Command plus the key that types `,` opens Settings.
      Switching the layout while the panel shows moves the binding.
- [ ] Settings shows Providers first, with three checkboxes that persist across restarts. A
      provider that is off has no section, no fetch and no menu items. With all off, the panel shows
      the hint. Turning one on while the panel shows renders it and refreshes it.
- [ ] `SectionStateCache` has no `try?`. A missing file stays silent. Read, decode, directory and
      write failures are logged with `Logger` and fall back to an empty cache.
- [ ] Help, README and CHANGELOG describe the new behaviour (no remaining "US key position" claim).
      The CHANGELOG explains the lower Vibe numbers.
- [ ] Notarized 0.2.2 (202): DMG on the website, page and roster show v0.2.2, `dl.php` serves it.

## Execution schedule and ownership

- **Execution scope and limits.** Execution has not been requested yet. Each of these needs an
  explicit go-ahead from the user:
  - pushing (CI);
  - notarization (contacts Apple, uses the `99-AUTH` key);
  - installing into `/Applications`;
  - deploying the website.
- **Coordinator-owned files and resources:**
  - `01_Project/project.yml`, `xcodegen generate` and the tracked `.xcodeproj`;
  - `README.md`, `CHANGELOG.md`, `01_Project/Resources/Help/*`, `docs/*` (including `decisions.md`);
  - `scripts/*`, DerivedData and build folders, git.
  - `AppDelegate.swift` is coordinator-owned **except in Wave 1**, where 1.4 owns it.
- **New files** are pre-created as empty stubs by the coordinator, followed by
  `xcodegen generate`, before agents are dispatched. Sources and tests are folder globs, so agents
  never touch the project.
- **Test-running limit (carried over).** The test target is app-hosted. Local backpressure is
  `xcodebuild build-for-testing`, and the full suite runs on GitHub CI. A local `xcodebuild test`
  needs a go-ahead. Tests must compile on Xcode 16.4 (no `super` calls in async `setUp`/`tearDown`
  of `@MainActor` classes; see 947650b). Tests may not depend on the Mac's real keyboard layout,
  except one live smoke test like `testLiveDefaultToggleName`.
- **Interfaces fixed before dispatch:**

```swift
// 1.2 — Sources/App/KeyboardLayoutNames.swift (+ HotKeyShortcut.swift)
struct LayoutTranslator: Sendable {
    /// Character typed by `keyCode` with Command held (Command-specific maps, e.g. "Dvorak – QWERTY ⌘");
    /// nil when the layout is unavailable or the result is empty / multi-character.
    var character: @Sendable (_ keyCode: UInt32) -> Character?
    /// Key code that types `character` (scan 0…127), nil when none.
    var keyCode: @Sendable (_ character: Character) -> UInt32?
    @MainActor static var current: LayoutTranslator { get }   // ASCII-capable layout, UCKeyTranslate
    static let usANSI: LayoutTranslator                       // fallback / tests
}
extension HotKeyShortcut {
    func validate() -> ValidationFailure?                                // structural only (store)
    func validate(using translator: LayoutTranslator) -> ValidationFailure? // + reserved + system (recorder)
    static func settings(using translator: LayoutTranslator) -> HotKeyShortcut // Command + key typing ","
}

// 1.3 / 2.2 — Sources/Shared/Services/Vibe/*
// VibeTokenTotals: inputTokens INCLUDES cachedInputTokens; outputTokens INCLUDES reasoningTokens.
extension VibeUsageProvider { static func totalTokens(_: VibeTokenTotals) -> Int }  // input + output
extension VibeRateCard { static func cost(inputTokens:cachedTokens:outputTokens:prices:) -> Decimal } // inclusive input

// 1.4 — Sources/Features/UsageStatus/UsagePreferences.swift
extension UsagePreferences {
    @Published var enabledProviderIDs: Set<String>   // keys "<id>.enabled", default true; ids codex/claude/vibe
    func isEnabled(_ providerID: String) -> Bool
    func setEnabled(_ enabled: Bool, for providerID: String)
}
```

| Wave | Tasks | Mode | Why |
|---|---|---|---|
| 1 | 1.1, 1.2, 1.3, 1.4 | 4 parallel agents | No mutual prerequisites; disjoint files (table below) |
| 2 | 2.1 (coordinator), 2.2 (agent) | parallel | 2.1 needs 1.2 + 1.4 (`AppDelegate`); 2.2 needs 1.3 (same Vibe files) |
| 3 | 3.1 → 3.2 | serial, coordinator | Shared docs/version files; review needs everything integrated |

Wave 1 ownership (exclusive):

| Task | Owns |
|---|---|
| 1.1 | `SectionStateCache.swift`, `Tests/Features/UsageStatus/SectionStateCacheTests.swift` |
| 1.2 | `KeyboardLayoutNames.swift`, `HotKeyShortcut.swift`, `ShortcutRecorderField.swift`, `Tests/App/HotKeyShortcutTests.swift`, `Tests/App/ShortcutRecorderFieldTests.swift` |
| 1.3 | `Vibe/VibeJournalAggregator.swift`, `Vibe/VibeUsageProvider.swift`, `Vibe/VibeRateCard.swift`, `Tests/Shared/Services/Vibe/*`, `Tests/Features/UsageStatus/SectionFixtures.swift` |
| 1.4 | `UsagePreferences.swift`, `SettingsWindowController.swift`, `Views/UsageStatusView.swift`, `AppDelegate.swift`, `Tests/Features/UsageStatus/UsagePreferencesTests.swift` |

## Tasks

### Wave 1 (parallel — no mutual dependencies; disjoint ownership)

- [x] **1.1**: Log `SectionStateCache` failures (Backlog #13) — `c5fc548`
  - Depends on: none. External gates: none.
  - Owns: see table.
  - Success:
    - The file has no `try?`.
    - A file-not-found read (`CocoaError.fileReadNoSuchFile`) returns `[:]` silently. Any other read
      error, a decode error, and directory, encode or write failures each log once through
      `Logger(subsystem: "com.sim.LLM-UsageStatus", category: "SectionCache")`, with no file
      contents or paths beyond the file name. The `[:]` fallback is kept.
    - The doc comments are updated.
    - Tests cover the missing file (empty, no throw), a corrupt file (empty) and an unwritable
      directory (no crash; the next load still works).
  - Backpressure: `build-for-testing`; `grep -n 'try?' Sources/Features/UsageStatus/SectionStateCache.swift` is empty.

- [x] **1.2**: Layout-aware shortcut refusals and ISO key (Backlog #12, D4) — `4421c67` (real-layout behaviour still gated by E1)
  - Depends on: none. External gates: E1 (real QWERTZ, AZERTY and Dvorak behaviour).
  - Owns: see table. Interfaces: `LayoutTranslator`, the two-level `validate`, `settings(using:)`.
  - Success:
    - **`LayoutTranslator.current`:** uses `UCKeyTranslate` on the ASCII-capable layout, with the
      Command bit in the modifier state, `LMGetKbdType()` and no dead keys.
    - **Recorder refusals:** the recorder uses `validate(using: .current)`. It refuses Command or
      Command-Shift on any key whose character (lowercased) is in `a c f h m n o p q s t v w x z 3 4 5`.
      It also refuses Space, Tab, Grave and ISO Section by code. "Reserved" means Command plus the
      key that types `,`.
    - **Fallback:** when the translator returns nil, the US set is used.
    - **ISO key:** `kVK_ISO_Section` is in `keyNames`, named by the layout.
    - **Stored chords:** `HotKeyShortcutStore.current` keeps the structural `validate()`.
    - **Refusal text:** "Command-Comma is reserved for Settings." stays correct, because it names
      the character.
    - **Tests** use fake translators for QWERTZ, AZERTY, Dvorak, Command-QWERTY and nil, covering
      every Acceptance Criteria case. The six tests named in R1 are updated, and the totals of
      `HotKeyShortcutTests` and `ShortcutRecorderFieldTests` do not shrink.
  - Backpressure: `build-for-testing`; the test list is reported to the coordinator.

- [x] **1.3**: Inclusive Vibe token semantics and cost (D2) — `7175c92`
  - Depends on: none. External gates: none.
  - Owns: see table.
  - Success:
    - **Extraction:** `extractUsage` keeps cached tokens inside input and reasoning tokens inside
      output. It stops adding `cache_write_tokens` to input, unless the mistral-vibe source shows it
      is excluded from `input_tokens`; record the finding with its source URL in the task's report.
    - **Totals:** `totalTokens` is input + output.
    - **Cost:** `VibeRateCard.cost` charges (input − cached) at the input price, never a negative
      amount.
    - **Fixtures:** `VibeJournalAggregatorTests:24` and every other fixture where cached > input or
      reasoning > output is corrected to realistic inclusive values. `SectionFixtures` Vibe values
      are updated.
    - **New tests:** inclusive totals, single cached charge, and a clamp when cached > input.
  - Backpressure: `build-for-testing`.

- [x] **1.4**: Provider on/off — preferences, Settings section, panel and menu (D6) — `2c11dbe`; visual check passed in E1 (2026-11-11, user-operated; no screenshot captured)
  - Depends on: none. External gates: E1 (visual check of Settings and the panel).
  - Owns: see table (`AppDelegate.swift` only in this wave).
  - Success:
    - **Preferences:** `UsagePreferences.enabledProviderIDs` persists `<id>.enabled` (default on).
    - **Settings:** `SettingsWindowController` takes `preferences` in `init` and adds **Providers**
      as the first section. It has three `NSButton(checkboxWithTitle:)` controls, titled from the
      provider display names "Codex", "Claude Code" and "Mistral Vibe", and the window still sizes to
      fit.
    - **Panel:** `UsageStatusView` renders only enabled stores, and `refreshPassedRenewals` skips
      disabled ones. With none enabled, it shows the hint in the caption style.
    - **AppDelegate:**
      - `showHUD` refreshes only enabled stores.
      - Enabling a provider while the panel is visible refreshes it.
      - `makeMenu` omits "Show 5-hour limit" when Codex is off and "Set Vibe Monthly Budget…" when
        Vibe is off. Separators stay balanced.
    - No new SwiftUI controls (the AppKit checkboxes follow `47_project-ui-conventions.md`).
    - Tests cover the default, persistence round trip, toggling, and the enabled-stores filter as a
      pure helper.
  - Backpressure: `build-for-testing`; a fresh Debug build screenshot of Settings (no app control
    beyond the standing handoff).

### Wave 2 (parallel — disjoint; prerequisites integrated and validated)

- [x] **2.1**: Settings hotkey follows the layout (D5) — coordinator — `b088b6b` (AZERTY behaviour still gated by E1)
  - Depends on: 1.2 (`settings(using:)`), 1.4 (`AppDelegate.swift` integrated). External gates: E1 (AZERTY).
  - Owns: `AppDelegate.swift`.
  - Success:
    - `registerSettingsShortcut` uses `HotKeyShortcut.settings(using: .current)`.
    - While the panel shows, a `kTISNotifySelectedKeyboardInputSourceChanged` observer (distributed
      center, as in the recorder) re-registers the hotkey. The observer is removed when the panel
      hides and on terminate. The failure path logs as today.
  - Backpressure: `build-for-testing`. A unit test (in `HotKeyShortcutTests`, coordinator-added)
    covers `settings(using:)` with an AZERTY fake.

- [x] **2.2**: Vibe totals from session snapshots; rotation-proof; children fold (D1, D3) — `9ed0eb2` (real-store comparison matched; E1 check still open)
  - Depends on: 1.3. External gates: E1 (compare against Vibe's own numbers on this Mac).
  - Owns: `Vibe/VibeJournalAggregator.swift`, `Vibe/VibeUsageProvider.swift`, a new
    `Vibe/VibeSessionSnapshot.swift`, a new `Tests/Shared/Services/Vibe/VibeSessionSnapshotTests.swift`
    (both pre-created by the coordinator), and the existing Vibe tests and `SectionFixtures.swift`.
  - Success:
    - **Snapshot reader:** follows `CURRENT` → `generations/<gen>/manifest.json` →
      `projection-state.json`, or the chunked `projection_state.chunks` → `chunks/<sha>.json`, and
      reads `snapshot.session.tokenUsage`.
    - **Recovery journal:** the newest complete `set_envelope` `tokenUsage` in
      `manifest.recovery_journal_segment.path` overrides the snapshot. A trailing line without a
      newline is ignored.
    - **Errors:** no `try?`. A malformed snapshot falls back to journal sums for that session,
      logged as in the existing aggregator.
    - **Totals:** all-time totals and cost use the per-session `tokenUsage`.
    - **Sessions:** "Sessions" counts sessions whose `rootSessionId` is their own ID, or whose root
      is missing.
    - **Pricing:** children use their own model, otherwise the root's model.
    - **Windows:** the 24-hour and 7-day windows are unchanged apart from 1.3.
    - **Fixtures:**
      1. rotation (generations A and B, journal B+1 only; then generation C with segment A+1
         deleted, and the total never decreases);
      2. a live delta override plus a truncated line;
      3. chunked state;
      4. no `tokenUsage`, falling back to the journal;
      5. a child with its root present and a child with its root missing.
    - **Report:** the coordinator gets a one-off read-only comparison script result on this Mac:
      per-session app total compared with `tokenUsage.totalTokens`.
  - Backpressure: `build-for-testing`; comparison output in the report.

### Wave 3 (serial integration — shared docs and version files)

- [x] **3.1**: Docs, decisions, version (coordinator) — `efe5595`
  - Depends on: 1.1–1.4, 2.1, 2.2.
  - Owns: `Resources/Help/help-settings-and-shortcuts.md` (Providers section, layout-aware refusals,
    ISO key), `help-mistral-vibe.md` and `help-authoritative-vs-estimated.md` (what the Vibe numbers
    count; child sessions fold), `help-privacy-and-data.md` (a provider that is off is never read),
    `README.md:62` and its features list, `CHANGELOG.md [0.2.2]` (Fixed: Vibe double count and
    rotation; Changed: lower Vibe numbers explained; Added: provider on/off, ISO key; Fixed:
    layout-aware refusals, AZERTY Settings), `docs/decisions.md` (D1–D6),
    `project.yml` (0.2.2 / 202) + `xcodegen generate`.
  - Success: no "US key position" claim left outside CHANGELOG history; help manifest JSON valid;
    no shortcut glyphs; built Info.plist 0.2.2 / 202.
  - Backpressure: `jq . Resources/Help/help-manifest.json`; `grep -rn "US key position" 01_Project/Resources README.md`
    empty; `build-for-testing`.

- [x] **3.2**: Final verification, independent review, CI — Release build, review (fix `8822044`), CI green (244 tests); fresh Debug build handed off and launched 2026-11-11
  - Depends on: 3.1. External gates: push go-ahead (CI).
  - Owns: the review report; findings return to the owning task.
  - Success:
    - An unsigned universal Release build into scratch succeeds.
    - An independent `feature-dev:code-reviewer` review of the whole diff is done, with applicable
      findings fixed and checks re-run.
    - CI is green on the release-candidate commit, and the test count is at least 217 plus the new
      tests.
    - A fresh Debug build is handed off for E1 under the standing fresh-build authorization.
  - Backpressure: Release build log; CI run URL; review report.

## External checks

- [x] **E1**: Manual acceptance in a fresh Debug build (user-operated) — **passed 2026-11-11** (user reported all checks pass)
  - Depends on: 3.2. Gates: the UI, layout and Vibe acceptance criteria; E2.
  - Success:
    1. Settings shows Providers first. Untick Claude Code → the panel has no Claude section and the
       Console shows no Claude fetch. Untick all → hint. Re-tick → the section appears and refreshes.
       The Codex and Vibe menu items hide and show.
    2. German layout: Command-(Z keycap) refused, Command-(Y keycap) accepted; the ISO `<` key can be
       recorded with Control-Command.
    3. French layout, panel showing: Command plus the key that types `,` opens Settings.
    4. Vibe: totals are plausible against Vibe's own counters (2.2 report). Reopen later the same
       day → "Tokens (all time)" has not decreased. Sessions count is root sessions.
    5. About shows `Version 0.2.2 (202)`.
- [ ] **E2**: Notarize 0.2.2 (go-ahead — Apple, `99-AUTH` key)
  - Depends on: E1.
  - Success: clean tree; `scripts/notarize-release.sh 0.2.2` gives Accepted, stapled, `spctl`
    "Notarized Developer ID"; `dist/0.2.2/` has `SHA256SUMS.txt` and `SOURCE_COMMIT.txt`.
- [ ] **E3**: DMG and website (go-ahead — upload)
  - Depends on: E2.
  - Success: `scripts/package-dmg.sh 0.2.2` gives an Accepted DMG. Upload it, then update the page
    version (`data-field="version"`, released date) and the roster version, as for 0.2.1
    (App-Websites 94a8150). Live bytes match and `dl.php` serves 0.2.2. Commit in App-Websites;
    the README link stays valid.
- [ ] **E4**: Install and smoke test (go-ahead to replace `/Applications` copy; user-operated checks)
  - Depends on: E3.
  - Success: graceful quit of 0.2.1, install of the notarized 0.2.2, `spctl` ok, About 0.2.2 (202),
    and the provider toggles survive a relaunch.

---

## Operational Learnings

- zsh scripts: syntax-check with `zsh -n`, not `bash -n`.
- `release.sh` runs `xcodegen generate` and then requires a clean tree, so commit `project.pbxproj`
  before release runs.
- The Vibe store format is undocumented by Mistral (R2). Keep the journal fallback, and treat new
  store shapes as "fall back and log", never as a crash or a silent zero.

## Blocked Tasks

- None. D6 was confirmed by the user on 2026-11-10 (UI-changes protocol). Execution has not been
  requested yet.

---

## Execution Log

| Wave / task IDs | Assignments or serial reason | Validation / evidence | Commits or exception | Remaining gates / next action or stop reason |
|---|---|---|---|---|
| — | Plan written 2026-11-10 from two parallel research agents plus coordinator on-disk checks (`research/findings.md`); D3, D6 and the two deferrals decided by the user | — | — | Next: Wave 1 (1.1–1.4), once execution is requested |
| Wave 1 (1.1, 1.2, 1.3, 1.4), 2026-11-10 | 4 parallel `developer` agents with fresh context, exclusive file ownership, separate scratch DerivedData folders. Coordinator handled one cross-owner fix: 1.4's new `SettingsWindowController(preferences:)` argument in `ShortcutRecorderFieldTests.testWindowControllerSmoke` was made by the 1.2 owner and committed with 1.4 | Integrated `build-for-testing` **TEST BUILD SUCCEEDED**, no warnings. 237 test functions (217 + 20 new: 1.1 +2, 1.2 +11 (35 → 46), 1.3 +3, 1.4 +4). `grep 'try?' SectionStateCache.swift` empty. Tests not run locally (app-hosted; CI at 3.2). 1.3 finding: mistral-vibe `formats.py` (`TokenCounts`: "the cached and cache-written input are part of the input") → `cache_write_tokens` is no longer added. Source: https://github.com/mistralai/mistral-vibe/blob/main/harness/runtimes/python/python/mistralai_vibe_local_harness/vibe/completion_profile/formats.py | `2c11dbe` 1.4 · `c5fc548` 1.1 · `7175c92` 1.3 · `4421c67` 1.2 (each builds alone). Not pushed | 1.4: the Settings screenshot is still open. API notes for later waves: the failure type is `HotKeyShortcut.Rejection`; extras are `LayoutTranslator.init(map:)`, `.unavailable` and `ShortcutRecorderField(translator:)`; `UsagePreferences.providerIDs` and `enabledStores(_:enabled:)`. Next: Wave 2 (2.1 coordinator, 2.2 agent) |
| Wave 2 (2.1, 2.2), 2026-11-10 | 2.1 serial by coordinator (owns `AppDelegate.swift`); 2.2 by one `developer` agent with fresh context in parallel, exclusive Vibe files, separate scratch DerivedData. Coordinator pre-created `VibeSessionSnapshot.swift` and its test stub, then ran `xcodegen generate` | Integrated `build-for-testing` **TEST BUILD SUCCEEDED**. 244 test functions (237 + 7 new in `VibeSessionSnapshotTests`; Vibe 42 → 49). The 2.1 AZERTY test already existed from 1.2 (`HotKeyShortcutTests.swift:188`), so none was added. `grep 'try?' Vibe/*.swift` empty. Two Swift warnings in files outside this wave: `ShortcutRecorderField.swift:30` (unnecessary `nonisolated(unsafe)`) and `ClaudeLogAggregator.swift:144` (deprecated `init(cString:)`); not in the Wave 1 record, now in the TASKS Inbox. 2.2 real-store comparison (read-only, scripts in the session scratchpad `cmp/`): 36 sessions, app sum 168,838,748 equals Vibe's own `totalTokens` sum 168,838,748, 0 per-session mismatches; 12 root sessions. Store finding: `projection_state.chunks` hold only history, so counters always come from `projection-state.json`. The reader also folds in `projection_advanced` and `session_relocated` (as omarchy does). Tests not run locally (app-hosted; CI at 3.2) | `b088b6b` 2.1 · `9ed0eb2` 2.2 (with the project file). Not pushed | For 3.2 review: a session with no manifest logs a `.notice` on every refresh (fallback path); check this is acceptable. Next: Wave 3 (3.1 docs/version, then 3.2 review + CI, which needs a push go-ahead) |
| Wave 3 (3.1, 3.2), 2026-11-11 | Serial by coordinator (shared docs/version files). Independent review by one `feature-dev:code-reviewer` agent with fresh context (read-only) | 3.1: `jq` manifest ok; no "US key position" outside CHANGELOG history; no shortcut glyphs; `build-for-testing` **TEST BUILD SUCCEEDED**; built Info.plist 0.2.2 / 202. 3.2: unsigned universal Release build **BUILD SUCCEEDED** (`lipo`: x86_64 arm64; log in session scratchpad). Review: no defects; applied its suggestion (per-session snapshot-fallback `.notice` → `.debug`, count in the scan summary line); `build-for-testing` green again. Push authorized by the user; CI https://github.com/Xpycode/LLM-UsageStatus/actions/runs/43055174992 **success, 244 tests, 0 failures**. Fresh Debug build: `04_Exports/0.2.2-E1-Debug/DerivedData/Build/Products/Debug/LLM-UsageStatus.app`, 0.2.2 (202), ad-hoc, executable SHA-256 `69c96da4…a6ca14`, from `8822044` | `efe5595` 3.1 · `8822044` 3.2 review fix. Pushed to origin | Not launched: two 0.2.1 instances running (PID 17683 `/Applications`, PID 12734 `dist/0.2.1`); the standing handoff covers one identified instance, so the user chooses. Then E1 (user-operated, includes the 1.4 screenshot); E2–E4 need their own go-aheads |

---
*Keep active while required work or acceptance is incomplete. On completion, retire in place with
execution evidence and updated incoming links.*
