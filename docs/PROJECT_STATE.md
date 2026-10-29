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

- **Focus:** `specs/multi-provider-usage-hud.md` written; open questions to resolve, then `/make-plan`.
- **Next:** resolve the spec's open questions (Claude plan limits, Vibe cost display, hotkey choice,
  Claude weekly-window semantics), then `/make-plan` to create the first implementation plan.
- **Execution:** no code yet. `01_Project/` is empty; the XcodeGen project is created by the first
  plan. Validation commands are placeholders in `AGENTS.md` until then.

## Recent

- 2026-10-29: Directions setup, new-project assessment (build now, new app, publish, all three
  providers in v1), data-source investigation for all three providers, spec written. Initial commit.

## Handoff

- Current handoff: `docs/sessions/2026-10-29.md`
- Decisions: `docs/decisions.md`
