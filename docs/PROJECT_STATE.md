# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-10-29 (pre-clear, session 8 final — v1 complete)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **v1 is complete.** The plan (17/17 code tasks + gates E1 and E2) is retired as the permanent record; 0.1.0 is **signed, notarized (Apple verdict Accepted), stapled, and spctl-clean**. The notarized build is running (keep-running; holds the hotkey). Post-v1 candidates: Backlog item 10 (Vibe money-first glance — journal-level model discovery + multi-vendor pricing), Inbox items (app icon, Vibe "all time" fluctuation, provider logos), and public distribution (GitHub Release) which needs its own go-ahead and a remote. **Next:** user smoke-tests the notarized artifact; post-v1 work on request.

## Recent

- 2026-10-29: **E2 passed** — 0.1.0 Developer ID signed, Apple verdict Accepted, stapled, spctl clean; notarized build handed off and running. The whole plan is complete.
- 2026-10-29: Task 4.4 (user-selected at the panel review): Vibe without a budget shows a last-24-hours glance line (estimated spend + tokens); fixed an aggregator control-flow bug found on the way. Provider-logo idea captured to Inbox. Utilization-scale defect fixed from the panel review; collapsed sections gained small secondary-window lines; fresh Release build handed off.
- 2026-10-29: E1 passed (live compare against all three vendor dashboards; Claude endpoint proven 2xx after the sign-in refresh). Wave 4 executed serially: headline-first sections, expand/hover detail, Vibe monthly budget; Claude window diagnostics landed — five-hour window confirmed present with over-limit utilization. Utilization-scale defect fixed from the panel review; collapsed sections gained small secondary-window lines; fresh Release build handed off.
- 2026-10-29: Wave 3 executed (2 parallel fresh-context agents): 3.1 release pipeline + repo surface (universal build verified, CI unverified — no remote), 3.2 full verification (119/119 green, 15 fixture renders). Claude endpoint diagnosis resolved (401 = stale token). Fresh dist/0.1.0 Release build handed off and running.
- 2026-10-29: Post-wave HUD review (user screenshots) drove three fixes: malformed-line misclassification (structural records skip silently), Keychain match-all errSecParam (match-one fallback), and 401/403-blind diagnostics (HTTP status + blob key-name logging). Claude endpoint outcome pending the Keychain prompt; Vibe all-time totals instability captured to Inbox.
- 2026-10-29: Wave 2 executed serially (coordinator): HUD views + provider conformances + composition root, Claude local-fallback and Vibe cost rules, persisted 5-hour toggle and renewal refreshes. 116/116 tests green; three task commits; fresh build launched.
- 2026-10-29: Wave 1 executed (5 parallel fresh-context agents + coordinator integration): XcodeGen shell with Control-Option-Command-L hotkey, Provider protocol + normalized section model, verbatim Codex port, Claude OAuth service + log aggregator + Keychain token provider, Vibe journal aggregator + rate card. Build green; 91/91 tests green.

## Handoff

- Current handoff: `docs/sessions/2026-10-29.md` → **Resume (pre-clear, end of 2026-10-29 — session 8, final)** — user smoke-tests the notarized 0.1.0 build; post-v1 work (Backlog/Inbox) or public distribution on request.
- Decisions: `docs/decisions.md`
