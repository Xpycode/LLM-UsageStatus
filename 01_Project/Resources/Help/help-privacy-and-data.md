# Privacy and Data Sources

LLM Usage Status is a display-only utility. It does not change anything in Codex, Claude Code or Mistral Vibe.

## What it reads

- **Codex** — your Codex sign-in file (~/.codex/auth.json), sent only to Codex's usage service to fetch your allowance.
- **Claude Code** — the sign-in Claude Code keeps in your Keychain, sent only to Claude's usage service, plus your session logs (~/.claude/projects) for local estimates.
- **Mistral Vibe** — Vibe's local session store (~/.vibe/logs/session/unified): the session journals and the per-session usage counters. No network request is made for Vibe.

A provider you turn off in Settings is never read: the app does not open its files, its Keychain item or its usage service.

## Credentials

Sign-in tokens are read in memory when needed. They are never stored, logged or shown by this app. The app never refreshes or modifies them.

## What is stored

Your display preferences are saved: which providers are on, the Codex 5-hour toggle, the Vibe budget and reset day, your chosen shortcut and window positions. The app also keeps the last-seen usage values for each provider in `~/Library/Application Support/LLM-UsageStatus/last-sections.json`, so that after a relaunch the panel can show them, with their timestamps, until the next refresh. No credentials and no longer history are stored.

## What is sent over the network

- Usage requests to the Codex and Claude usage services, as described above.
- **Update checks** — once a day while **Check for updates automatically** is on, and whenever you choose **Check for Updates…**, the app downloads this project's release list (appcast.xml) from GitHub. The request names the app and its version; no system information or usage data is sent.
- **Update downloads** — only after you choose **Install Update**, the app downloads the new version's disk image from GitHub Releases.
- **Send Feedback…** sends your message to the developer's server only when you submit the form. No logs or usage data are attached.
- **Leave a Tip** just opens a web page in your browser.

There is no telemetry.
