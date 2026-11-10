# 0.2.2 research findings (2026-11-10)

Two parallel research agents (code + web), coordinator spot-checks on this Mac. No project files
were edited during research.

## R1 — Backlog #12: positional shortcut refusals

**Current state**
- `HotKeyShortcut.validate()` (`Sources/App/HotKeyShortcut.swift:73-80`): order = supported key
  (`keyNames`, 101-139) → Command or Control → `== .settings` (`kVK_ANSI_Comma` + Command, 13-16) →
  Command(+Shift) on `systemKeyCodes` (84-88: US positions A C F H M N O P Q S T V W X Z 3 4 5,
  Space, Tab, Grave).
- Two callers: the recorder (`ShortcutRecorderField.swift:122`) and the stored-value read
  `HotKeyShortcutStore.current` (`HotKeyShortcut.swift:157`), which silently falls back to the
  default when the stored chord fails validation.
- `kVK_ISO_Section` (0x0A) is missing from `keyNames`, so the ISO `<` key is "unsupported".
- `KeyboardLayoutNames.current` (`KeyboardLayoutNames.swift:13-31`): ASCII-capable layout
  (`TISCopyCurrentASCIICapableKeyboardLayoutInputSource`), `kUCKeyActionDisplay`, modifiers 0,
  `LMGetKbdType()`, no dead keys; key code → character only; uncached; only the recorder observes
  layout changes (`ShortcutRecorderField.swift:65-69`).
- **Second bug:** the Settings hotkey registers at the US Comma position (`AppDelegate.swift:56-58`).
  On French AZERTY that key types `;` — Command-; opens Settings and the real Command-, does not.
- Refusal text (`ShortcutRecorderField.swift:139-146`): "Command-Comma is reserved for Settings." /
  "That shortcut is used by macOS and other apps."
- "US key position" docs: `Resources/Help/help-settings-and-shortcuts.md:18`, `README.md:62`
  (`CHANGELOG.md:55` is history — leave).
- Tests to update: `HotKeyShortcutTests` (19; lines 115, 123, 127, 162),
  `ShortcutRecorderFieldTests` (16; lines 45, 104). `GlobalHotKeyTests` unaffected.

**Prior art (web)**
- sindresorhus/KeyboardShortcuts: system-hotkey check via enabled `CopySymbolicHotKeys` entries by key
  code; menu conflicts by character; ASCII-capable layout, modifiers 0.
  https://github.com/sindresorhus/KeyboardShortcuts/blob/main/Sources/KeyboardShortcuts/Shortcut.swift
- Kentzo ShortcutRecorder: same split (symbolic hotkeys by code, menus by key equivalent).
  https://github.com/Kentzo/ShortcutRecorder/blob/master/Sources/ShortcutRecorder/SRShortcutValidator.m
- App shortcuts (Copy, Undo, Settings) are character-defined; macOS 12+ also localizes menu key
  equivalents (`NSMenuItem.allowsAutomaticKeyEquivalentLocalization`).
  https://developer.apple.com/documentation/appkit/nsmenuitem/allowsautomatickeyequivalentlocalization
- ISO keyboards swap `kVK_ISO_Section` / `kVK_ANSI_Grave` codes on some layouts (Mozilla bug 1263302);
  harmless here because we register the code the key event reports — block both codes for
  Command-only chords.

**Design (adopted in the plan):** injectable `LayoutTranslator` (character for key code with Command
state; key code for character); recorder refuses Command(+Shift) on whatever key *types* a, c, f, h,
m, n, o, p, q, s, t, v, w, x, z, 3, 4, 5 (plus Space, Tab, Grave/Section by code); "reserved" =
Command + the key that types `,`; Settings hotkey registers at that key and follows layout changes;
ISO Section supported; translator nil/empty/multi-char → today's US-position set. The stored-value
check stays structural only, so a layout switch never silently resets a saved shortcut.

Deferred (user, 2026-11-10): refusing enabled `CopySymbolicHotKeys` system hotkeys → new backlog item.

## R2 — Vibe "Tokens (all time)" fluctuation

