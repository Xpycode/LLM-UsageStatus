# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-08 (Settings Wave 2 done; CI 200 green)

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
  Waves 1–2 done (c337166, c8d3ce7), CI green (200 tests). **Wave 3 ready** (3.1 verification ∥
  3.2 code review); not yet requested. E1 needs the user after Wave 3; its launch-at-login part needs
  a separate go-ahead to install into /Applications.
- Still open from v1 follow-up: user smoke test of the two 2026-11-06 fixes in the running Debug
  build; `dist/0.1.0` is stale vs source (rebuild + re-notarize before any redistribution).
- GitHub remote (private) + CI green since 2026-11-07 (now 200 tests on Xcode 16.4).

## Recent

- 2026-11-08: Settings Wave 2 — Settings window (Startup / Shortcut / About) and shortcut recorder, wired into the app: Settings… menu items, Command-Comma while the panel shows, rebinding with restore-on-conflict, launch-at-login refresh, chord-aware footer; README updated. CI 200 green. Not yet tried by hand (E1).
- 2026-11-08: Settings Wave 1 built — shortcut model, multi-shortcut hotkey, launch-at-login service and version info, all tested (189 tests green on CI); not wired into the app yet.
- 2026-11-08: Repo tidied and given a private GitHub remote; CI now runs and passes (147 tests) after two test-only fixes for GitHub's older Xcode. Settings-window plan written, ready for Wave 1.
- 2026-11-06: Smoke-test diagnosis (endpoint 401 = stale token; collapsed fallback looked blank)
  and the two approved fixes: Claude fallback glance line + hint, partial Vibe cost sums with
  `VibeRateCard` (zai-glm-5-3 priced at Z.ai's published rates). 140/140 tests green; fresh Debug
  build handed off and running; dist/0.1.0 now stale vs source.
- 2026-10-29: **E2 passed** — 0.1.0 Developer ID signed, Apple verdict Accepted, stapled, spctl clean; notarized build handed off and running. The whole plan is complete.

## Handoff

- Current handoff: `docs/sessions/2026-11-08.md` → **Resume (end of 2026-11-08, after Wave 2)** —
  `/execute` Wave 3 of the Settings plan, then E1; user smoke test of the 2026-11-06 fixes still open.
- Decisions: `docs/decisions.md`
