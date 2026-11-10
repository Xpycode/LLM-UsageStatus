# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-10 (0.2.1 released: app icon; DMG + page live)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Execution:** `docs/plans/2026-11-08-v0.2.0/IMPLEMENTATION_PLAN.md` — 11/11 tasks; E1–E5 done (retire it).
  Live: `apps.lucesumbrarum.com/apps/llm-usagestatus.html` (LU-021) + DMG via `dl.php?app=llm-usagestatus`.
  **0.2.1 (201)** shipped same day: app icon (padded macOS grid), notarized app + DMG (881a9c9),
  live on the website (App-Websites 94a8150). Next: retire the 0.2.0 plan; pick the next backlog item.
- Installed: notarized 0.2.0 (200) in `/Applications/LLM-UsageStatus.app`, running; previous ad-hoc
  copy kept in `04_Exports/replaced-Applications-288f5ab/`.
- `dist/0.1.0` is stale vs source (rebuild + re-notarize before any redistribution).
- GitHub remote (private) + CI green since 2026-11-07 (now 217 tests on Xcode 16.4).

## Recent

- 2026-11-10: **0.2.1 released** — icon approved, padded to the 824/1024 grid; notarized (app + DMG Accepted), CI green, website serves it.
- 2026-11-10: **E5 done** — detail page uploaded, 8/8 files byte-match live; committed in App-Websites (5643984).
- 2026-11-10: **0.2.0 is downloadable** — notarized DMG on the apps website, README links it; a detail page with sample-data screenshots and a draft icon is ready to upload.
- 2026-11-10: **0.2.0 notarized (E3) and smoke-tested (E4)** — installed in /Applications; feedback test submission arrived on the website; login-item refresh check passed.
- 2026-11-10: **E1 done** — LLM Usage Status is on the website's feedback and tip lists (Count Clock Wise activated in the same deploy, approved).
- 2026-11-09: **0.2.0 E2 passed** — menus, Help, Feedback window, Tip, German layout names, About; Settings shortcut row was cut off and is fixed (label on its own line). Feedback test submission waits on E1.
- 2026-11-08: 0.2.0 pushed (9 commits) — CI green, 217 tests; all 11 plan tasks checked. Manual check (E2) next.

## Handoff

- Current handoff: 0.2.1 fully released; /Applications still has 0.2.0 until the user installs the new DMG.
- Decisions: `docs/decisions.md`
