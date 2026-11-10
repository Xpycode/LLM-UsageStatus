# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-10 (0.2.0 released as DMG; detail page upload pending)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Execution:** `docs/plans/2026-11-08-v0.2.0/IMPLEMENTATION_PLAN.md` — 11/11 tasks; E1–E4 done.
  **E5:** notarized 0.2.0 DMG live at `apps.lucesumbrarum.com/dl.php?app=llm-usagestatus` (website only).
  Next: upload the staged detail page (8 files in App-Websites; needs permission), then icon decision.
- Installed: notarized 0.2.0 (200) in `/Applications/LLM-UsageStatus.app`, running; previous ad-hoc
  copy kept in `04_Exports/replaced-Applications-288f5ab/`.
- `dist/0.1.0` is stale vs source (rebuild + re-notarize before any redistribution).
- GitHub remote (private) + CI green since 2026-11-07 (now 217 tests on Xcode 16.4).

## Recent

- 2026-11-10: **0.2.0 is downloadable** — notarized DMG on the apps website, README links it; a detail page with sample-data screenshots and a draft icon is ready to upload.
- 2026-11-10: **0.2.0 notarized (E3) and smoke-tested (E4)** — installed in /Applications; feedback test submission arrived on the website; login-item refresh check passed.
- 2026-11-10: **E1 done** — LLM Usage Status is on the website's feedback and tip lists (Count Clock Wise activated in the same deploy, approved).
- 2026-11-09: **0.2.0 E2 passed** — menus, Help, Feedback window, Tip, German layout names, About; Settings shortcut row was cut off and is fixed (label on its own line). Feedback test submission waits on E1.
- 2026-11-08: 0.2.0 pushed (9 commits) — CI green, 217 tests; all 11 plan tasks checked. Manual check (E2) next.

## Handoff

- Current handoff: `docs/sessions/2026-11-10.md` → **Resume** — upload the staged website detail page
  (needs permission), verify live, commit it in App-Websites; then the icon decision.
- Decisions: `docs/decisions.md`
