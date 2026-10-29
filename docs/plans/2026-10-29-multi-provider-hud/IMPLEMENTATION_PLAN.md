# Implementation Plan — Multi-Provider Usage HUD v1

> **Persists across sessions.** Execute using the shared `commands/execute.md` procedure.
> Repair scheduling errors while preserving task IDs, completed evidence and approved scope.
> Task state/evidence is authoritative here; TASKS links here and holds backlog/inbox.

**Progress:** 0/13; external acceptance: E1 (fresh-build smoke test), E2 (notarized 0.1.0 release).
**Task states:** unchecked = pending / implemented-unverified / blocked (name gate);
checked = complete with required evidence. Task identity includes this plan path plus ID.

## Goal

A dockless macOS HUD, toggled by Control-Option-Command-L, showing one usage section per provider —
Codex (authoritative allowance), Claude Code (OAuth-endpoint utilization, local-log fallback),
Mistral Vibe (local token aggregates, conditional cost line) — with zero user configuration.

Journey: CLI-owned local files + Codex/Claude endpoints → hotkey toggle → NSPanel HUD with three
independent sections → user sees current numbers per installed CLI; missing CLIs show "not detected".

## Acceptance Criteria

Derived from `specs/multi-provider-usage-hud.md` (authoritative there; all of its core/edge/error
criteria must pass). Summary:

- [ ] All three sections populate from existing CLI data with no configuration; absent CLIs show "not detected"
- [ ] Codex section matches CodexUsageStatus semantics (allowance, credits, resets, optional 5-hour)
- [ ] Claude section: OAuth endpoint primary (five-hour/seven-day utilization + resets_at), labeled local fallback
- [ ] Vibe section: token aggregates from the unified session store; cost line only when prices resolve
- [ ] Per-provider failure isolation; failed refresh retains prior values with safe error copy
- [ ] Hotkey toggle + registration-failure fallback menu; refresh on open; malformed lines skip-counted

## Specs

- `specs/multi-provider-usage-hud.md` — v1 specification (approved, open questions resolved)

## Research annex (evidence behind the plan)

- CUS architecture digest: which files lift verbatim vs rewrite (UsagePanelController, GlobalHotKey,
  UsageStore seam; UsageSnapshot/UsageStatusContent are Codex-shaped and get a normalized replacement).
- Claude endpoint: `GET https://api.anthropic.com/api/oauth/usage`, headers
  `Authorization: Bearer <token>` + `anthropic-beta: oauth-2025-04-20`, schema
  `five_hour{utilization,resets_at}`, `seven_day{utilization,resets_at}`; token in Keychain
  (`Claude Code-credentials` service, per-install suffixed variants; verified present locally).
  Poll sparingly (429 reports); `claude setup-token` tokens get 403 (inference-only scope).
- Vibe: journal `usage` fields (input/output/cached/reasoning/total); no self-serve Mistral usage API;
  official prices for the bundled rate card (cached input = 10% of input).
- Full subagent reports in scratchpad: `cus-architecture-digest.md`, `claude-limits-research.md`,
  `vibe-pricing-research.md`.

---

## Execution schedule and ownership

- Execution scope/limits: planning approved by user request; execution not yet requested.
- Coordinator-owned files/resources: `01_Project/project.yml` (folder globs — new files need no
  edits; coordinator owns any project.yml change), `01_Project` XcodeGen generation, build/test
  directories, Git, `docs/` state files.
- Interfaces to establish before dispatch: task 1.2's `Provider` protocol + normalized
  `ProviderSection` display model is the contract consumed by 2.1–2.3 and conformed to by every
  provider service.

## Tasks

### Wave 1 (parallel — no dependencies, exclusive ownership)

- [ ] **1.1**: App shell scaffold -> `01_Project/project.yml`, `01_Project/Resources/LLM-UsageStatus.entitlements`, `01_Project/Sources/App/*`
  - Depends on / external gates: none
  - Owns: `Sources/App/` (App entry, AppDelegate, GlobalHotKey, UsagePanelController), `project.yml`, entitlements; `Tests/App/`
  - Interface: `UsagePanelController` + `GlobalHotKey` APIs (ported from CUS: AppDelegate.swift:10-109, GlobalHotKey.swift:43-47, UsagePanelController.swift:49-156); hotkey Control-Option-Command-L (`kVK_ANSI_L`, fresh Carbon signature); placeholder content view showing static text so the shell is independently demonstrable
  - Success: `xcodegen generate` + build succeeds; app launches dockless, hotkey toggles the placeholder panel, click-away dismisses, drag moves it; hotkey failure shows the status-item fallback
  - Backpressure: `xcodebuild ... build` + `GlobalHotKeyTests` port (Backend injection, install-once/retry/release semantics)

