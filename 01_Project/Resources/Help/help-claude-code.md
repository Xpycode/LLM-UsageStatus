# Claude Code

## When you are signed in

If Claude Code is signed in on this Mac, the section shows your subscription utilization as reported by Claude's usage service, as two headlines:

- **5-hour limit** — percent left, a countdown to its reset and a bar.
- **7-day limit** — percent left, a countdown to the weekly reset and a bar.

Click the section to expand it for the meters and the exact reset times. These values are authoritative.

## Fable allowance

On plans that include Fable models with their own allowance (such as Max), a smaller bar under the 7-day headline reads, for example, "Fable allowance: 87% left". It is the percent left of your Fable allowance, not of the whole weekly limit. The Fable allowance can use up to half of your weekly limit and resets together with it.

If Claude does not report a Fable allowance for your account, for example on Pro, the bar does not appear. That is expected.

## When you are not

If the sign-in cannot be used, the section falls back to local estimates computed from your Claude Code session logs for the last 7 days. The first line says why, followed by session and token counts:

- **No Claude sign-in** — no Claude Code sign-in was found.
- **Sign-in expired** — the stored sign-in was rejected.
- **Sign-in lacks usage scope** — the stored sign-in cannot read usage.

For example: "Sign-in expired · 12 sessions · 3.4M tokens · 7 days". If there is no local activity, it reads "… · no local usage (7 days)". Expanded, the section lists Sessions, Input tokens, Output tokens, Cache creation and Cache read. All of these are estimates.

## Refreshing an expired sign-in

LLM Usage Status never refreshes or changes your sign-in itself. It only reads it.

To fix **Sign-in expired**:

1. Run Claude Code once.
2. Close and reopen the panel.

The section note reads "Run Claude Code to refresh the sign-in." Whenever Claude Code has not run recently, the panel may show estimates instead of subscription utilization. That is expected.
