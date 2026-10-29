# Implementation Plan — Multi-Provider Usage HUD v1

> **Persists across sessions.** Execute using the shared `commands/execute.md` procedure.
> Repair scheduling errors while preserving task IDs, completed evidence and approved scope.
> Task state/evidence is authoritative here; TASKS links here and holds backlog/inbox.

**Progress:** 13/13 (all code tasks complete); external acceptance: E1 (fresh-build smoke test), E2 (notarized 0.1.0 release).
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
  `five_hour{utilization,resets_at}`, `seven_day{utilization,resets_at}` — plus additional buckets
  (per-model weekly windows, `extra_usage`), so decode tolerantly; `resets_at` format unpinned
  (ISO-8601 vs epoch seconds — determine empirically); token in Keychain (service
  `Claude Code-credentials`, suffixed variant `Claude Code-credentials-<sha256(CLAUDE_CONFIG_DIR)[:8]>`
  when `CLAUDE_CONFIG_DIR` is set — probe suffixed then unsuffixed; verified present locally).
  Poll sparingly (429 reports); `claude setup-token` tokens get 403 (requires `user:profile` scope).
- Vibe: journal `usage` fields (input/output/cached/reasoning/total, plus `cache_write_tokens`);
  usage rows carry no timestamp (`core_input` rows carry `time_unix_ms`; `meta.json` — with
  `start_time`/`end_time` and `model_name` — exists only for completed top-level sessions, never for
  child sessions); `store_format` lives in each session's `CURRENT` file. No self-serve Mistral
  usage API (Enterprise-only Admin API is sales-gated); official prices for the bundled rate card
  (per-model triples; cached = 10% of input holds for Mistral-owned models only).
- Full subagent reports in scratchpad: `cus-architecture-digest.md`, `claude-limits-research.md`,
  `vibe-pricing-research.md`.
- Plan review 2026-10-29: all annex claims re-verified (two web-verification subagents + local
  inspection of CUS sources, the unified store and Keychain metadata); refinements folded into
  tasks 1.4, 1.5 and 2.1.

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

- [x] **1.1**: App shell scaffold -> `01_Project/project.yml`, `01_Project/Resources/LLM-UsageStatus.entitlements`, `01_Project/Sources/App/*`
  - Depends on / external gates: none
  - Owns: `Sources/App/` (App entry, AppDelegate, GlobalHotKey, UsagePanelController), `project.yml`, entitlements; `Tests/App/`
  - Interface: `UsagePanelController` + `GlobalHotKey` APIs (ported from CUS: AppDelegate.swift:10-109, GlobalHotKey.swift:43-47, UsagePanelController.swift:49-156); hotkey Control-Option-Command-L (`kVK_ANSI_L`, fresh Carbon signature); placeholder content view showing static text so the shell is independently demonstrable
  - Success: `xcodegen generate` + build succeeds; app launches dockless, hotkey toggles the placeholder panel, click-away dismisses, drag moves it; hotkey failure shows the status-item fallback
  - Backpressure: `xcodebuild ... build` + `GlobalHotKeyTests` port (Backend injection, install-once/retry/release semantics)

- [x] **1.2**: Provider abstraction and store generalization -> `01_Project/Sources/Shared/Models/ProviderModels.swift`, `01_Project/Sources/Features/UsageStatus/UsageStore.swift`
  - Depends on / external gates: none
  - Owns: `ProviderModels.swift` (Provider protocol, normalized section display model with rows/meters/deadlines/estimation flags), `UsageStore.swift`; `Tests/Shared/Models/`, `Tests/Features/UsageStatus/UsageStoreTests.swift`
  - Interface: the contract for all providers (conformance target) and the multi-provider store API used by the composition root
  - Success: protocol + display model compile with unit tests covering invariants (estimate flags, deadline sets, unavailable states, safe-error contract); store retains reentrancy guard and safe-string-only error publication from CUS
  - Backpressure: targeted `xcodebuild ... test -only-testing:LLM-UsageStatusTests/ProviderModels` (+ store tests)