- [ ] **1.2**: Provider abstraction and store generalization -> `01_Project/Sources/Shared/Models/ProviderModels.swift`, `01_Project/Sources/Features/UsageStatus/UsageStore.swift`
  - Depends on / external gates: none
  - Owns: `ProviderModels.swift` (Provider protocol, normalized section display model with rows/meters/deadlines/estimation flags), `UsageStore.swift`; `Tests/Shared/Models/`, `Tests/Features/UsageStatus/UsageStoreTests.swift`
  - Interface: the contract for all providers (conformance target) and the multi-provider store API used by the composition root
  - Success: protocol + display model compile with unit tests covering invariants (estimate flags, deadline sets, unavailable states, safe-error contract); store retains reentrancy guard and safe-string-only error publication from CUS
  - Backpressure: targeted `xcodebuild ... test -only-testing:LLM-UsageStatusTests/ProviderModels` (+ store tests)

- [ ] **1.3**: Codex provider port -> `01_Project/Sources/Shared/Services/CodexUsageService.swift`, `UsageResponseDecoder.swift`, `01_Project/Sources/Shared/Models/UsageSnapshot.swift`
  - Depends on / external gates: none
  - Owns: Codex service + decoder + snapshot files; `Tests/Shared/Services/CodexUsageServiceTests.swift`, `UsageResponseDecoderTests.swift`, `Tests/Shared/Models/UsageSnapshotTests.swift`
  - Interface: CUS-equivalent public API (injected Transport/AuthInput/now; `GET chatgpt.com/backend-api/wham/usage`; safe `FetchError` enum) — conformance to 1.2's protocol happens in 2.1
  - Success: verbatim-port tests pass (URL/headers/timeouts, decoder edge cases incl. rounding traps and reset reconciliation, snapshot invariants); no credential-logging paths
  - Backpressure: `xcodebuild ... test -only-testing:LLM-UsageStatusTests/CodexUsageServiceTests` (+ decoder/snapshot tests)

- [ ] **1.4**: Claude data sources -> `01_Project/Sources/Shared/Services/Claude/ClaudeOAuthUsageService.swift`, `ClaudeLogAggregator.swift`, `ClaudeTokenProvider.swift`
  - Depends on / external gates: none
  - Owns: `Sources/Shared/Services/Claude/**`; `Tests/Shared/Services/Claude/**`
  - Interface: `ClaudeOAuthUsageService` (injectable Transport + token provider + now; endpoint `GET api.anthropic.com/api/oauth/usage`, headers `Authorization: Bearer` + `anthropic-beta: oauth-2025-04-20`; strict decoding of `five_hour`/`seven_day` utilization + `resets_at`; 429 and 403 map to safe errors) and `ClaudeLogAggregator` (line-by-line JSONL parse of `~/.claude/projects/**/*.jsonl`, malformed lines skipped and counted, session + rolling 7-day aggregates, timestamps respected)
  - Success: scripted-transport tests pass (headers, error sanitization, 429 mapping); aggregator fixture tests pass (correct sums, malformed-line skip-counting, empty-dir handling); `ClaudeTokenProvider` reads Keychain items (`Claude Code-credentials` and suffixed variants) with denial/absence mapped to a "local-only" mode — no credential content in any test or log
  - Backpressure: `xcodebuild ... test -only-testing:LLM-UsageStatusTests/Claude`
  - Risk note: Keychain ACL may prompt or deny on first read — the provider must degrade to local-only mode, never fail the section

- [ ] **1.5**: Vibe journal aggregator + rate card -> `01_Project/Sources/Shared/Services/Vibe/VibeJournalAggregator.swift`, `MistralRateCard.swift`
  - Depends on / external gates: none
  - Owns: `Sources/Shared/Services/Vibe/**`; `Tests/Shared/Services/Vibe/**`
  - Interface: `VibeJournalAggregator` (reads `~/.vibe/logs/session/unified/*/journal/*.jsonl`; `store_format` gate; per-response `usage` rows summed into input/output/cached/reasoning totals; malformed lines skipped and counted; rolling aggregates by `meta.json`/row timestamps) and `MistralRateCard` (bundled table incl. Medium 3.5 $1.50/$0.15/$7.50 per 1M, cached = 10% of input; resolves model name → price triple, cache priced at cached rate)
  - Success: fixture tests pass (synthetic journal lines: sums, cache-vs-input pricing, malformed rows, empty store); rate-card resolution tests pass (known model resolves, unknown returns nil)
  - Backpressure: `xcodebuild ... test -only-testing:LLM-UsageStatusTests/Vibe`

### Wave 2 (serial integration)

