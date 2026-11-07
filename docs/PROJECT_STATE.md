# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-08 (Settings window plan; remote + CI green)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Planning done for the Settings window** (launch at login, shortcut rebinding, About):
  `docs/plans/2026-11-06-settings-window/IMPLEMENTATION_PLAN.md`, 8 tasks in 3 waves + manual
  acceptance E1. Execution not yet requested.
- **Execution:** Wave 1 ready, no prerequisites — 1.1 shortcut model, 1.2 multi-registration
  hotkey, 1.3 launch-at-login service, 1.4 version/About model (four parallel units). Waves 2–3
  follow; E1 needs the user, and its launch-at-login part needs a separate go-ahead to install
  into /Applications.
- Still open from v1 follow-up: user smoke test of the two 2026-11-06 fixes in the running Debug
  build; `dist/0.1.0` is stale vs source (rebuild + re-notarize before any redistribution).
- GitHub remote (private) + CI green since 2026-11-07 (147 tests on Xcode 16.4).

## Recent

- 2026-11-06: Smoke-test diagnosis (endpoint 401 = stale token; collapsed fallback looked blank)
  and the two approved fixes: Claude fallback glance line + hint, partial Vibe cost sums with
  `VibeRateCard` (zai-glm-5-3 priced at Z.ai's published rates). 140/140 tests green; fresh Debug
  build handed off and running; dist/0.1.0 now stale vs source.
- 2026-10-29: **E2 passed** — 0.1.0 Developer ID signed, Apple verdict Accepted, stapled, spctl clean; notarized build handed off and running. The whole plan is complete.
- 2026-10-29: Task 4.4 (user-selected at the panel review): Vibe without a budget shows a last-24-hours glance line (estimated spend + tokens); fixed an aggregator control-flow bug found on the way. Provider-logo idea captured to Inbox. Utilization-scale defect fixed from the panel review; collapsed sections gained small secondary-window lines; fresh Release build handed off.
- 2026-10-29: E1 passed (live compare against all three vendor dashboards; Claude endpoint proven 2xx after the sign-in refresh). Wave 4 executed serially: headline-first sections, expand/hover detail, Vibe monthly budget; Claude window diagnostics landed — five-hour window confirmed present with over-limit utilization. Utilization-scale defect fixed from the panel review; collapsed sections gained small secondary-window lines; fresh Release build handed off.
- 2026-10-29: Wave 3 executed (2 parallel fresh-context agents): 3.1 release pipeline + repo surface (universal build verified, CI unverified — no remote), 3.2 full verification (119/119 green, 15 fixture renders). Claude endpoint diagnosis resolved (401 = stale token). Fresh dist/0.1.0 Release build handed off and running.
- 2026-10-29: Post-wave HUD review (user screenshots) drove three fixes: malformed-line misclassification (structural records skip silently), Keychain match-all errSecParam (match-one fallback), and 401/403-blind diagnostics (HTTP status + blob key-name logging). Claude endpoint outcome pending the Keychain prompt; Vibe all-time totals instability captured to Inbox.

## Handoff

- Current handoff: `docs/sessions/2026-11-06.md` → **Resume (end of 2026-11-06 — session 9)** —
  smoke-test the two fixes in the running Debug build; dist/0.1.0 needs a release rebuild +
  re-notarization before redistribution.
- Decisions: `docs/decisions.md`
