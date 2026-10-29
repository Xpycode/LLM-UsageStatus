# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-10-29 (pre-clear, session 4)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Execution:** Plan active at `docs/plans/2026-10-29-multi-provider-hud/IMPLEMENTATION_PLAN.md` — 8/13 tasks; Wave 2 (2.1–2.3) complete: three-provider HUD live end-to-end (Codex endpoint, Claude endpoint + labeled local fallback, Vibe journal aggregates + conditional cost), preferences/renewal timers; 116/116 tests green (app-hosted run user-authorized this session); fresh build launched for user testing (keep-running). **Next:** Wave 3 (3.1 release pipeline, 3.2 verification + fixture visuals) on request; E1/E2 open; no code-level blockers.

## Recent

- 2026-10-29: Wave 2 executed serially (coordinator): HUD views + provider conformances + composition root, Claude local-fallback and Vibe cost rules, persisted 5-hour toggle and renewal refreshes. 116/116 tests green; three task commits; fresh build launched.
- 2026-10-29: Wave 1 executed (5 parallel fresh-context agents + coordinator integration): XcodeGen shell with Control-Option-Command-L hotkey, Provider protocol + normalized section model, verbatim Codex port, Claude OAuth service + log aggregator + Keychain token provider, Vibe journal aggregator + rate card. Build green; 91/91 tests green.
- 2026-10-29: Plan review passed — research annex re-verified (web subagents + local); refinements folded into tasks 1.4/1.5/2.1 (defensive OAuth decoding, Keychain probe order, journal timestamp-attribution strategy, per-model cached pricing, Codex conformance ownership).
- 2026-10-29: Logged out with plan review as the next pickup; no code yet, everything committed through the plan commit.
- 2026-10-29: /make-plan with three research subagents resolved all five spec open questions (see decisions.md); 13-task plan written, spec approved.
- 2026-10-29: Directions setup, new-project assessment (build now, new app, publish, all three providers in v1), provider data-source investigation, spec written. Initial commit.

## Handoff

- Current handoff: `docs/sessions/2026-10-29.md` → **Resume (pre-clear, end of 2026-10-29 — session 4)** — Wave 3 pickup (3.1 + 3.2) on user request; keep-running fresh build noted.
- Decisions: `docs/decisions.md`
