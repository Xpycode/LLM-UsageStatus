# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-15 (E1 passed; pace gauge in 0.3.0 on `main`; next: release E2–E5)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Funnel:** acceptance → release — 0.3.0 (300) built, E0 and E1 passed; release steps E2–E5 next.
- **Execution:** `docs/plans/2026-11-12-v0.3.0/IMPLEMENTATION_PLAN.md` — 0.3.0 (300): **10/10 tasks checked**, E0 + E1 passed (E1 2026-11-15, user "all pass"); **ready:** E2 notarize (needs go-ahead) → E3 publish → E4 install → E5 self-update, each with its own go-ahead. D11 local no-new-plist proof still waits for an authorized local test run. `main` @ `8f06132` (pace gauge + refresh-line fix), CI green (run 43741786958, 295 tests).
- **Next:** release — E2 `scripts/notarize-release.sh 0.3.0` from a clean `main` (commit/push the log first). Website: the App-Websites session adds GitHub/Homebrew links (E3 folds them in if still open). Deferred: Backlog #14, #15, #16, #17.
- Running: **refresh-line build** (pid 23100) from `04_Exports/0.3.0-refresh-line-Debug/` — `8f06132` content, 0.3.0 (300), ad-hoc, exec SHA-256 `d45bc54b…ff1b14`, verified 18:32 CET 2026-11-15. E4 replaces it with the notarized `/Applications` copy. Installed 0.2.2 not running.
- `appcast.xml` is live on `main` (raw GitHub) with the 0.2.2 (202) item; `dist/` holds 0.2.1 and 0.2.2.
- GitHub remote **public since 2026-11-12** (Releases + Homebrew tap `xpycode/llm-usagestatus`) + CI green since 2026-11-07 (now 295 tests on Xcode 16.4).

## Recent

- 2026-11-15: **0.3.0 accepted** — the pace gauge ships in 0.3.0 (merged to main, new README screenshots); the user's manual check passed; the panel no longer grows and shrinks on every refresh.
- 2026-11-15: **Hover tips fixed** — the panel's tooltips never showed because the app is inactive while the panel is up; replaced by the app's own hover tip, and the expanded view no longer repeats a gauge as a bar; user accepted.
- 2026-11-14: **Pace gauge** — each limit is now a round gauge (outer ring usage left, inner pie time left, orange when behind pace), Fable beside the 7-day gauge, details on hover; on a branch, tooltips still broken.
- 2026-11-14: **Panel fixes** — expanding or collapsing a section no longer makes the panel jump (it now resizes in the same layout pass); header is the shortcut plus a Settings gear under an underlined title; both confirmed by the user.
- 2026-11-12: **0.3.0 Wave 3 done** — docs, Help, Sparkle notice and cask (`auto_updates`, livecheck) for 0.3.0; independent review (no blockers; signing team check, null-headlines decode, logged lenient drops, Settings caption, SKIP_SIGN guard fixed; pre-0.3.0 items → Backlog #17); CI green 280; E1 Debug build handed off.

## Handoff

- Current handoff: `docs/sessions/2026-11-15.md` → **Resume (release)** — E1 passed, `main` clean at `8f06132` + log commit; next: E2 notarize → E3 → E4 → E5, each with go-ahead. Earlier Resume blocks are historical.
- Decisions: `docs/decisions.md`
