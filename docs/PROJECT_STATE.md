# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-12 (0.3.0 Wave 1 done; Wave 2 ready)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Funnel:** build — 0.3.0 plan written and decisions confirmed 2026-11-12; Waves 0 and 1 done the same day; Wave 2 is ready.
- **Execution:** `docs/plans/2026-11-12-v0.3.0/IMPLEMENTATION_PLAN.md` — 0.3.0 (300): 1/10 tasks checked; 1.1–1.4 implemented and integrated (build-for-testing green, 275 test functions), unchecked until CI (1.1–1.3) and 2.3 (1.4); E0–E5 open. **Ready:** Wave 2 = 2.1 Fable sub-meter (agent), 2.2 hygiene (agent; deleting the 96 test plists needs a go-ahead), 2.3 Developer ID signing dry run + first appcast item (coordinator; its push needs a go-ahead). Commits from `109957c` on are not pushed (main ahead 7).
- **Next:** `/execute` Wave 2 (2.1–2.3); a push go-ahead lets CI verify 1.1–1.3 early. Website: the App-Websites session adds GitHub/Homebrew links (E3 folds them in if still open). Deferred: Backlog #14 (budget since reset day), #15 (system hotkeys), #16 (Claude limit resets).
- Installed: notarized 0.2.2 (202) in `/Applications/LLM-UsageStatus.app` (running; 0.2.1 in the Trash).
- `dist/` holds 0.2.1 and 0.2.2 (0.1.0 and 0.2.0 moved to the Trash 2026-11-10).
- GitHub remote **public since 2026-11-12** (Releases + Homebrew tap `xpycode/llm-usagestatus`) + CI green since 2026-11-07 (now 244 tests on Xcode 16.4).

## Recent

- 2026-11-12: **0.3.0 Wave 1 done** — Sparkle updater with Check for Updates… and a Settings Updates section, Claude 5-hour and 7-day headlines, the Fable decoder and key-names diagnostic, inside-out signing and appcast tooling; integrated test build green.
- 2026-11-12: **0.3.0 Wave 0 done** — Sparkle 2.10.1 pinned, 0.3.0 (300), partial Info.plist, own EdDSA key exported and verified, stubs; build-for-testing green.
- 2026-11-12: **0.2.2 plan closed** — last check passed (provider on/off survives a relaunch); 0.3.0 decisions confirmed.
- 2026-11-12: **0.3.0 planned** — Sparkle auto-updates, Claude two headlines, Fable allowance meter; research found the Fable meter in `limits[]` and that the resets inventory is gated to the Claude CLI surface (deferred). Plan: `docs/plans/2026-11-12-v0.3.0/`.
- 2026-11-12: **Open source + Homebrew** — repo public, README in the syncthingStatus style, GitHub Release v0.2.2, Homebrew tap working.

## Handoff

- Current handoff: `docs/sessions/2026-11-12.md` → **Resume (current handoff)** in the fifth session section — Wave 1 done; next: `/execute` Wave 2. The earlier Resume blocks are historical.
- Decisions: `docs/decisions.md`
