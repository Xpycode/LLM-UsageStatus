# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-12 (0.3.0 Wave 2 done; Wave 3 ready)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Funnel:** build — 0.3.0 plan written and decisions confirmed 2026-11-12; Waves 0, 1 and 2 done the same day; Wave 3 is ready.
- **Execution:** `docs/plans/2026-11-12-v0.3.0/IMPLEMENTATION_PLAN.md` — 0.3.0 (300): 8/10 tasks checked (0.1, 1.1–1.4, 2.1–2.3), E0 passed; **ready:** Wave 3 = 3.1 docs/cask/notices → 3.2 review, CI, fresh build for E1 (coordinator). Open gates: E1–E5; D11 local no-new-plist proof waits for an authorized local test run. CI green on `04d0ece` (279 tests); `3c83c41` (Fable bar colour) is committed but not pushed (main ahead 1 + this log).
- **Next:** `/execute` Wave 3 (3.1, 3.2). Website: the App-Websites session adds GitHub/Homebrew links (E3 folds them in if still open). Deferred: Backlog #14 (budget since reset day), #15 (system hotkeys), #16 (Claude limit resets).
- Running: signed 0.3.0 test build (pid 49601) from `04_Exports/0.3.0-W2b-signed-Release/`; the installed notarized 0.2.2 in `/Applications/LLM-UsageStatus.app` was quit for the handoff and is **not** running — relaunch it yourself (or give a go-ahead) when done testing.
- `appcast.xml` is live on `main` (raw GitHub) with the 0.2.2 (202) item; `dist/` holds 0.2.1 and 0.2.2.
- GitHub remote **public since 2026-11-12** (Releases + Homebrew tap `xpycode/llm-usagestatus`) + CI green since 2026-11-07 (now 279 tests on Xcode 16.4).

## Recent

- 2026-11-12: **0.3.0 Wave 2 done** — Fable allowance sub-meter (live: 87% left), test-defaults cleanup and zero warnings (96 leftover plists deleted), Developer ID signing dry run, first appcast item (0.2.2) pushed and live; signed build said "You're up to date!"; CI green 279; E0 key names captured.
- 2026-11-12: **0.3.0 Wave 1 done** — Sparkle updater with Check for Updates… and a Settings Updates section, Claude 5-hour and 7-day headlines, the Fable decoder and key-names diagnostic, inside-out signing and appcast tooling; integrated test build green.
- 2026-11-12: **0.3.0 Wave 0 done** — Sparkle 2.10.1 pinned, 0.3.0 (300), partial Info.plist, own EdDSA key exported and verified, stubs; build-for-testing green.
- 2026-11-12: **0.2.2 plan closed** — last check passed (provider on/off survives a relaunch); 0.3.0 decisions confirmed.
- 2026-11-12: **0.3.0 planned** — Sparkle auto-updates, Claude two headlines, Fable allowance meter; research found the Fable meter in `limits[]` and that the resets inventory is gated to the Claude CLI surface (deferred). Plan: `docs/plans/2026-11-12-v0.3.0/`.
- 2026-11-12: **Open source + Homebrew** — repo public, README in the syncthingStatus style, GitHub Release v0.2.2, Homebrew tap working.

## Handoff

- Current handoff: `docs/sessions/2026-11-12.md` → **Resume (current handoff)** in the fifth session section — Wave 1 done; next: `/execute` Wave 2. The earlier Resume blocks are historical.
- Decisions: `docs/decisions.md`
