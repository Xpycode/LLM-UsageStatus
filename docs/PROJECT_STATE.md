# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-15 (0.3.0 released and installed; in-app update proven; next: website)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Funnel:** release → 0.3.0 (300) **published** (GitHub Release, appcast, Homebrew cask) and installed; only the website is open.
- **Execution:** `docs/plans/2026-11-12-v0.3.0/IMPLEMENTATION_PLAN.md` — 10/10 tasks; E0, E1, E2, E4, E5 passed; E3 done except step 5 (website, App-Websites session). Archive the plan once the website is done.
- **Next:** website for 0.3.0 in App-Websites (DMG upload, page/roster version and date, `dl.php`); until then the README apps-site link serves 0.2.2. Deferred: Backlog #14, #15, #16, #17.
- Running: installed **0.3.0** (pid 69801) from `/Applications/LLM-UsageStatus.app`, identical to `dist/0.3.0`. No test builds remain (`04_Exports/` emptied 2026-11-15).
- 0.2.2 has no updater: 0.2.2 users update once by hand or `brew upgrade`; in-app updates start with 0.3.0.
- `03_Screenshots/` untracked by choice; on this Mac it is in `.git/info/exclude` so the release scripts' clean-tree check passes.
- GitHub remote **public since 2026-11-12** (Releases + Homebrew tap `xpycode/llm-usagestatus`) + CI green (295 tests on Xcode 16.4).

## Recent

- 2026-11-15: **0.3.0 released** — notarized, on GitHub and Homebrew and in the update feed; a test copy updated itself to 0.3.0 through the app; installed in Applications; old test builds cleared.
- 2026-11-15: **0.3.0 accepted** — the pace gauge ships in 0.3.0 (merged to main, new README screenshots); the user's manual check passed; the panel no longer grows and shrinks on every refresh.
- 2026-11-15: **Hover tips fixed** — the panel's tooltips never showed because the app is inactive while the panel is up; replaced by the app's own hover tip, and the expanded view no longer repeats a gauge as a bar; user accepted.
- 2026-11-14: **Pace gauge** — each limit is now a round gauge (outer ring usage left, inner pie time left, orange when behind pace), Fable beside the 7-day gauge, details on hover; on a branch, tooltips still broken.
- 2026-11-14: **Panel fixes** — expanding or collapsing a section no longer makes the panel jump (it now resizes in the same layout pass); header is the shortcut plus a Settings gear under an underlined title; both confirmed by the user.

## Handoff

- Current handoff: `docs/sessions/2026-11-15.md` → **Resume (post-release)** — 0.3.0 released and installed; next: website in App-Websites, then archive the plan. Earlier Resume blocks are historical.
- Decisions: `docs/decisions.md`
