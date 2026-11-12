# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-12 (0.2.2 released and installed)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Funnel:** build → release — 0.2.2 code complete (8/8), CI green (244 tests), **0.2.2 released** — E1–E3 passed 2026-11-11, installed 2026-11-12 (E4).
- **Execution:** `docs/plans/2026-11-10-v0.2.2/IMPLEMENTATION_PLAN.md` — 0.2.2 (202). Remaining: user confirms provider toggles survive a relaunch in the installed app.
- **Next:** plan Sparkle as 0.3.0 (feed: `appcast.xml` in this repo, like syncthingStatus). Website: the App-Websites session adds GitHub/Homebrew links. Releases follow `docs/homebrew.md`. After 0.2.2: Sparkle; provider logos last. Deferred: Backlog #14 (budget since reset day), #15 (system hotkeys).
- Installed: notarized 0.2.2 (202) in `/Applications/LLM-UsageStatus.app` (running; 0.2.1 in the Trash).
- `dist/` holds 0.2.1 and 0.2.2 (0.1.0 and 0.2.0 moved to the Trash 2026-11-10).
- GitHub remote **public since 2026-11-12** (Releases + Homebrew tap `xpycode/llm-usagestatus`) + CI green since 2026-11-07 (now 244 tests on Xcode 16.4).

## Recent

- 2026-11-12: **Open source + Homebrew** — repo public (full history, secret scan clean); README in syncthingStatus style; GitHub Release v0.2.2 (DMG byte-identical to the website's); cask in-repo tap, fetch + online audit pass.
- 2026-11-12: **0.2.2 installed** — notarized build in /Applications, running, Gatekeeper clean.
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
