# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

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
