# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-10-29 (pre-clear, session 7 final + utilization-scale fix)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Execution:** Plan active at `docs/plans/2026-10-29-multi-provider-hud/IMPLEMENTATION_PLAN.md` — **17/17 code tasks** (v1 13 + Wave 4 incl. 4.4 Vibe glance line) and **E1 passed**; only gate **E2** remains: notarized 0.1.0 (Developer ID signing credentials + notarytool key + explicit publish go-ahead). The HUD is now fully glance-first: percent-left headlines with countdowns and per-day quotes (Codex/Claude/Vibe-with-budget), and a last-24-hours estimated-spend + tokens glance line for Vibe without a budget; detail behind click/hover. 134/134 tests, 18 fixture renders. Claude utilization-scale defect fixed (endpoint reports percentages; verified live 2%/0% against the vendor page). Fresh Release build running (keep-running; holds the hotkey). **Open:** user visual confirmation of the running panel, then E2 on go-ahead.

## Recent

- 2026-10-29: Task 4.4 (user-selected at the panel review): Vibe without a budget shows a last-24-hours glance line (estimated spend + tokens); fixed an aggregator control-flow bug found on the way. Provider-logo idea captured to Inbox. Utilization-scale defect fixed from the panel review; fresh Release build handed off.
- 2026-10-29: E1 passed (live compare against all three vendor dashboards; Claude endpoint proven 2xx after the sign-in refresh). Wave 4 executed serially: headline-first sections, expand/hover detail, Vibe monthly budget; Claude window diagnostics landed — five-hour window confirmed present with over-limit utilization. Utilization-scale defect fixed from the panel review; fresh Release build handed off.
- 2026-10-29: Wave 3 executed (2 parallel fresh-context agents): 3.1 release pipeline + repo surface (universal build verified, CI unverified — no remote), 3.2 full verification (119/119 green, 15 fixture renders). Claude endpoint diagnosis resolved (401 = stale token). Fresh dist/0.1.0 Release build handed off and running.
- 2026-10-29: Post-wave HUD review (user screenshots) drove three fixes: malformed-line misclassification (structural records skip silently), Keychain match-all errSecParam (match-one fallback), and 401/403-blind diagnostics (HTTP status + blob key-name logging). Claude endpoint outcome pending the Keychain prompt; Vibe all-time totals instability captured to Inbox.
- 2026-10-29: Wave 2 executed serially (coordinator): HUD views + provider conformances + composition root, Claude local-fallback and Vibe cost rules, persisted 5-hour toggle and renewal refreshes. 116/116 tests green; three task commits; fresh build launched.
- 2026-10-29: Wave 1 executed (5 parallel fresh-context agents + coordinator integration): XcodeGen shell with Control-Option-Command-L hotkey, Provider protocol + normalized section model, verbatim Codex port, Claude OAuth service + log aggregator + Keychain token provider, Vibe journal aggregator + rate card. Build green; 91/91 tests green.

## Handoff

- Current handoff: `docs/sessions/2026-10-29.md` → **Resume (pre-clear, end of 2026-10-29 — session 7, final)** — user glance-verifies the running build (headline sections, glance line, expand/collapse, hover, budget editor), then E2 (notarized 0.1.0) on explicit go-ahead.
- Decisions: `docs/decisions.md`
