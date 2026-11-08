# Decisions

Durable, project-specific decisions. Newest first.

---

## 2026-11-08 — Shortcut names come from the ASCII-capable keyboard layout

**Choice:** `HotKeyShortcut.displayName` names single-character keys (letters, top-row digits, ANSI
punctuation) with `UCKeyTranslate` against `TISCopyCurrentASCIICapableKeyboardLayoutInputSource`,
uppercased, falling back to the US name; non-character keys (F-keys, arrows, Space, Return, keypad…)
keep their spelled-out names. The hotkey binding (virtual key code) is unchanged.

**Why:** the *current* input source can be Cyrillic, Greek or an IME and yields non-Latin or no
names; the ASCII-capable layout is what macOS uses for Command chords and what KeyboardShortcuts and
MASShortcut use (0.2.0 plan, research R1). Backlog 11 had said "current keyboard layout".

---

## 2026-11-08 — Settings window: own hotkey code, self-managed window, three sections

**Choice:** Hotkey rebinding extends the app's own `GlobalHotKey` (multiple ids, configurable
chord) with a small AppKit recorder, instead of adopting the fleet's ShortcutKit package. The
Settings window is a self-managed AppKit `NSWindow` (cookbook #71), not the SwiftUI `Settings`
scene. It holds exactly three sections (Startup, Shortcut, About); the 5-hour toggle and Vibe
budget stay in the right-click menu. Command-Comma is a second Carbon hotkey that exists only
while the panel is visible. Launch at login reads `SMAppService.mainApp.status` live (never a
stored mirror) and is withheld outside an Applications folder.

**Why:** ShortcutKit is a path package outside this repo, so GitHub CI (just made green) couldn't
resolve it. The SwiftUI Settings scene doesn't reliably front a window in a dockless app. The
panel never becomes key, so only a Carbon registration can see Command-Comma, and holding it
system-wide would take it from every other app. A login item registered from a build directory
or Downloads points at a path that breaks later.

**Consequences:** one more hand-rolled recorder in the fleet (revisit if zPackages gets a remote).
Plan: `docs/plans/2026-11-06-settings-window/IMPLEMENTATION_PLAN.md`.

---

## 2026-11-06 — Partial cost sums replace the all-or-nothing Vibe cost line; rate card goes multi-vendor

**Choice:** The Vibe section's cost line (and 24-hour glance line) sums sessions whose model price
resolves from the bundled rate card and labels the remainder: a partial sum renders as
`<priced total>+ · N sessions unpriced`, the glance as `≈ $X+`; a fully priced sum renders as today.
The budget percent-left headline still requires a fully priced sum — a floor would overstate the
money left, and a percent meter cannot carry the "+ · N unpriced" qualifier. When no used session
is priced, the row stays hidden (a "$0.00+" floor says nothing).

The rate card is renamed `MistralRateCard` → `VibeRateCard` and extended beyond Mistral models:
`zai-glm-5-3` added at Z.ai's published GLM-5.3 rates ($1.40 input / $0.26 cached / $4.40 output
per 1M tokens, verified 2026-11-06 against the vendor's pricing page via two independent
sources). This is the model this machine's Vibe sessions actually run, which is why the cost line
had disappeared entirely (Backlog 10).

**Why:** the all-or-nothing rule (any unpriced session suppresses the whole line) meant real
mixed-model usage showed no spend at all — the user rejected that on 2026-11-06 after the
post-notarization smoke test. A visibly labeled floor is honest under the project's estimate rule;
honest competitor pricing belongs in a Vibe-scoped rate card, not one named after a single vendor.

**Consequences:** pricing values are bundled literals that need hand-updating when vendors change
prices (record verification dates beside entries); unknown models still contribute to token counts
and the unpriced-session count, never to the sum. Reasoning tokens remain excluded from cost
(billed as part of output by vendors; they are counted separately in token rows).

---

## 2026-11-06 — Claude local fallback carries a glance line and sign-in-state hint

**Choice:** The Claude fallback (endpoint token missing/rejected/out-of-scope) now builds a
visible one-line glance — `Sign-in expired · N sessions · X tokens · 7 days`, or
`... · no local usage (7 days)` when the store is silent — estimate-labeled, shown collapsed and
expanded. The reason prefix maps from the closed `FetchError` cases, never raw error text.

**Why:** collapsed sections hide rows, and the fallback had no headline, so the degraded section
rendered nothing but its timestamp and looked broken — reported during the 2026-11-06 smoke test.
This stays inside the 2026-10-29 no-in-app-refresh decision: the app still never writes the
Keychain item; the hint only says why the section is local.

**Consequences:** the collapsed Claude section always shows its state; the token-staleness root
cause is unchanged and resolves only by running Claude Code.

---

## 2026-10-29 — No in-app Claude token refresh; stale tokens degrade to labeled local estimates

**Choice:** The app reads the Claude OAuth token from the Keychain item Claude Code owns but never
refreshes or writes it. When the stored access token is expired/rejected (usage endpoint 401), the
Claude section shows the labeled local-log fallback; the user refreshes the sign-in by running
Claude Code itself.

**Why:** the token's refresh flow is Claude Code's internal OAuth client and is undocumented;
implementing our own refresh would write to a Keychain item another app owns, risk invalidating
Claude Code's session, and couple this app to an unstable internal contract. The diagnosis
(2026-10-29) proved the read/decode/fetch path correct — HTTP 401 came from a stale stored token,
and the labeled fallback engaged exactly as designed, so the graceful degradation is the right
steady-state behavior.

**Consequences:** whenever Claude Code has not run recently, the HUD shows labeled local
estimates instead of subscription utilization (acceptable: values are visibly labeled, never
presented as authoritative). E1 includes an explicit check: run Claude Code once, then confirm
the section switches to endpoint utilization.

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