- [x] **1.3**: Codex provider port -> `01_Project/Sources/Shared/Services/CodexUsageService.swift`, `UsageResponseDecoder.swift`, `01_Project/Sources/Shared/Models/UsageSnapshot.swift`
  - Depends on / external gates: none
  - Owns: Codex service + decoder + snapshot files; `Tests/Shared/Services/CodexUsageServiceTests.swift`, `UsageResponseDecoderTests.swift`, `Tests/Shared/Models/UsageSnapshotTests.swift`
  - Interface: CUS-equivalent public API (injected Transport/AuthInput/now; `GET chatgpt.com/backend-api/wham/usage`; safe `FetchError` enum) — conformance to 1.2's protocol happens in 2.1
  - Success: verbatim-port tests pass (URL/headers/timeouts, decoder edge cases incl. rounding traps and reset reconciliation, snapshot invariants); no credential-logging paths
  - Backpressure: `xcodebuild ... test -only-testing:LLM-UsageStatusTests/CodexUsageServiceTests` (+ decoder/snapshot tests)

- [x] **1.4**: Claude data sources -> `01_Project/Sources/Shared/Services/Claude/ClaudeOAuthUsageService.swift`, `ClaudeLogAggregator.swift`, `ClaudeTokenProvider.swift`
  - Depends on / external gates: none
  - Owns: `Sources/Shared/Services/Claude/**`; `Tests/Shared/Services/Claude/**`
  - Interface: `ClaudeOAuthUsageService` (injectable Transport + token provider + now; endpoint `GET api.anthropic.com/api/oauth/usage`, headers `Authorization: Bearer` + `anthropic-beta: oauth-2025-04-20`; decode `five_hour`/`seven_day` utilization + `resets_at` while tolerating unknown keys — the real response also carries per-model weekly windows and `extra_usage`; determine the `resets_at` format empirically (ISO-8601 vs epoch seconds, community reports conflict); 429 and 403 map to safe errors) and `ClaudeLogAggregator` (line-by-line JSONL parse of `~/.claude/projects/**/*.jsonl`, malformed lines skipped and counted, session + rolling 7-day aggregates, timestamps respected)
  - Success: scripted-transport tests pass (headers, error sanitization, 429 mapping, unknown-key tolerance); aggregator fixture tests pass (correct sums, malformed-line skip-counting, empty-dir handling); `ClaudeTokenProvider` reads Keychain items — probe suffixed service `Claude Code-credentials-<sha256(CLAUDE_CONFIG_DIR)[:8]>` (present when `CLAUDE_CONFIG_DIR` is set) then unsuffixed `Claude Code-credentials` — with denial/absence mapped to a "local-only" mode — no credential content in any test or log
  - Backpressure: `xcodebuild ... test -only-testing:LLM-UsageStatusTests/Claude`
  - Risk note: Keychain ACL may prompt or deny on first read — the provider must degrade to local-only mode, never fail the section

- [x] **1.5**: Vibe journal aggregator + rate card -> `01_Project/Sources/Shared/Services/Vibe/VibeJournalAggregator.swift`, `MistralRateCard.swift`
  - Depends on / external gates: none
  - Owns: `Sources/Shared/Services/Vibe/**`; `Tests/Shared/Services/Vibe/**`
  - Interface: `VibeJournalAggregator` (reads `~/.vibe/logs/session/unified/*/journal/*.jsonl`; `store_format` gate from each session's `CURRENT` file; per-response `usage` rows summed into input/output/cached/reasoning totals, with `cache_write_tokens` folded into the input total and never counted twice; malformed lines skipped and counted; timestamp attribution: usage rows carry no own timestamp — use the paired `core_input` row's `time_unix_ms` where present, else the journal file's mtime, else whole-session attribution from `meta.json` (which exists only for completed top-level sessions, never for child sessions); rolling windows degrade to session totals when no timestamp resolves) and `MistralRateCard` (bundled per-model price triples — input, cached, output — e.g. Medium 3.5 $1.50/$0.15/$7.50 per 1M; store the cached price per model rather than deriving 10% universally; resolves model name → price triple, model name taken from the session's `meta.json` when present, cache priced at cached rate)
  - Success: fixture tests pass (synthetic journal lines: sums, cache-vs-input pricing, cache_write folding, malformed rows, empty store, timestamp-attribution fallbacks incl. sessions without `meta.json`); rate-card resolution tests pass (known model resolves, unknown or missing model name returns nil)
  - Backpressure: `xcodebuild ... test -only-testing:LLM-UsageStatusTests/Vibe`

