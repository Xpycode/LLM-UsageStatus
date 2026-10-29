# Multi-Provider Usage HUD Specification

**Status:** Approved
**Created:** 2026-10-29
**Last Updated:** 2026-10-29 (open questions resolved via subagent research; Claude section upgraded to OAuth-endpoint primary)

---

## Problem Statement

### What problem does this solve?

One glance at the remaining/used usage of all the LLM CLIs the user runs — Codex/ChatGPT,
Claude/Claude Code, Mistral/Vibe — in a single dockless HUD, instead of separate tools or
guesswork. Intended for publication: any user of these CLIs gets it working with zero setup.

### Who has this problem?

Developers using multiple LLM CLIs on macOS; the author first, then the general CLI-user public
after release.

### How do they solve it today?

CodexUsageStatus covers Codex only. Claude Code and Vibe usage are checked by visiting web
consoles or remembering the last `/usage`-style output; nothing shows all three at once.
Recurring daily friction (multiple times per working session).

- Choice and why now: build a new app (not extending CodexUsageStatus) with a clean multi-provider
  architecture — see `docs/decisions.md` 2026-10-29. Proven HUD/hotkey/Codex patterns are reused as
  reference implementations.
- Investment and trade-off: "solid" — a working app with tests, fixtures and a clean provider
  protocol, like CodexUsageStatus; not a full product with settings UI and auto-updater in v1.
- Reconsider when: the Codex usage endpoint breaks irreversibly, the local log formats of Claude
  Code or Vibe change incompatibly with unreasonable maintenance cost, or scope expands beyond
  display-only usage status.

---

## Proposed Solution

### One-Liner

A dockless macOS HUD, toggled by a global hotkey, that shows one usage section per provider —
Codex, Claude Code, Mistral Vibe — each fed by its own service, with zero configuration for the
end user.

### Key Capabilities

1. **Codex section** — authoritative allowance: weekly allowance remaining with renewal countdown,
   credits, available reset passes, optional five-hour limit (port of CodexUsageStatus behavior).
2. **Claude Code section** — authoritative utilization via the undocumented OAuth usage endpoint
   (`GET api.anthropic.com/api/oauth/usage`, token from the Claude Code Keychain items): five-hour
   and seven-day utilization with vendor `resets_at`; fallback to locally aggregated tokens
   (`~/.claude/projects/**/*.jsonl`) clearly labeled as estimates when the token is unavailable.
3. **Mistral Vibe section** — locally aggregated usage: tokens per rolling period (and optionally
   derived cost) from `~/.vibe/logs/session/unified/*/journal/*.jsonl`. Optionally, the user can
   set a monthly budget (amount + reset day; Mistral publishes no allowance API): with a budget,
   the section leads with an estimated percent-left headline and a dollars-per-day quote derived
   from the local cost estimate; without one, it stays token-first with no percentage.
4. **Provider isolation** — a missing CLI shows "not detected"; a failing refresh shows the last
   good values with a failure message; providers never break each other.
5. **HUD interaction** — same interaction model as CodexUsageStatus: global hotkey toggle,
   click-elsewhere dismissal, draggable panel, refresh on open.
6. **Headline-first sections** (accepted 2026-10-29 at E1 review) — every populated section leads
   with one glance line: **percentage left until the next reset** for its primary window, the reset
   countdown, and — where a remaining quantity exists (Codex credits, Vibe budget) — an estimated
   per-day amount for the remaining days, visibly labeled as an estimate. Utilization meters render
   as "X% left". The full detail (meters, token counts, credits, passes, sessions, cost) is
   available on demand: click a section to expand it inline, click again to collapse; hovering
   shows a compact tooltip summary.

### User Flow

1. Source/input: CLI-owned local files (`~/.codex/auth.json`, `~/.claude/projects/**/*.jsonl`,
   `~/.vibe/logs/session/unified/*/journal/*.jsonl`) and the Codex usage endpoint.
2. User action: presses the global hotkey.
3. Destination/output: the HUD panel shows one section per provider with refreshed values.
4. Observable outcome: each installed CLI's numbers appear within seconds; absent CLIs show
   "not detected"; nothing is configured by the user.

### Usefulness or Feasibility Check

- Uncertainty: none on data availability (verified 2026-10-29 on this machine — see
  `docs/decisions.md`). Remaining feasibility questions are format stability, handled below.
- Smallest check: fixture-based readers for both log formats produce correct aggregates — part of
  the plan's acceptance, not a separate experiment.

---

## Acceptance Criteria

### Core Functionality

- [ ] Given all three CLIs installed and signed in, when the user toggles the HUD, then all three
      sections show current values and a last-updated time.
- [ ] Given Codex signed in, when the Codex section refreshes, then it shows weekly allowance
      remaining with renewal countdown, credits, and available reset passes, matching
      CodexUsageStatus semantics (unavailable fields labeled as such, never guessed).
- [ ] Given Claude Code is signed in and its OAuth token is readable, when the Claude section
      refreshes, then it shows five-hour and seven-day utilization with reset times from the OAuth
      usage endpoint.
- [ ] Given the Claude OAuth token is unavailable but transcripts exist, when the Claude section
      refreshes, then it falls back to locally aggregated token counts visibly labeled as estimates.
- [ ] Given Vibe sessions exist, when the Vibe section refreshes, then it shows rolling-period
      token aggregates from the session journals.
