# Authoritative vs Estimated

The providers expose different amounts of information, so not every number in the panel means the same thing.

## Authoritative

**Codex** allowance figures (weekly limit, credits, reset passes, and the optional 5-hour limit) come from Codex's own usage service. They are the provider's own numbers.

**Claude Code** subscription utilization (5-hour and 7-day limits, and the Fable allowance where your plan has one) is also reported by the provider's usage service, but only while you are signed in. See Claude Code.

## Estimated

- **Claude Code local fallback** — when the sign-in is unavailable, the section shows figures computed from your local session logs. They are labeled as estimates.
- **Mistral Vibe** — Vibe has no usage service and no allowance. Every figure comes from local files on your Mac. Token totals count input plus output once (cached and reasoning tokens are already inside them), and sub-agent sessions count toward their parent session. Cost is estimated from a built-in price list, and a budget percent is an estimate based on that cost.

## How estimates are marked

Estimated values carry an **estimated** tag or an "(estimated)" suffix. A trailing "+" after an amount, such as "$4.20+", means the real total is at least that much because some sessions could not be priced.

The panel never shows an estimate as an authoritative allowance.
