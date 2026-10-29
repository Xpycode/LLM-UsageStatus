# Decisions

Durable, project-specific decisions. Newest first.

---

## 2026-10-29 — Open-question resolutions (from `/make-plan` research)

Researched by three subagents (web + local), evidence in `docs/plans/2026-10-29-multi-provider-hud/IMPLEMENTATION_PLAN.md` research annex.

### Claude: authoritative OAuth endpoint primary, local logs labeled fallback

**Choice:** The Claude section's primary source is the undocumented but widely verified
`GET https://api.anthropic.com/api/oauth/usage` (headers: `Authorization: Bearer <OAuth token>`,
`anthropic-beta: oauth-2025-04-20`), returning `five_hour.utilization/resets_at` and
`seven_day.utilization/resets_at` — the same data Claude Code's own `/usage` shows. The OAuth token is
read from the macOS Keychain items Claude Code maintains (service `Claude Code-credentials`, plus
per-install suffixed variants; verified present on this machine). If the token is unavailable
(Keychain denial, no sign-in), the section falls back to locally aggregated transcript tokens with
estimate labeling. Poll sparingly (refresh-on-open only; community reports 429s under frequent
polling).

**Why:** upgrades Claude from "estimates only" to the same authority tier as Codex; no plan-limit
baselines are encoded anywhere (none are officially published; community figures conflict).

### Claude: no hard-coded weekly window semantics

**Choice:** display `resets_at` from the endpoint; the local fallback shows a rolling 7-day token
aggregate labeled as an estimate. Never hardcode "weekly limit = X tokens" or a fixed reset cadence —
sources conflict (rolling vs account-anchored vs 72h cycles) and Anthropic publishes nothing.

### Vibe: tokens-only display, conditional cost line

**Choice:** the Vibe section shows token aggregates (input/output/cached) from the unified session
store. A derived cost line appears only when a complete price triple resolves for the model —
bundled updatable rate card for known Mistral models (from official pricing: Medium 3.5 $1.50/$7.50,
cached input 10% of input), config prices taking precedence — otherwise the line is hidden. No
allowance/quota framing (pay-per-token; Mistral has no self-serve usage API for standard keys).

### Vibe: unified session store only in v1

**Choice:** read only `~/.vibe/logs/session/unified/*/journal/*.jsonl` (store format
`mistral.vibe.unified-session-store/v1`). Legacy/older Vibe log layouts are out of scope.

### Hotkey: Control-Option-Command-L

**Choice:** `kVK_ANSI_L` with Control-Option-Command modifiers (L for LLM), fresh Carbon signature,
distinct from CodexUsageStatus's Control-Option-Command-X so both apps can run simultaneously.

### Architecture: normalized provider display model

**Choice:** per CUS architecture review: one hotkey toggles one panel; each provider service
conforms to a shared `Provider` protocol and produces a normalized section display model, keeping the
content view pure value-driven (the cleanest extension seams in CodexUsageStatus are the injected
fetch closure, the value-type content inputs, and the per-service generic error enums).

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