- [ ] Given a provider's CLI is not installed, when the HUD opens, then that section shows
      "not detected" and the other sections still populate.
- [ ] Given the user presses the hotkey, when the panel is hidden, then it shows; when visible,
      then it hides (with the CodexUsageStatus hotkey-registration failure fallback: warning-icon
      menu with Show HUD / Retry Shortcut / Quit).
- [ ] Given the app is launched by a user who has never configured anything, when the HUD opens,
      then every section populated purely from existing CLI-owned files — no API keys, no sign-in,
      no preferences required.
- [ ] Given a populated section, when the HUD renders, then the section leads with the percentage
      left for its primary window and its reset countdown (Codex: weekly; Claude: seven-day, or
      five-hour when that is what the endpoint returns; Vibe: monthly budget when configured).
- [ ] Given a section with a quantifiable remaining amount, when the headline renders, then it
      shows the estimated per-day amount for the remaining days, visibly labeled as an estimate.
- [ ] Given a populated section, when the user clicks it, then it expands to show the full detail;
      clicking again collapses it; hovering shows a compact tooltip summary of the detail.
- [ ] Given the user configured a Vibe monthly budget, when the Vibe section refreshes, then the
      headline shows an estimated percent left and dollars-per-day quote until the configured
      reset; given no budget is configured, then the Vibe section shows no percentage.
- [ ] Given any quantity is rendered, when it is formatted, then thousands grouping is correct and
      consistent for the user's locale (no mangled separators).

### Edge Cases

- [ ] Given a provider refresh fails, when the panel is open, then prior values remain with an
      update-failed message and the last successful update time.
- [ ] Given malformed or partially unreadable log lines, when aggregation runs, then valid lines
      are counted and the section notes incomplete data rather than failing entirely.
- [ ] Given empty or fresh CLIs with no sessions yet, when the HUD opens, then sections show
      zero/none states without errors.
- [ ] Given very large transcript or journal files, when the HUD opens, then aggregation completes
      without blocking the UI unacceptably (bounded reading, off-main-thread).

### Error States

- [ ] Given the Codex endpoint is unreachable, when the Codex section refreshes, then it shows the
      failure and retains prior values; other sections are unaffected.
- [ ] Given the Codex auth file is missing, when the HUD opens, then the Codex section shows
      "not detected".

---

## Technical Considerations

### Dependencies

- SwiftUI, AppKit (NSPanel), Carbon/RegisterEventHotKey — as proven in CodexUsageStatus.
- XcodeGen for project generation; no third-party runtime dependencies intended.

### Architecture Notes

- `Provider` protocol (Swift, actor-based services) with three implementations; a
  `UsageSnapshot`-style shared display model per section; HUD view renders sections independently.
- File readers must be resilient: line-by-line JSON parsing, skip-and-count malformed lines.
- Codex service: port from CodexUsageStatus including its decoder and no-credential-logging rules.
- App is non-sandboxed to read user-home CLI files; distribution via Developer ID + notarization
  (same as CodexUsageStatus; see Directions `61_distribution-notarization.md` at release time).

### Performance

- Aggregation reads potentially thousands of JSONL lines; run off the main actor, refresh on panel
  open (not continuous polling), like CodexUsageStatus.

### Security

- The Codex bearer token/account header is read in memory and sent only to the Codex usage
  service; never logged, never persisted (CodexUsageStatus rule, unchanged).
- No credentials exist for Claude/Vibe paths — the readers touch only token-count data, not
  conversation content; transcript contents must not be logged or retained by the app.

---

## Out of Scope

- Settings UI, editable hotkey, launch-at-login, About/Help window, auto-updater (CodexUsageStatus
  parity: none of these in v1).
- Cost/billing display for Codex or Claude beyond vendor-reported numbers; Vibe cost display is an
  open question, not a v1 promise.
- Buying credits, redeeming passes, or any state mutation in the CLIs.
- Windows/Linux, menu-bar (non-HUD) presentation, iOS.
- Reading Claude Code or Vibe conversation contents for anything but token counts.

---

## Open Questions

| Question | Status | Answer |
|----------|--------|--------|
| Which Claude plan limits to encode as estimate baselines (Pro vs Max tiers), and are they configurable per install? | Resolved | None encoded. Primary source is the OAuth usage endpoint (authoritative utilization + resets_at); local-log fallback shows tokens as labeled usage facts, no plan baselines — no officially published numbers exist and community figures conflict. See decisions 2026-10-29. |
| Should the Vibe section show derived cost from model prices, or tokens only? | Resolved | Tokens-only primary; a derived cost line appears only when a price triple resolves for the model (bundled updatable rate card; config prices take precedence), hidden otherwise. |
| Which global hotkey (CodexUsageStatus uses Control-Option-Command-X)? | Resolved | Control-Option-Command-L. |
| Claude weekly window semantics: rolling 7 days vs calendar week (community tools disagree)? | Resolved | Display the endpoint's `resets_at`; local fallback shows a rolling 7-day aggregate labeled as an estimate; no hardcoded cadence. |
| Display "sessions" from Vibe's older non-unified session logs too, or only the unified store? | Resolved | Unified store only in v1; legacy layouts out of scope. |

---

## Related

- Decisions: `docs/decisions.md` (2026-10-29 entries)
- Reference implementation: `/Users/sim/ProgrammingProjects/1-macOS/CodexUsageStatus`
- Sessions: `docs/sessions/2026-10-29.md`
