# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-10 (0.2.2 Wave 1 done; Wave 2 ready)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Funnel:** build — 0.2.2 Wave 1 of 3 done.
- **Execution:** `docs/plans/2026-11-10-v0.2.2/IMPLEMENTATION_PLAN.md` — 0.2.2 (202). Wave 1 done
  (1.1, 1.2, 1.3 complete; 1.4 implemented, Settings screenshot open); 4 commits, not pushed.
  **Wave 2 (2.1 Settings hotkey follows layout, 2.2 Vibe session snapshots) is ready.**
- **Next:** `/execute` Wave 2. After 0.2.2: Sparkle; provider logos last. Deferred: Backlog #14 (budget since reset day), #15 (system hotkeys).
- Installed: notarized 0.2.1 (201) in `/Applications/LLM-UsageStatus.app` (user-installed, acceptance passed).
- `dist/` holds only 0.2.1 (0.1.0 and 0.2.0 moved to the Trash 2026-11-10).
- GitHub remote (private) + CI green since 2026-11-07 (now 217 tests on Xcode 16.4).

## Recent

- 2026-11-10: **0.2.2 Wave 1 done** — cache logging, layout-aware refusals + ISO key, Vibe inclusive tokens/cost, provider on/off (4 commits, build-for-testing green, not pushed).
- 2026-11-10: **0.2.2 planned** — Vibe number fix, layout-aware shortcut refusals, provider on/off in Settings (user request), cache logging.
- 2026-11-10: **0.2.1 shipped and accepted** — the app now has its icon; installed, all checks passed; 0.2.0 plan retired; next release (0.2.2 maintenance) agreed.
- 2026-11-10: **0.2.0 fully published** — notarized download and its own page on the apps website.
- 2026-11-10: **0.2.0 notarized (E3) and smoke-tested (E4)** — installed in /Applications; feedback test submission arrived on the website; login-item refresh check passed.
- 2026-11-10: **E1 done** — LLM Usage Status is on the website's feedback and tip lists (Count Clock Wise activated in the same deploy, approved).
- 2026-11-09: **0.2.0 E2 passed** — menus, Help, Feedback window, Tip, German layout names, About; Settings shortcut row was cut off and is fixed (label on its own line). Feedback test submission waits on E1.

## Handoff

- Current handoff: `docs/sessions/2026-11-10.md` → last **Resume** (night) — 0.2.2 Wave 1 done, Wave 2 next.
- Decisions: `docs/decisions.md`