### Wave 2 (serial integration)

- [x] **2.1**: Multi-provider HUD with Codex live -> `01_Project/Sources/Features/UsageStatus/Views/UsageStatusView.swift`, `AppDelegate` composition wiring
  - Depends on: 1.1 (shell), 1.2 (protocol/store), 1.3 (Codex service)
  - External gates: none
  - Owns: `Sources/Features/UsageStatus/Views/**`, the Codex `Provider` conformance extension in `Sources/Shared/Services/` (the one edit to 1.3-owned files, coordinated as Wave 2 serial work), the AppDelegate composition-root edit (services → providers → stores → panel)
  - Interface: per-provider section rendering from the normalized model (rows/meters/deadlines/estimate labels), one store per provider, refresh-on-open
  - Success: HUD shows the Codex section end-to-end through the provider path (build → hotkey → refresh → rows); a provider fetch failure shows safe copy and retains prior values; placeholder content removed
  - Backpressure: full `xcodebuild ... build` + app test suite green
- [x] **2.2**: Claude and Vibe sections live
  - Depends on: 2.1 (section interface), 1.4, 1.5
  - External gates: none
  - Owns: Claude/Vibe provider conformance files (inside their service dirs), their section content within the views, composition-root wiring for the two stores
  - Interface: complete three-provider HUD
  - Success: all three sections populate; Claude shows endpoint utilization with `resets_at`, degrades to labeled local aggregates when the token is unavailable; Vibe shows token totals and a cost line only when the rate card resolves; absent CLIs show "not detected"; estimate labels visible wherever fallback data is shown
  - Backpressure: full app test suite green; fixture-driven section-state unit tests pass
- [x] **2.3**: Preferences, renewal timers, state parity -> `Sources/Features/UsageStatus/UsagePreferences.swift`, views, AppDelegate menu
  - Depends on: 2.2
  - External gates: none
  - Owns: `UsagePreferences.swift` (per-provider persisted toggles), right-click menu, generalized `refreshPassedRenewals`, stale/failed caption cluster
  - Interface: none (polish of established surfaces)
  - Success: Codex 5-hour toggle persists across restarts and updates the open panel; renewal countdowns request one refresh per passed deadline for any provider's deadline set; stale/last-updated captions per section; copy uses the new app name and Command-spelled shortcuts
  - Backpressure: full app test suite green (incl. preferences tests)

### Wave 3 (parallel)

- [x] **3.1**: Release pipeline and repo surface -> `scripts/release.sh`, `scripts/notarize-release.sh`, `.github/workflows/ci.yml`, `README.md`, `LICENSE`, `CHANGELOG.md`
  - Depends on: 2.3
  - External gates: none (E2 gates actual publication)
  - Owns: `scripts/`, `.github/`, root README/LICENSE/CHANGELOG
  - Interface: release scripts app-name-templated (LLM-UsageStatus, com.sim.LLM-UsageStatus)
  - Success: `release.sh 0.1.0` dry-run builds a universal unsigned artifact with matching CFBundleShortVersionString and refuses to overwrite an existing version dir; CI workflow runs build+tests on push
  - Backpressure: script dry-run evidence retained; CI green on push
