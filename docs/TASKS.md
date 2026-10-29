# TASKS

- **Active plan:** none yet — run `/make-plan` against `specs/multi-provider-usage-hud.md` after the open questions are resolved.

## Backlog

Mapped to the spec's acceptance criteria (`specs/multi-provider-usage-hud.md`); the plan owns task
status and evidence once created.

1. Scaffold the XcodeGen app project in `01_Project/` (dockless HUD shell, global hotkey, warning-icon fallback) — reuse CodexUsageStatus patterns.
2. Define the `Provider` protocol and the three-provider HUD layout (one section per provider, per-provider failure isolation).
3. Codex provider: port auth-file reading and the usage-endpoint service from CodexUsageStatus.
4. Claude provider: transcript aggregator over `~/.claude/projects/**/*.jsonl` (session and weekly token aggregates, estimate labeling).
5. Vibe provider: session-journal aggregator over `~/.vibe/logs/session/unified/*/journal/*.jsonl`.
6. Preference persistence: which providers are visible, estimate display settings (UserDefaults only).
7. Tests: fixture-based aggregator tests for both log readers, provider-protocol tests, formatter tests.
8. Distribution: Developer ID signing, notarization, release script (adapt `scripts/notarize-release.sh` from CodexUsageStatus).

## Inbox

- Hotkey choice for the new app (CodexUsageStatus uses Control-Option-Command-X).
- Icon design in `02_Design/`.
