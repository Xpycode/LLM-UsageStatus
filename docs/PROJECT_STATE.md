# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-12 (0.3.0 Wave 3 done; all 10 tasks checked; E1 next)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Funnel:** build → acceptance — 0.3.0 plan written and decisions confirmed 2026-11-12; Waves 0–3 done the same day; E1 (user-operated) is next.
- **Execution:** `docs/plans/2026-11-12-v0.3.0/IMPLEMENTATION_PLAN.md` — 0.3.0 (300): **10/10 tasks checked**, E0 passed; **awaiting acceptance:** E1 (user-operated manual check in the running E1 Debug build), then E2 notarize → E3 publish → E4 install → E5 self-update (each needs its go-ahead). D11 local no-new-plist proof waits for an authorized local test run. CI green on `4ae5cc9` (run 43156399908, 280 tests).
- **Next:** run E1 (four checks in the plan's E1 entry) and report; then go-ahead for E2. Website: the App-Websites session adds GitHub/Homebrew links (E3 folds them in if still open). Deferred: Backlog #14, #15, #16, #17 (pre-0.3.0 `try?` + `util=` log in the Claude decoder).
- Running: **E1 Debug build** (pid 97978, `4ae5cc9`) from `04_Exports/0.3.0-W3-E1-Debug/` — the W2b test build was quit for the handoff. The installed notarized 0.2.2 in `/Applications/LLM-UsageStatus.app` is **not** running — relaunch it yourself (quit the E1 build first) or give a go-ahead when done testing.
- `appcast.xml` is live on `main` (raw GitHub) with the 0.2.2 (202) item; `dist/` holds 0.2.1 and 0.2.2.
- GitHub remote **public since 2026-11-12** (Releases + Homebrew tap `xpycode/llm-usagestatus`) + CI green since 2026-11-07 (now 280 tests on Xcode 16.4).

## Recent

- 2026-11-12: **0.3.0 Wave 3 done** — docs, Help, Sparkle notice and cask (`auto_updates`, livecheck) for 0.3.0; independent review (no blockers; signing team check, null-headlines decode, logged lenient drops, Settings caption, SKIP_SIGN guard fixed; pre-0.3.0 items → Backlog #17); CI green 280; E1 Debug build handed off.
- 2026-11-12: **0.3.0 Wave 2 done** — Fable allowance sub-meter (live: 87% left), test-defaults cleanup and zero warnings (96 leftover plists deleted), Developer ID signing dry run, first appcast item (0.2.2) pushed and live; signed build said "You're up to date!"; CI green 279; E0 key names captured.
- 2026-11-12: **0.3.0 Wave 1 done** — Sparkle updater with Check for Updates… and a Settings Updates section, Claude 5-hour and 7-day headlines, the Fable decoder and key-names diagnostic, inside-out signing and appcast tooling; integrated test build green.
- 2026-11-12: **0.3.0 Wave 0 done** — Sparkle 2.10.1 pinned, 0.3.0 (300), partial Info.plist, own EdDSA key exported and verified, stubs; build-for-testing green.
- 2026-11-12: **0.2.2 plan closed** — last check passed (provider on/off survives a relaunch); 0.3.0 decisions confirmed.

## Handoff

- Current handoff: `docs/sessions/2026-11-12.md` → **Resume (current handoff)** in the seventh session section — Wave 3 done, all 10 tasks checked; next: E1 (user-operated). The earlier Resume blocks are historical.
- Decisions: `docs/decisions.md`
