# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-10-29 (pre-clear, session 5 final)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Execution:** Plan active at `docs/plans/2026-10-29-multi-provider-hud/IMPLEMENTATION_PLAN.md` — **13/13 code tasks complete**. Wave 3 done: release pipeline (release.sh verified with a real universal 0.1.0 build, notarize script ported, CI workflow — unverified, no git remote; README/LICENSE/CHANGELOG) and full verification (119/119 tests, 15 fixture renders checked in). Claude endpoint diagnosis closed: implementation correct; 401 = stale stored token; labeled local fallback engaged as designed; endpoint stays primary. Fresh Release artifact running (keep-running; holds the hotkey). **Open: E1** — user-operated smoke test of the running fresh artifact (run Claude Code once first to refresh the stale token, then check the Claude section shows endpoint utilization); **then E2** — notarized 0.1.0 (needs signing credentials + explicit publish go-ahead).

## Recent

- 2026-10-29: Wave 3 executed (2 parallel fresh-context agents): 3.1 release pipeline + repo surface (universal build verified, CI unverified — no remote), 3.2 full verification (119/119 green, 15 fixture renders). Claude endpoint diagnosis resolved (401 = stale token). Fresh dist/0.1.0 Release build handed off and running.
- 2026-10-29: Post-wave HUD review (user screenshots) drove three fixes: malformed-line misclassification (structural records skip silently), Keychain match-all errSecParam (match-one fallback), and 401/403-blind diagnostics (HTTP status + blob key-name logging). Claude endpoint outcome pending the Keychain prompt; Vibe all-time totals instability captured to Inbox.
- 2026-10-29: Wave 2 executed serially (coordinator): HUD views + provider conformances + composition root, Claude local-fallback and Vibe cost rules, persisted 5-hour toggle and renewal refreshes. 116/116 tests green; three task commits; fresh build launched.
- 2026-10-29: Wave 1 executed (5 parallel fresh-context agents + coordinator integration): XcodeGen shell with Control-Option-Command-L hotkey, Provider protocol + normalized section model, verbatim Codex port, Claude OAuth service + log aggregator + Keychain token provider, Vibe journal aggregator + rate card. Build green; 91/91 tests green.
- 2026-10-29: Plan review passed — research annex re-verified (web subagents + local); refinements folded into tasks 1.4/1.5/2.1; /make-plan with three research subagents resolved all five spec open questions; spec approved.

## Handoff

- Current handoff: `docs/sessions/2026-10-29.md` → **Resume (pre-clear, end of 2026-10-29 — session 5, final)** — E1 user smoke test of the running fresh artifact (Claude Code refresh first for the Claude section), then E2 on explicit go-ahead.
- Decisions: `docs/decisions.md`