- [x] **3.2**: Full verification and fixture visuals -> `docs/verification/2026-10-29-multi-provider-hud/`
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
| Plan review 2026-10-29 | 2 web-verification subagents (Claude OAuth, Mistral pricing) + local verification (CUS refs, unified store, Keychain metadata) | All claims confirmed; refinements folded into 1.4/1.5/2.1 and the annex | — | Plan review passed; Wave 1 ready on user request |
| Wave 1 (1.1–1.5) 2026-10-29 | 5 parallel fresh-context agents (shell, provider abstraction, Codex verbatim port, Claude sources, Vibe aggregator); coordinator integration | `xcodegen generate` + `xcodebuild build` SUCCEEDED; full `xcodebuild test` (app-hosted, user-authorized) 91/91 green — covers every task's backpressure suite (GlobalHotKey, ProviderModels, UsageStore, Codex/decoder/snapshot, Claude OAuth+aggregator, Vibe aggregator+rate card); app-hosted launch evidences dockless launch + hotkey registration; 1.1's interactive panel behaviors are verbatim CUS ports, full confirmation folds into E1 | "Wave 1: HUD shell + provider abstraction + Codex/Claude/Vibe data sources" (+ coordinator fixes: missing try, NSDirectoryEnumerator async-context fix, realpath session-id fix in Claude aggregator) | Wave 2 ready (2.1 after 1.1–1.3, then 2.2, 2.3); E1/E2 open |
| Wave 2 (2.1→2.2→2.3) 2026-10-29 | Serial coordinator execution — integration tasks share the views/composition-root surface, so no independent fresh-context work existed; delegation offered no benefit | `xcodegen generate` + full `xcodebuild test` (app-hosted, user-authorized for this wave) green at each task boundary: 98/98 (2.1), 112/112 (2.2), 116/116 (2.3) — new coverage: CodexUsageProviderTests (identity, section mapping incl. resets/expiry/unlimited/zero-passes, error→state mapping), ClaudeUsageProviderTests (endpoint meters/deadlines incl. both resets_at formats, labeled local fallback, not-detected, 403 fallback, 429 retains unavailable, transport failure), VibeUsageProviderTests (scan rows + cost when model resolves, cost omitted when unresolvable, unattributed windows flagged as estimates, skipped/malformed notes, absent/empty store), UsagePreferencesTests (injected defaults suite) | Three task commits: "Wave 2 task 2.1: multi-provider HUD views, Codex provider conformance, composition root" (62cc4ae), "Wave 2 task 2.2: Claude and Vibe sections live" (aa94c96), "Wave 2 task 2.3: preferences, renewal timers, menu parity" (bbdd5e6) | Wave 3 ready (3.1 and 3.2 after 2.3); E1/E2 open. Note: meters render utilization ("X% used") rather than CUS's "X% remaining" — the normalized model carries one utilization fraction for all providers; E1 acceptance can revisit wording. Interactive behaviors (hotkey toggle, live sections populating, restart) fold into E1 |
| Wave 3 (3.1 ∥ 3.2) 2026-10-29 | 2 parallel fresh-context agents (release pipeline; verification/renders) — disjoint file ownership; coordinator integrated + committed. Same-session preamble: Claude endpoint diagnosis closed (401 = stale stored token; implementation verified end-to-end; labeled fallback engaged as designed; endpoint stays primary) — commit 38ecefb | 3.1: real `release.sh 0.1.0` run — universal unsigned build (`lipo`: x86_64 arm64), CFBundleShortVersionString 0.1.0 match, second run refuses overwrite (exit 1); `zsh -n` on both scripts; notarize script NOT executed (E2 credentials). CI implemented + YAML-validated; **CI green-on-push unverifiable — repo has no git remote**. 3.2: full suite (app-hosted, user-authorized this session) 116/116 baseline then **119/119 green** with the 3 new SectionFixtureRenderTests, re-run confirmed with byte-identical renders; 15 fixture PNGs (3 providers × 5 states) checked in under `docs/verification/2026-10-29-multi-provider-hud/` + regeneration README; 15 #Preview declarations share the fixture catalog. Coordinator: fresh Release handoff — old Debug instance quit gracefully (PID 66578 confirmed exited), fresh `dist/0.1.0/LLM-UsageStatus.app` launched and verified (PID 93177, executable path + version 0.1.0) | "Wave 3 task 3.1: release pipeline and repo surface" (e7ef277); "Wave 3 task 3.2: full verification and fixture renders" (439a09a); dist/ artifacts intentionally uncommitted | 13/13 code tasks complete; E1 next (user-operated smoke test of the running fresh artifact — run Claude Code once first to refresh the stale token, then check the Claude section shows endpoint utilization); E2 after E1. Open notes: Codex estimate-fallback fixture exercises view capability only (Codex section never sets isEstimate — documented in verification README); .gitignore lacks a dist/ entry (decide at E2 whether release evidence is committed) |

---

*Keep active while required work or acceptance is incomplete.*
