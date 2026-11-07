# Research annex — Settings window plan (2026-11-06)

Two agent reports produced during `/make-plan` for the Settings window. Coordinator synthesis
lives in this folder's `IMPLEMENTATION_PLAN.md`; these are the full source reports.

- `web-research.md` — SMAppService semantics and gotchas, Carbon hotkey rebinding pitfalls
  (incl. the Sequoia shift/option-only restriction and cross-process `eventHotKeyExistsErr`),
  LSUIElement Settings-window landmines, version/About conventions. All claims URL-cited.
- `local-conventions.md` — house findings: ShortcutKit public API (`zPackages`), the two house
  settings-window patterns (cookbook #71 self-managed NSWindow vs. Aloft's Settings-scene dance),
  QuickStatsPanel's launch-at-login reference implementation, cookbook #64/#71/#111 summaries,
  and AppCitizenshipKit's status (menu-bar-commands API only).