**Root cause = aggregation bug (two defects), not a label problem.** High confidence; verified on disk.

1. **Rotation loss.** The aggregator sums `action_result` usage rows in
   `~/.vibe/logs/session/unified/<session>/journal/*.jsonl` (`VibeJournalAggregator.swift:176-206`,
   extraction 287-317). The store retains 2 generations and deletes older journal segments
   (`_RETAINED_GENERATIONS = 2`, `_discard_superseded` in mistralai/mistral-vibe `_storage.py`).
   Coordinator check: session 3d2162b7's journal holds only segments 1448 and 1508. Each rotation
   drops a segment → the total falls (46.9M → 35.2M) with an unchanged session count.
2. **Double counting.** Coordinator check over all 776 local usage rows: `cached_input_tokens ≤
   input_tokens`, `reasoning_tokens ≤ output_tokens`, `total_tokens == input + output` in **every**
   row, so cached ⊂ input and reasoning ⊂ output. `VibeUsageProvider.totalTokens` (214-216) adds all
   four (~2×), and `VibeRateCard.cost` (44-48) charges cached tokens at full input price **and** again
   at the cached price → with ~95 % cache hits the cost row and budget headline are ~7–8× too high.
   The fixture `VibeJournalAggregatorTests.swift:24` (input 100 / cached 5 120) encodes the wrong
   assumption. `cache_write_tokens` is 0 in every local row (semantics unverified).

**Authoritative source on disk:** `CURRENT` → `generations/<gen>/manifest.json` →
`projection-state.json` (or chunked `manifest.projection_state.chunks` → `chunks/<sha>.json`) →
`snapshot.session.tokenUsage {inputTokens, cachedInputTokens, outputTokens, totalTokens}` —
cumulative, monotonic per session (rose across both kept generations in all 32 sessions;
`compaction_count` 0 everywhere). Newer usage arrives in the recovery journal
(`manifest.recovery_journal_segment.path`) as `projection_delta` `set_envelope` records whose
`state.session.tokenUsage` is complete — the newest wins; a trailing line without a newline is a
record still being written and must be ignored. Third-party reader doing exactly this:
omacom/omarchy `bin/omarchy-agent-usage-vibe` (`unified_state`, `parse_unified`).
Mistral documents none of this (3.0.0 notes:
https://newreleases.io/project/pypi/mistral-vibe/release/3.0.0) — format drift is a standing risk.

**Children.** 24 of 32 local sessions are sub-agent children (`child-*`, no `meta.json`) carrying
`snapshot.session.rootSessionId` / `parentSessionId`. Coordinator check: a root's counter does **not**
include its children (root 77e752bb 2.79M vs children 4.98M), so totals = sum over all sessions;
only the *session count* folds children into roots (user decision 2026-11-10). A child whose root
is not in the store counts as its own session.

**Store totals now:** current code 128.9M; snapshot sum 167.2M (double count + rotation loss net).

**Known limit kept:** 24-hour / 7-day windows stay journal-based (only rows carry timestamps); they
get the inclusive-field fix but can still miss rows rotated out of long sessions — already labeled
estimates.

Deferred (user, 2026-11-10): the monthly-budget headline uses all stored cost instead of cost since
the reset day (`VibeUsageProvider.swift:179`) → new backlog item (needs a time-window design).

Agent scratch scripts (not project files):
`/private/tmp/claude-501/-Users-sim-ProgrammingProjects-1-macOS-LLM-UsageStatus/8f944413-f045-42e2-b8d4-4f140fe78807/scratchpad/`
(`vibe_cmp.py`, `storage.py`, `omarchy.py`).

## R3 — Backlog #13: `try?` in SectionStateCache

`Sources/Features/UsageStatus/SectionStateCache.swift` lines 28, 29, 42, 43, 44 use `try?`. A
missing file on first launch is normal (must not log as an error); unreadable/corrupt reads and
failed directory/encode/write must log via `Logger` (subsystem `com.sim.LLM-UsageStatus`, as in
`HelpSupport.swift:9`). The empty-cache fallback and "never surfaces as an error" contract stay.
