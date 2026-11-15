# Reading the Panel

The panel has one section per provider: **Codex**, **Claude Code** and **Mistral Vibe**.

## What a section shows

- One headline per limit window: a round gauge, the percent left until its reset (for example, "68% left") and the window's name (such as "5-hour limit" or "Weekly limit"). Claude Code shows two headlines, the 5-hour and the 7-day limit; Codex shows its weekly limit, plus the 5-hour limit while **Show 5-hour limit** is on.
- Some headlines carry a smaller gauge beside them for a related allowance, such as Claude's **Fable** gauge.
- Hold the pointer over a gauge for its details: the countdown with the share of time left (for example, "Resets in 3d 12h 0m (50% time left)"), the exact reset time, an approximate per-day amount where a remaining amount exists, and whether you are on pace.
- Click the section to expand it for the details the gauges don't show, such as Codex credits and reset passes, and each window's reset countdown.

## Reading a gauge

- The **outer ring** is the usage left; the **inner pie** is the time left until the reset. Both start at 12 o'clock and run down clockwise, like a clock hand sweeping.
- If the ring reaches as far round as the pie or further, you have at least as much usage left as time: you are on pace. The ring is blue (purple for a smaller gauge such as Fable).
- If the ring falls short of the pie, usage is running out faster than time and the ring turns **orange**.
- A gauge without a pie has no known reset time or window length.

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
