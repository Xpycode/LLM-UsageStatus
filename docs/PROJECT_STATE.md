# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-15 (pace gauge folded into 0.3.0, committed and pushed on its branch; next: CI, merge, E1)

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
- **Side work:** **pace gauge** on branch `feature/pace-gauge` — accepted by the user (build 4); **folded into 0.3.0** (user, 2026-11-15); CHANGELOG, README (new screenshots) and E1 check 1 updated; committed `57ea8cc`, CI green (run 43737412872, 293 tests), fast-forwarded to `main` and pushed (Backlog #18).
- **Next:** E1 **passed** (user, 2026-11-15, all four checks); user nit (panel jumps on refresh) fixed, uncommitted, awaiting the user's look → commit to `main`, CI, then go-ahead for E2 (four checks in the plan's E1 entry), then go-ahead for E2. Website: the App-Websites session adds GitHub/Homebrew links (E3 folds them in if still open). Deferred: Backlog #14, #15, #16, #17, #18.
- Running: **refresh-line build** (pid 23100) from `04_Exports/0.3.0-refresh-line-Debug/` — `57ea8cc` + uncommitted refresh-line fix, 0.3.0 (300), exec SHA-256 `d45bc54b…ff1b14`, verified 18:32 CET. E1 build (pid 72852) quit, verified exited. Installed 0.2.2 not running.
- `appcast.xml` is live on `main` (raw GitHub) with the 0.2.2 (202) item; `dist/` holds 0.2.1 and 0.2.2.
- GitHub remote **public since 2026-11-12** (Releases + Homebrew tap `xpycode/llm-usagestatus`) + CI green since 2026-11-07 (now 280 tests on Xcode 16.4).

## Recent

- 2026-11-15: **Hover tips fixed** — the panel's tooltips never showed because the app is inactive while the panel is up; replaced by the app's own hover tip, and the expanded view no longer repeats a gauge as a bar; user accepted.
- 2026-11-14: **Pace gauge** — each limit is now a round gauge (outer ring usage left, inner pie time left, orange when behind pace), Fable beside the 7-day gauge, details on hover; on a branch, tooltips still broken.
- 2026-11-14: **Panel fixes** — expanding or collapsing a section no longer makes the panel jump (it now resizes in the same layout pass); header is the shortcut plus a Settings gear under an underlined title; both confirmed by the user.
- 2026-11-12: **0.3.0 Wave 3 done** — docs, Help, Sparkle notice and cask (`auto_updates`, livecheck) for 0.3.0; independent review (no blockers; signing team check, null-headlines decode, logged lenient drops, Settings caption, SKIP_SIGN guard fixed; pre-0.3.0 items → Backlog #17); CI green 280; E1 Debug build handed off.
- 2026-11-12: **0.3.0 Wave 2 done** — Fable allowance sub-meter (live: 87% left), test-defaults cleanup and zero warnings (96 leftover plists deleted), Developer ID signing dry run, first appcast item (0.2.2) pushed and live; signed build said "You're up to date!"; CI green 279; E0 key names captured.

## Handoff

- Current handoff: `docs/sessions/2026-11-15.md` → **Resume (publish)** — gauge accepted on `feature/pace-gauge`, uncommitted; next: CHANGELOG, 0.3.0 vs 0.3.1, commit + push, merge, E1, E2–E5. The 2026-11-14 Resume blocks and earlier are historical.
- Decisions: `docs/decisions.md`
