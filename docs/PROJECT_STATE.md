# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-08 (0.2.0 Wave 2 done)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Execution:** `docs/plans/2026-11-08-v0.2.0/IMPLEMENTATION_PLAN.md` — 3/11; Waves 1–2 implemented,
  1.1 + 2.1–2.4 awaiting CI (needs push); **Wave 3 (3.1) ready**, not yet requested. E1 site roster open.
- Installed: E1 build (288f5ab, Debug, ad-hoc) in `/Applications/LLM-UsageStatus.app`, running;
  not a release — replace with a notarized 0.2.0 before redistribution.
- `dist/0.1.0` is stale vs source (rebuild + re-notarize before any redistribution).
- GitHub remote (private) + CI green since 2026-11-07 (now 204 tests on Xcode 16.4).

## Recent

- 2026-11-08: 0.2.0 Wave 2 built — the Help, Feedback and Tip packages are wired into the project; Feedback/Tip and Help window support code plus the recorder now updates when the keyboard layout changes; builds clean, tests await CI. Not in the menus yet (Wave 3).
- 2026-11-08: 0.2.0 planned (research by four agents) and Wave 1 built — shortcut names follow the keyboard layout, Help and feedback packages copied in, help text written; builds clean, tests await CI.
- 2026-11-08: **Settings E1 passed** — all six manual checks, including launch at login from /Applications, plus the 2026-11-06 fixes; Command-Tab behavior judged fine (kept by design). Plan retired.
- 2026-11-08: Settings Wave 3 — Release build and checks passed; independent code review led to five fixes (standard Command shortcuts like Command-C are now refused, a bad stored shortcut falls back to the default, three smaller recorder/restart fixes). CI 204 green. Fresh build handed off for E1.
- 2026-11-08: Settings Wave 2 — Settings window (Startup / Shortcut / About) and shortcut recorder, wired into the app: Settings… menu items, Command-Comma while the panel shows, rebinding with restore-on-conflict, launch-at-login refresh, chord-aware footer; README updated. CI 200 green. Not yet tried by hand (E1).
- 2026-11-08: Settings Wave 1 built — shortcut model, multi-shortcut hotkey, launch-at-login service and version info, all tested (189 tests green on CI); not wired into the app yet.
- 2026-11-08: Repo tidied and given a private GitHub remote; CI now runs and passes (147 tests) after two test-only fixes for GitHub's older Xcode. Settings-window plan written, ready for Wave 1.

## Handoff

- Current handoff: `docs/sessions/2026-11-08.md` → **Resume (end of 2026-11-08, after 0.2.0 Wave 1)** —
  push for CI (1.1), then Wave 2.
- Decisions: `docs/decisions.md`
