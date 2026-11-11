# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-11 (0.2.2 live on the website; E4 install next)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Funnel:** build → release — 0.2.2 code complete (8/8), CI green (244 tests), **E1–E3 passed 2026-11-11** — notarized 0.2.2 is live on the website.
- **Execution:** `docs/plans/2026-11-10-v0.2.2/IMPLEMENTATION_PLAN.md` — 0.2.2 (202). Remaining: E4 install (needs a go-ahead).
- **Next:** E4 install (go-ahead), then plan Sparkle as 0.3.0 (decide where the update feed is hosted). After 0.2.2: Sparkle; provider logos last. Deferred: Backlog #14 (budget since reset day), #15 (system hotkeys).
- Installed: notarized 0.2.1 (201) in `/Applications/LLM-UsageStatus.app` (not running; the 0.2.2 Debug build runs for E1).
- `dist/` holds 0.2.1 and 0.2.2 (0.1.0 and 0.2.0 moved to the Trash 2026-11-10).
- GitHub remote (private) + CI green since 2026-11-07 (now 244 tests on Xcode 16.4).

## Recent

- 2026-11-11: **0.2.2 published** — notarized DMG live, page and roster show v0.2.2.
- 2026-11-11: **0.2.2 notarized** — Apple Accepted, stapled, Gatekeeper clean.
- 2026-11-11: **0.2.2 E1 passed** — user acceptance of the Debug build; all 8 tasks closed.
- 2026-11-11: **0.2.2 Wave 3 done** — docs/version 0.2.2 (202), universal Release build, independent review (no defects; one log-noise fix), pushed, CI green with 244 tests.
- 2026-11-10: **0.2.2 Wave 2 done** — Settings hotkey follows the layout; Vibe totals from session snapshots (match Vibe's own 168.8M exactly, 0 mismatches); 244 test functions, build-for-testing green, not pushed.
- 2026-11-10: **0.2.2 Wave 1 done** — cache logging, layout-aware refusals + ISO key, Vibe inclusive tokens/cost, provider on/off (4 commits, build-for-testing green, not pushed).
- 2026-11-10: **0.2.2 planned** — Vibe number fix, layout-aware shortcut refusals, provider on/off in Settings (user request), cache logging.
- 2026-11-10: **0.2.1 shipped and accepted** — the app now has its icon; installed, all checks passed; 0.2.0 plan retired; next release (0.2.2 maintenance) agreed.
- 2026-11-10: **0.2.0 fully published** — notarized download and its own page on the apps website.

## Handoff

- Current handoff: `docs/sessions/2026-11-11.md` → **Resume** — 0.2.2 Wave 3 done; Debug build running for E1.
- Decisions: `docs/decisions.md`
