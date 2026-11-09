# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-09 (0.2.0 E2 passed)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Execution:** `docs/plans/2026-11-08-v0.2.0/IMPLEMENTATION_PLAN.md` — 11/11 tasks; CI green on 7a092d0
  (217 tests; Settings fix 83a3dcd green). **E2 passed** (feedback submission waits on E1). Next: E1 site roster
  (go-ahead), then E3 notarize (go-ahead). Running: E2b Debug build from `04_Exports/0.2.0-E2b-Debug/`.
- Installed: E1 build (288f5ab, Debug, ad-hoc) in `/Applications/LLM-UsageStatus.app`, not running;
  not a release — replace with a notarized 0.2.0 before redistribution.
- `dist/0.1.0` is stale vs source (rebuild + re-notarize before any redistribution).
- GitHub remote (private) + CI green since 2026-11-07 (now 217 tests on Xcode 16.4).

## Recent

- 2026-11-09: **0.2.0 E2 passed** — menus, Help, Feedback window, Tip, German layout names, About; Settings shortcut row was cut off and is fixed (label on its own line). Feedback test submission waits on E1.
- 2026-11-08: 0.2.0 pushed (9 commits) — CI green, 217 tests; all 11 plan tasks checked. Manual check (E2) next.
- 2026-11-08: 0.2.0 Wave 4 — version 0.2.0 (200), changelog, release scripts refuse uncommitted changes and record the source commit; universal Release build passes; independent review → README/Help now admit the last-seen usage cache and the US-position shortcut check. Fresh Debug build ready for manual testing (not launched).
- 2026-11-08: 0.2.0 Wave 3 — Help, Send Feedback… and Leave a Tip are now in the right-click menu (Help also in the shortcut-warning menu), Command-? reopens Help while Help or Settings is in front, license notices for the Help window's open-source parts ship in the app, README updated. Builds clean; tests await CI; not yet tried by hand (E2).
- 2026-11-08: 0.2.0 Wave 2 built — the Help, Feedback and Tip packages are wired into the project; Feedback/Tip and Help window support code plus the recorder now updates when the keyboard layout changes; builds clean, tests await CI. Not in the menus yet (Wave 3).

## Handoff

- Current handoff: `docs/sessions/2026-11-08.md` → **Resume (end of 2026-11-08, after 0.2.0 Wave 4)** —
  E2 passed; next E1 (site roster) → feedback submission check → E3 notarize.
- Decisions: `docs/decisions.md`
