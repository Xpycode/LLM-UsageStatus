# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-12 (0.2.2 shipped; open source + Homebrew; 0.3.0 planned, decisions confirmed)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Funnel:** plan → build — 0.3.0 plan written 2026-11-12 (validation gate passed: dependencies, ownership and gates checked); the user confirmed all four planner decisions the same day; Wave 0 is ready.
- **Execution:** `docs/plans/2026-11-12-v0.3.0/IMPLEMENTATION_PLAN.md` — 0.3.0 (300): 0/10 tasks, E0–E5 open. First wave: 0.1 (coordinator: Sparkle 2.10.1 pinned, version 300, partial Info.plist, EdDSA key, stubs), then Wave 1 = 1.1 Sparkle wiring, 1.2 two headlines, 1.3 Claude decoder + diagnostic, 1.4 release pipeline (4 parallel agents). **Confirmed 2026-11-12:** D2 (own key account + `99-AUTH` export; key go-ahead given), D4 (Check for Updates… after Settings…; Settings "Updates" section), D10 ("Limit resets" → Backlog #16), D11 (hygiene task). **Execution not requested.** The 0.2.2 plan is retired (all checks passed 2026-11-12).
- **Next:** `/execute` Wave 0 (0.1). Website: the App-Websites session adds GitHub/Homebrew links (E3 folds them in if still open). Deferred: Backlog #14 (budget since reset day), #15 (system hotkeys), #16 (Claude limit resets).
- Installed: notarized 0.2.2 (202) in `/Applications/LLM-UsageStatus.app` (running; 0.2.1 in the Trash).
- `dist/` holds 0.2.1 and 0.2.2 (0.1.0 and 0.2.0 moved to the Trash 2026-11-10).
- GitHub remote **public since 2026-11-12** (Releases + Homebrew tap `xpycode/llm-usagestatus`) + CI green since 2026-11-07 (now 244 tests on Xcode 16.4).

## Recent

- 2026-11-12: **0.2.2 plan closed** — last check passed (provider on/off survives a relaunch); 0.3.0 decisions confirmed.
- 2026-11-12: **0.3.0 planned** — Sparkle auto-updates, Claude two headlines, Fable allowance meter; research found the Fable meter in `limits[]` and that the resets inventory is gated to the Claude CLI surface (deferred). Plan: `docs/plans/2026-11-12-v0.3.0/`.
- 2026-11-12: **Open source + Homebrew** — repo public, README in the syncthingStatus style, GitHub Release v0.2.2, Homebrew tap working.
- 2026-11-12: **0.2.2 released and installed** — notarized DMG live on the website, page and roster show v0.2.2, installed in Applications.
- 2026-11-11: **0.2.2 accepted** — user passed all manual checks; all 8 tasks closed.
- 2026-11-11: **0.2.2 Wave 3 done** — docs and version, universal Release build, independent review, CI green with 244 tests.

## Handoff

- Current handoff: `docs/sessions/2026-11-12.md` → **Resume (current handoff)** in the third session section — decisions confirmed, 0.2.2 retired; next: `/execute` Wave 0. The earlier Resume blocks are historical.
- Decisions: `docs/decisions.md`
