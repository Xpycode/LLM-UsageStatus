# Implementation Plan — Multi-Provider Usage HUD v1

> **Persists across sessions.** Execute using the shared `commands/execute.md` procedure.
> Repair scheduling errors while preserving task IDs, completed evidence and approved scope.
> Task state/evidence is authoritative here; TASKS links here and holds backlog/inbox.

**Progress:** 17/17 code tasks (v1 13 + Wave 4) + E1 passed; external acceptance: E2 (notarized 0.1.0 release); user glance-verification of the Wave 4 UI on the running build.
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

### Wave 4 (post-E1 acceptance follow-ups; serial)

- [x] **4.1**: Headline-first sections — model, presentation, formatting
  - Depends on: E1 findings (user-accepted design 2026-10-29: % left headline + per-day estimate; detail on click/hover)
  - Owns: `ProviderModels.swift`, `UsageStatusView.swift`, provider section-building (Codex/Claude), quantity formatting
  - Interface: `ProviderSection` gains an optional headline (window label, percent left, reset date, optional per-day quote); meters render "X% left"
  - Success: populated sections lead with "% left · resets in …" (+ labeled per-day estimate where a remaining quantity exists: Codex credits); clicking a section expands/collapses the full detail; hovering shows a compact tooltip summary; the live-seen formatting defects (credits "74,172,73", tokens "42,817.996") are fixed with locale-correct grouping and covered by tests
  - Also (done): privacy-safe Claude window-presence logging — live evidence 2026-10-29 16:31: five_hour present util=200% reset=true seven_day present util=0%; the window was never absent, it carried over-limit utilization
  - Backpressure: updated provider/view tests + full suite
- [x] **4.2**: Vibe monthly budget preference and input UI
  - Depends on: 4.1
  - Owns: `UsagePreferences.swift`, right-click menu, `VibeUsageProvider.swift` headline, a small AppKit-native input surface (no SwiftUI controls per project UI conventions)
  - Interface: persisted `vibeMonthlyBudgetUSD` (nil = unset) + reset day; headline percent-left and $/day quote derived from the local cost estimate, visibly labeled estimates
  - Success: with a budget set, the Vibe headline shows estimated % left + $/day until the configured reset; without one, the section stays token-first with no percentage; menu entry and persistence tests pass
  - Backpressure: preferences + provider tests + full suite
- [x] **4.3**: Wave 4 verification and evidence refresh
  - Depends on: 4.2
  - Owns: fixture catalog/previews, `docs/verification/2026-10-29-multi-provider-hud/`
  - Success: full suite green; fixture renders refreshed for the new states (collapsed headline, expanded detail, Vibe with budget); verification README updated
  - Backpressure: full suite + regenerated renders

