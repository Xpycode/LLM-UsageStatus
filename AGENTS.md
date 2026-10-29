# LLM-UsageStatus — Agent Instructions

## Project Context

- **Purpose:** A dockless macOS HUD showing usage status for multiple LLM CLIs (Codex, Claude Code, Mistral Vibe) in one panel, for publishing to other CLI users.
- **Stack:** Swift / SwiftUI, macOS 15 or newer, XcodeGen-generated project, non-sandboxed.
- **Build:** `cd 01_Project && xcodegen generate && xcodebuild -project LLM-UsageStatus.xcodeproj -scheme LLM-UsageStatus -configuration Debug -destination 'platform=macOS' build`
- **Test:** `cd 01_Project && xcodebuild -project LLM-UsageStatus.xcodeproj -scheme LLM-UsageStatus -configuration Debug -destination 'platform=macOS' -derivedDataPath build/UsageHUD test`
- **Lint:** none

Note: the test bundle is app-hosted (TEST_HOST = the app): running tests launches the dockless app
briefly and registers its global hotkey — treat as an app launch for control-scope purposes.

## Instruction Ownership

- `AGENTS.md` is the entry point for Codex and Mistral Vibe; `CLAUDE.md` is the Claude Code entry point.
- Keep stable project facts aligned, while keeping tool-specific behavior in its own entry point.
- Keep task status/evidence in the selected plan; `docs/PROJECT_STATE.md` selects the plan and one
  current session-log handoff. `docs/TASKS.md` holds backlog/inbox and an Active plan link.
- Directions workflow procedures live in the master `commands/*.md`; do not copy or translate them.

## Directions Workflow

- Local master: `/Users/sim/ProgrammingProjects/0-DIRECTIONS/__DIRECTIONS`
- Use the globally installed `directions` skill for `status`, `log`, `spec`, `make-plan`, `execute`,
  `check`, `decide`, `cookbook`, `worktree`, and other Directions requests.
- Current state: `docs/PROJECT_STATE.md`; active execution: its selected plan; detailed
  history: `docs/sessions/`; durable choices: `docs/decisions.md`.
- Read universal guidance from the Directions master on demand. Do not add copied universal docs to
  this repository.

## Project Rules

- Provider data sources are local files owned by each CLI (`~/.codex/auth.json`, `~/.claude/projects/**/*.jsonl`,
  `~/.vibe/logs/session/unified/*/journal/*.jsonl`) plus the undocumented Codex usage endpoint. Read tokens
  in memory only; never log, persist, or transmit credentials except the existing bearer header to the
  Codex usage service.
- Every provider implements the same `Provider` protocol; the HUD renders one section per provider.
  Additions require a scoped decision first.
- Estimated values must be visibly labeled as estimates; the panel never presents a guess as an
  authoritative allowance.
- A provider whose CLI is not installed shows a "not detected" state; one provider failing never
  breaks the others' sections.
- Display-only app: it never buys credits, redeems passes, or mutates any CLI state.

## Validation

Run in this order where applicable:

```bash
xcodegen generate   # in 01_Project/, once the project exists
xcodebuild ... build
xcodebuild ... test
```

## Known Gotchas

- None yet; add only verified project-specific gotchas here.
