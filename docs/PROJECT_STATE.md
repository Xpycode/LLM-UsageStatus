# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-12 (0.3.0 Wave 0 done; Wave 1 ready)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Funnel:** build — 0.3.0 plan written and decisions confirmed 2026-11-12; Wave 0 done the same day; Wave 1 is ready.
- **Execution:** `docs/plans/2026-11-12-v0.3.0/IMPLEMENTATION_PLAN.md` — 0.3.0 (300): 1/10 tasks, E0–E5 open. **Wave 0 (0.1) done 2026-11-12** (`109957c`, not pushed): Sparkle 2.10.1 pinned, version 0.3.0 (300), partial Info.plist, EdDSA key (account `LLM-UsageStatus`, exported to `99-AUTH` and verified), stubs. **Ready:** Wave 1 = 1.1 Sparkle wiring, 1.2 two headlines, 1.3 Claude decoder + diagnostic, 1.4 release pipeline (4 parallel agents). Execution was requested for Wave 0 only.
- **Next:** `/execute` Wave 1 (1.1–1.4). Website: the App-Websites session adds GitHub/Homebrew links (E3 folds them in if still open). Deferred: Backlog #14 (budget since reset day), #15 (system hotkeys), #16 (Claude limit resets).
- Installed: notarized 0.2.2 (202) in `/Applications/LLM-UsageStatus.app` (running; 0.2.1 in the Trash).
- `dist/` holds 0.2.1 and 0.2.2 (0.1.0 and 0.2.0 moved to the Trash 2026-11-10).
- GitHub remote **public since 2026-11-12** (Releases + Homebrew tap `xpycode/llm-usagestatus`) + CI green since 2026-11-07 (now 244 tests on Xcode 16.4).

## Recent

- 2026-11-12: **0.3.0 Wave 0 done** — Sparkle 2.10.1 pinned, 0.3.0 (300), partial Info.plist, own EdDSA key exported and verified, stubs; build-for-testing green.
- 2026-11-12: **0.2.2 plan closed** — last check passed (provider on/off survives a relaunch); 0.3.0 decisions confirmed.
- 2026-11-12: **0.3.0 planned** — Sparkle auto-updates, Claude two headlines, Fable allowance meter; research found the Fable meter in `limits[]` and that the resets inventory is gated to the Claude CLI surface (deferred). Plan: `docs/plans/2026-11-12-v0.3.0/`.
- 2026-11-12: **Open source + Homebrew** — repo public, README in the syncthingStatus style, GitHub Release v0.2.2, Homebrew tap working.
- 2026-11-12: **0.2.2 released and installed** — notarized DMG live on the website, page and roster show v0.2.2, installed in Applications.
- 2026-11-11: **0.2.2 accepted** — user passed all manual checks; all 8 tasks closed.
- 2026-11-11: **0.2.2 Wave 3 done** — docs and version, universal Release build, independent review, CI green with 244 tests.

## Handoff

- Current handoff: `docs/sessions/2026-11-12.md` → **Resume (current handoff)** in the third session section — decisions confirmed, 0.2.2 retired; next: `/execute` Wave 0. The earlier Resume blocks are historical.
- Decisions: `docs/decisions.md`
