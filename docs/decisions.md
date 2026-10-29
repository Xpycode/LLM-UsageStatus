# Decisions

Durable, project-specific decisions. Newest first.

---

## 2026-10-29 — Build a new app instead of extending CodexUsageStatus

**Choice:** New app in this repository (`LLM-UsageStatus`); CodexUsageStatus stays untouched.

**Why:** A clean multi-provider architecture from the start (one `Provider` protocol, three
implementations) beats retrofitting a single-provider app; CodexUsageStatus remains a stable,
already-published utility. The proven parts (HUD panel, hotkey, Codex service) are reused as
reference implementations, not forked blindly.

**Alternatives rejected:** extending CodexUsageStatus in place (risks the working app, muddies its
identity); a web/status-bar tool (inconsistent with the established HUD UX).

---

## 2026-10-29 — Provider data sources and the honesty rule

**Choice:**
- Codex: `~/.codex/auth.json` bearer token + the undocumented Codex usage endpoint (as CodexUsageStatus does today).
- Claude Code: aggregate local transcripts `~/.claude/projects/**/*.jsonl`; no quota endpoint exists.
- Mistral Vibe: aggregate local session journals `~/.vibe/logs/session/unified/*/journal/*.jsonl`
  (verified format `mistral.vibe.unified-session-store/v1`, per-response `usage` objects).

**Rule:** Codex allowance numbers are authoritative; Claude and Vibe numbers are locally aggregated
usage and any limit framing is an estimate. Estimates are always visibly labeled; the panel never
presents a guess as an authoritative allowance.

**Why:** verified on 2026-10-29 by inspecting the actual files on this machine; Anthropic exposes no
subscription-limit endpoint and Mistral Vibe is pay-per-token with no allowance concept.

---

## 2026-10-29 — Zero-configuration for distributed users

**Choice:** The app reads files each CLI already maintains; no API keys, sign-ins, or configuration
inside the app. Distribution model identical to CodexUsageStatus: non-sandboxed, Developer ID
signed, notarized.

**Why:** any user of the three CLIs already has these files; setup cost for a new user is zero.
