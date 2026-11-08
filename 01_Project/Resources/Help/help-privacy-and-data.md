# Privacy and Data Sources

LLM Usage Status is a display-only utility. It does not change anything in Codex, Claude Code or Mistral Vibe.

## What it reads

- **Codex** — your Codex sign-in file (~/.codex/auth.json), sent only to Codex's usage service to fetch your allowance.
- **Claude Code** — the sign-in Claude Code keeps in your Keychain, sent only to Claude's usage service, plus your session logs (~/.claude/projects) for local estimates.
- **Mistral Vibe** — Vibe's local session journals (~/.vibe/logs/session/unified). No network request is made for Vibe.

## Credentials

Sign-in tokens are read in memory when needed. They are never stored, logged or shown by this app. The app never refreshes or modifies them.

## What is stored

Your display preferences are saved: the Codex 5-hour toggle, the Vibe budget and reset day, your chosen shortcut and window positions. The app also keeps the last-seen usage values for each provider in `~/Library/Application Support/LLM-UsageStatus/last-sections.json`, so that after a relaunch the panel can show them, with their timestamps, until the next refresh. No credentials and no longer history are stored.

## What is sent over the network

- Usage requests to the Codex and Claude usage services, as described above.
- **Send Feedback…** sends your message to the developer's server only when you submit the form. No logs or usage data are attached.
- **Leave a Tip** just opens a web page in your browser.

There is no telemetry.
