# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-10 (0.2.2 Wave 2 done; Wave 3 ready)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Funnel:** build — 0.2.2 Waves 1 and 2 of 3 done.
- **Execution:** `docs/plans/2026-11-10-v0.2.2/IMPLEMENTATION_PLAN.md` — 0.2.2 (202). Waves 1 and 2 done
  (1.4 Settings screenshot still open); `main` is 9 commits ahead of origin, not pushed.
  **Wave 3 is ready: 3.1 docs/version, then 3.2 review and CI (CI needs a push go-ahead).**
- **Next:** `/execute` Wave 3. After 0.2.2: Sparkle; provider logos last. Deferred: Backlog #14 (budget since reset day), #15 (system hotkeys).
- Installed: notarized 0.2.1 (201) in `/Applications/LLM-UsageStatus.app` (user-installed, acceptance passed).
- `dist/` holds only 0.2.1 (0.1.0 and 0.2.0 moved to the Trash 2026-11-10).
- GitHub remote (private) + CI green since 2026-11-07 (now 217 tests on Xcode 16.4).

## Recent

- 2026-11-10: **0.2.2 Wave 2 done** — Settings hotkey follows the layout; Vibe totals from session snapshots (match Vibe's own 168.8M exactly, 0 mismatches); 244 test functions, build-for-testing green, not pushed.
- 2026-11-10: **0.2.2 Wave 1 done** — cache logging, layout-aware refusals + ISO key, Vibe inclusive tokens/cost, provider on/off (4 commits, build-for-testing green, not pushed).
- 2026-11-10: **0.2.2 planned** — Vibe number fix, layout-aware shortcut refusals, provider on/off in Settings (user request), cache logging.
- 2026-11-10: **0.2.1 shipped and accepted** — the app now has its icon; installed, all checks passed; 0.2.0 plan retired; next release (0.2.2 maintenance) agreed.
- 2026-11-10: **0.2.0 fully published** — notarized download and its own page on the apps website.

## Handoff

- Current handoff: `docs/sessions/2026-11-10.md` → last **Resume** (late night) — 0.2.2 Wave 2 done, Wave 3 next.
- Decisions: `docs/decisions.md`
