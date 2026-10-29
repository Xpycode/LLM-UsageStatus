# Glossary

Project-specific terms for LLM-UsageStatus.

| Term | Meaning |
|---|---|
| Provider | One LLM CLI integration implementing the app's `Provider` protocol: Codex, Claude Code, or Mistral Vibe |
| HUD | The dockless, draggable status panel toggled by a global hotkey (CodexUsageStatus pattern) |
| Allowance | An authoritative remaining-quota number reported by the vendor (today: Codex only) |
| Usage aggregate | Tokens counted locally from CLI-owned files; presented as fact about consumption, not as remaining quota |
| Estimate | A derived value compared against assumed plan limits; must be labeled as an estimate in the UI |
| Codex auth file | `~/.codex/auth.json` — read in memory for the bearer token sent only to the Codex usage endpoint |
| Claude transcripts | `~/.claude/projects/**/*.jsonl` — per-message `usage` objects with input/output/cache token counts |
| Vibe session store | `~/.vibe/logs/session/unified/<id>/` — chunked session log; `journal/*.jsonl` rows carry per-response `usage` (format `mistral.vibe.unified-session-store/v1`) |
| Not detected | The UI state for a provider whose CLI files are absent on this Mac |
