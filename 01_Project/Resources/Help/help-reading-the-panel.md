# Reading the Panel

The panel has one section per provider: **Codex**, **Claude Code** and **Mistral Vibe**.

## What a section shows

- A headline with the percent left until the next reset (for example, "68% left") and a live countdown such as "Resets in 2d 4h 10m".
- Where a remaining amount exists, an approximate per-day amount (for example, "≈ 7417273 credits/day").
- Click the section to expand it for meters, rows and reset times.

## Status lines

Small lines at the bottom of each section tell you its state:

- **Updating…** — a refresh is in progress.
- **Update failed · showing previous values** — the last refresh failed. The previous values stay on screen. Close and reopen the panel to try again.
- **Last updated** — when the values were last fetched.
- **Reset time passed · awaiting updated usage** — a reset time has passed and fresh numbers have not arrived yet.

## Section states

- **Not detected on this Mac.** — the provider's command-line tool or its data files were not found. Install the tool and use it once, then reopen the panel.
- **Loading … usage…** — the first load is running.
- **Unable to load usage. Please try again.** — the first load failed. You also see "Dismiss and reopen to retry."

Each section is independent: one provider failing does not affect the others.

## Estimate tag

Values that are estimates carry the label **estimated** or **(estimated)**. See Authoritative vs Estimated.
