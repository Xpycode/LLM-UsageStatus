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

- **Execution:** no active plan. 0.2.0 plan retired 2026-11-10 (COMPLETE, 11/11, E1–E5).
  Live: `apps.lucesumbrarum.com/apps/llm-usagestatus.html` (LU-021) + DMG via `dl.php?app=llm-usagestatus`.
  **0.2.1 (201)** shipped same day: app icon (padded macOS grid), notarized app + DMG (881a9c9),
  live on the website (App-Websites 94a8150). User acceptance passed; installed in /Applications. Next: pick the next backlog item.
- Installed: notarized 0.2.1 (201) in `/Applications/LLM-UsageStatus.app` (user-installed, acceptance passed).
- `dist/` holds only 0.2.1 (0.1.0 and 0.2.0 moved to the Trash 2026-11-10).
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

- Current handoff: 0.2.1 fully released; none open; next work starts from the backlog.
- Decisions: `docs/decisions.md`
