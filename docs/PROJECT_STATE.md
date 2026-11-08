# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-08 (Settings Wave 1 done; CI 189 green)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Execution:** Settings plan `docs/plans/2026-11-06-settings-window/IMPLEMENTATION_PLAN.md` —
  Wave 1 (1.1–1.4) done, c337166, CI green (189 tests). **Wave 2 ready** (2.1 Settings window, then
  2.2 AppDelegate integration); not yet requested. E1 needs the user; its launch-at-login part needs
  a separate go-ahead to install into /Applications.
- Still open from v1 follow-up: user smoke test of the two 2026-11-06 fixes in the running Debug
  build; `dist/0.1.0` is stale vs source (rebuild + re-notarize before any redistribution).
- GitHub remote (private) + CI green since 2026-11-07 (now 189 tests on Xcode 16.4).

## Recent

- 2026-11-08: Settings Wave 1 built — shortcut model, multi-shortcut hotkey, launch-at-login service and version info, all tested (189 tests green on CI); not wired into the app yet.
- 2026-11-08: Repo tidied and given a private GitHub remote; CI now runs and passes (147 tests) after two test-only fixes for GitHub's older Xcode. Settings-window plan written, ready for Wave 1.
- 2026-11-06: Smoke-test diagnosis (endpoint 401 = stale token; collapsed fallback looked blank)
  and the two approved fixes: Claude fallback glance line + hint, partial Vibe cost sums with
  `VibeRateCard` (zai-glm-5-3 priced at Z.ai's published rates). 140/140 tests green; fresh Debug
  build handed off and running; dist/0.1.0 now stale vs source.
- 2026-10-29: **E2 passed** — 0.1.0 Developer ID signed, Apple verdict Accepted, stapled, spctl clean; notarized build handed off and running. The whole plan is complete.
- 2026-10-29: Task 4.4 (user-selected at the panel review): Vibe without a budget shows a last-24-hours glance line (estimated spend + tokens); fixed an aggregator control-flow bug found on the way. Provider-logo idea captured to Inbox. Utilization-scale defect fixed from the panel review; collapsed sections gained small secondary-window lines; fresh Release build handed off.

## Handoff

- Current handoff: `docs/sessions/2026-11-08.md` → **Resume (end of 2026-11-08, after Wave 1)** —
  `/execute` Wave 2 of the Settings plan; user smoke test of the 2026-11-06 fixes still open.
- Decisions: `docs/decisions.md`
