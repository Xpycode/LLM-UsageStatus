# PROJECT_STATE — LLM-UsageStatus

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **Focus:** Plan ready — `docs/plans/2026-10-29-multi-provider-hud/IMPLEMENTATION_PLAN.md` (13 tasks, 3 waves + 2 external gates). Execution not yet requested.
- **Next:** On `execute`, run Wave 1 (tasks 1.1–1.5, all parallel-ready): app shell, provider abstraction, Codex port, Claude sources, Vibe aggregator. Open questions resolved via three research subagents; spec approved.
- **Execution:** No code yet. `01_Project/` is empty; the plan's Wave 1 creates the XcodeGen project. Validation commands are placeholders in `AGENTS.md` until then.

## Recent

- 2026-10-29 (later): `/make-plan` with three research subagents (web + local): Claude OAuth usage endpoint verified, Mistral pricing/rate card gathered, CUS architecture digested; all five spec open questions resolved (see `docs/decisions.md`); IMPLEMENTATION_PLAN.md written, spec approved.
- 2026-10-29: Directions setup, new-project assessment (build now, new app, publish, all three
  providers in v1), data-source investigation for all three providers, spec written. Initial commit.

## Handoff

- Current handoff: `docs/sessions/2026-10-29.md`
- Decisions: `docs/decisions.md`
