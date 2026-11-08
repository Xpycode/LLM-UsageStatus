# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.0] - Unreleased

### Added

- Settings window (right-click menu → Settings…, or Command-Comma while the
  panel is showing) with three sections: Startup (launch at login, read from
  macOS's real login-item state), Shortcut (record a new show/hide chord;
  applies immediately and survives restarts) and About (version and build).
- In-app Help: right-click → LLM Usage Status Help opens a searchable Help
  window with topics on the panel, each provider, estimates, the shortcut,
  privacy and troubleshooting. Command-? reopens it while Help or Settings is
  in front. Also available from the shortcut-failure menu.
- Send Feedback… opens a feedback form (message, optional email, app and
  macOS version; no logs, usage data or credentials are attached).
- Leave a Tip opens the app's donate page in the default browser.
- The Claude section's local fallback shows a glance line with the reason
  (for example "Sign-in expired") and a hint to run Claude Code to refresh
  the sign-in.
- Each provider's last populated section is remembered across launches, so a
  relaunch while offline or throttled shows last-known values with honest
  timestamps (stored in `~/Library/Application Support/LLM-UsageStatus/`;
  no credentials).
- Third-party notices for MarkdownUI, NetworkImage and cmark ship in the app.

### Changed

- Shortcut names follow the keyboard layout: on QWERTZ, AZERTY and other
  Latin layouts the footer, recorder and shortcut-failure menu name the key
  printed on the keycap (non-Latin input sources use the last ASCII-capable
  layout). The binding itself is unchanged.
- Vibe cost estimates cover Z.ai GLM models as well as Mistral models; when
  some sessions use an unpriced model the partial total is labeled
  (`total+ · N sessions unpriced`). The budget headline still requires a
  fully priced total.
- Dollar amounts always render as `$10.97`, independent of the system locale.

### Fixed

- Standard Command shortcuts (for example Command-C) are refused as the
  show/hide shortcut (matched by US key position); an unreadable stored shortcut falls back to the default.

## [0.1.0] - 2026-10-29

### Added

- Headline-first sections: every populated section leads with the percent left
  until its next reset and a live countdown, plus an estimated per-day amount
  for the remaining days where a remaining quantity exists.
- On-demand detail: click a section to expand or collapse its full detail;
  hover for a compact tooltip summary. Meters read "X% left".
- Optional Mistral Vibe monthly budget (amount + reset day, right-click menu):
  with a budget set, the Vibe headline shows an estimated percent left and
  dollars-per-day quote; without one, the section shows a compact
  last-24-hours glance line (estimated spend where price-resolvable, plus
  token count).
- Privacy-safe Claude endpoint diagnostics (window presence and utilization).
- Initial dockless multi-provider usage HUD, summoned with Control-Option-Command-L.
- One section per installed CLI — Codex, Claude Code, and Mistral Vibe — with
  absent CLIs shown as "not detected" and per-provider failure isolation.
- Utilization meters and renewal countdowns for every provider's windows.
- Estimate labeling: values that are local estimates or approximations are
  always visibly labeled, never presented as authoritative.
- Codex section: weekly allowance, credits, reset passes, and an optional
  five-hour limit line.
- Claude Code section: subscription utilization with renewal times when signed
  in; labeled local estimates from session logs otherwise.
- Mistral Vibe section: local token aggregates with an estimated cost line only
  when model prices resolve.
- Per-provider preferences in the right-click menu, persisted across
  restarts, with stale and last-updated captions per section.
- Warning menu-bar fallback with Show HUD, Retry Shortcut, and Quit when
  hotkey registration fails.

Requires macOS 15 or later. Codex and Claude usage endpoints are undocumented
and may change. Updates are installed manually.