- [x] **4.4**: Vibe no-budget glance line
  - Depends on: 4.2 (user-selected at the 4.3 handoff review: collapsed Vibe with no budget showed nothing)
  - Owns: `VibeJournalAggregator.swift` (per-session window totals), `VibeUsageProvider.swift`, `ProviderModels.swift` (`SectionGlanceLine`), `UsageStatusView.swift` (glance rendering + tooltip)
  - Interface: sections without a headline can carry a compact preformatted glance line
  - Success: collapsed Vibe (no budget, recent activity) shows "≈ $X · N tokens · 24 hours" (spend only when every contributing session's model price resolves — the same all-or-nothing rule as the cost line; tokens-only otherwise); estimate-labeled; suppressed when the window is empty; renders refreshed
  - Backpressure: provider tests (glance construction, price suppression, budget precedence, empty window) + full suite

## External checks

- [x] **E1**: Fresh-build smoke test (user-operated) — **passed 2026-10-29** (session 5: user screenshots + live compare against ChatGPT/Codex, Claude, and Mistral usage pages; hotkey toggled; Codex 11% used ↔ ChatGPT 89% left, same reset time; Claude endpoint 2xx after sign-in refresh — 0%/7-day matches Claude's page; Vibe populates; absent-provider states covered by 3.2 fixture renders; the app itself never prompted for or stored credentials). **Acceptance follow-ups recorded:** (1) user requests headline "% left until next reset" + details (tokens etc.) behind hover/click — new scoped change, spec/plan update pending; (2) number-formatting defects seen live (Codex credits "74,172,73", Vibe tokens "42,817.996"); (3) Claude 5-hour window absent in the live section despite the web page showing a current-session window — investigate during that change.
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
| Wave 4 (4.1→4.2→4.3) 2026-10-29 | Serial coordinator execution — model/view/provider changes share the section surface; no independent fresh-context work. Design accepted by the user at E1 review (Both expand+hover / Budget-per-day quote / Vibe manual budget + token-first fallback); spec amended before coding | 4.1: headline-first sections — `SectionHeadline`/`SectionDailyBudget` model, Codex weekly headline with credits-per-day quote, Claude soonest-reset headline, "% left" meters, click-to-expand + `.help()` hover summary, Claude window-presence diagnostics (live evidence 16:31: five_hour present util=200%, seven_day 0% — the E1 "missing five-hour meter" was never an absent window). 4.2: persisted Vibe budget (USD + reset day, AppKit editor window via right-click menu), estimated % left + $/day headline that suppresses when the cost cannot resolve. Full suite **129/129 green** (10 new tests: headline mappings, budget math, reset-date clamping, preference persistence, malformed-defaults rejection). 4.3: 18 fixture renders (15 expanded + 3 collapsed headline incl. vibe-budget) checked in; verification README updated. The two "formatting defects" from the E1 screenshots did not reproduce in code (credits/tokens both format via locale-aware grouped formatting; `totalTokens` is an Int) — recorded as screenshot-transcription artifacts, user re-verifies visually | "Wave 4 tasks 4.1+4.2: headline-first sections and Vibe monthly budget" (cdff3e0); "Wave 4 task 4.3: fixture render refresh (18 states)" (09a524a); spec + CHANGELOG amended (pre-clear commit) | All code tasks complete; fresh Wave-4 Release 0.1.0 build handed off and running (PID 25354) — user glance-verifies the new UI (headline, expand/collapse, hover, budget editor). Remaining: **E2** — notarized 0.1.0 (signing credentials + explicit publish go-ahead). Backlog item 10 (Vibe per-model cost sums) still open; Inbox items unchanged |
| Task 4.4 (serial coordinator) 2026-10-29 | User-selected scope at the 4.3 handoff review (collapsed Vibe without a budget showed only "Last updated") — design: "Both" = estimated 24h spend + token count, estimate-labeled | Aggregator gained per-session window totals (model binding retained; fixed a control-flow bug where the per-session append sat after the remainder guard); provider builds the glance line with the same all-or-nothing price rule as the cost line; view renders it when no headline exists (tooltip included); fixtures updated. Full suite **133/133 green** (4 new glance tests); 18 renders regenerated | See pre-clear commit for the 4.4 code commit; renders checked in under docs/verification | Same as Wave 4: user glance-verification on the running build, then E2 |
| Defect fix (same session) 2026-10-29 | User's panel review (HUD "0% left" vs vendor page "2% used") exposed the Claude utilization scale error | Endpoint `utilization` is a percentage (2.0 = 2%), not a fraction — verified against the vendor page live; decoder normalizes to a fraction, clamps at 100%; fixtures moved to the real scale; regression test added; **134/134 green**; fresh build handed off (PID 43555) and its first fetch matched the vendor page exactly (2% / 0%) | "Fix: Claude endpoint utilization is a percentage, not a fraction" (a8a13f5) | Same as 4.4: user glance-verification, then E2. Rate-card scope (item 10) sharpened: user's sessions carry no model metadata or a non-Mistral model (zai-glm-5-3) — journal-level model discovery + multi-vendor pricing is the path to a money-first Vibe glance |

---

*Keep active while required work or acceptance is incomplete.*