- [ ] **2.1**: Multi-provider HUD with Codex live -> `01_Project/Sources/Features/UsageStatus/Views/UsageStatusView.swift`, `AppDelegate` composition wiring
  - Depends on: 1.1 (shell), 1.2 (protocol/store), 1.3 (Codex service)
  - External gates: none
  - Owns: `Sources/Features/UsageStatus/Views/**`, the AppDelegate composition-root edit (services → providers → stores → panel)
  - Interface: per-provider section rendering from the normalized model (rows/meters/deadlines/estimate labels), one store per provider, refresh-on-open
  - Success: HUD shows the Codex section end-to-end through the provider path (build → hotkey → refresh → rows); a provider fetch failure shows safe copy and retains prior values; placeholder content removed
  - Backpressure: full `xcodebuild ... build` + app test suite green
- [ ] **2.2**: Claude and Vibe sections live
  - Depends on: 2.1 (section interface), 1.4, 1.5
  - External gates: none
  - Owns: Claude/Vibe provider conformance files (inside their service dirs), their section content within the views, composition-root wiring for the two stores
  - Interface: complete three-provider HUD
  - Success: all three sections populate; Claude shows endpoint utilization with `resets_at`, degrades to labeled local aggregates when the token is unavailable; Vibe shows token totals and a cost line only when the rate card resolves; absent CLIs show "not detected"; estimate labels visible wherever fallback data is shown
  - Backpressure: full app test suite green; fixture-driven section-state unit tests pass
- [ ] **2.3**: Preferences, renewal timers, state parity -> `Sources/Features/UsageStatus/UsagePreferences.swift`, views, AppDelegate menu
  - Depends on: 2.2
  - External gates: none
  - Owns: `UsagePreferences.swift` (per-provider persisted toggles), right-click menu, generalized `refreshPassedRenewals`, stale/failed caption cluster
  - Interface: none (polish of established surfaces)
  - Success: Codex 5-hour toggle persists across restarts and updates the open panel; renewal countdowns request one refresh per passed deadline for any provider's deadline set; stale/last-updated captions per section; copy uses the new app name and Command-spelled shortcuts
  - Backpressure: full app test suite green (incl. preferences tests)

### Wave 3 (parallel)

- [ ] **3.1**: Release pipeline and repo surface -> `scripts/release.sh`, `scripts/notarize-release.sh`, `.github/workflows/ci.yml`, `README.md`, `LICENSE`, `CHANGELOG.md`
  - Depends on: 2.3
  - External gates: none (E2 gates actual publication)
  - Owns: `scripts/`, `.github/`, root README/LICENSE/CHANGELOG
  - Interface: release scripts app-name-templated (LLM-UsageStatus, com.sim.LLM-UsageStatus)
  - Success: `release.sh 0.1.0` dry-run builds a universal unsigned artifact with matching CFBundleShortVersionString and refuses to overwrite an existing version dir; CI workflow runs build+tests on push
  - Backpressure: script dry-run evidence retained; CI green on push
- [ ] **3.2**: Full verification and fixture visuals -> `docs/verification/2026-10-29-multi-provider-hud/`
  - Depends on: 2.3
  - External gates: none
  - Owns: verification evidence directory
  - Interface: none
  - Success: full `xcodebuild ... test` green; preview-based fixture renders of every section state (populated, unavailable, not-detected, stale, estimate-fallback) checked in; results summarized in the execution log
  - Backpressure: full test suite + rendered fixtures

## External checks

- [ ] **E1**: Fresh-build smoke test (user-operated)
  - Depends on: 3.2
  - Requires: user at this Mac; per the user's fresh-build handoff authorization the agent launches the exact fresh artifact after a successful build
  - Owns: acceptance evidence for the spec's core criteria
  - Gates: v1 acceptance (spec core criteria), and E2 readiness
  - Success / verification: hotkey toggles; all installed providers' sections populate live (Codex, Claude, Vibe on this Mac); absent-provider state verified by path manipulation in a test fixture; no credentials prompted or stored
  - While unavailable: 3.1/3.2 claims remain "implemented, not user-verified"
- [ ] **E2**: Signed + notarized 0.1.0 release accepted
  - Depends on: E1
  - Requires: Developer ID signing credentials, notarytool key (per `61_distribution-notarization.md` at release time); explicit user go-ahead to publish
  - Owns: release evidence (dist/0.1.0 artifacts, notarization.json, SHA256SUMS)
  - Gates: publication
  - Success / verification: `notarize-release.sh 0.1.0` completes with Apple verdict `Accepted`, stapled, spctl passes; user smoke-tests the released artifact
  - While unavailable: app is usable via unsigned dev builds only

## Operational Learnings

- (none yet — add as discovered; route shared learnings to canonical docs)

## Blocked Tasks

- (none)

---

## Execution Log

| Wave / task IDs | Assignments or serial reason | Validation / evidence | Commits or exception | Remaining gates / next action or stop reason |
|---|---|---|---|---|
| Plan created 2026-10-29 | Research: 3 subagents (web + local) resolved all 5 spec open questions | Reports linked in research annex | — | Execution not yet requested; Wave 1 all-ready |

---

*Keep active while required work or acceptance is incomplete.*
