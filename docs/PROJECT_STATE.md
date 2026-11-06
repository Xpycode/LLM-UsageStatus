# PROJECT_STATE — LLM-UsageStatus

**Last updated:** 2026-11-06 (session 9 — post-v1 smoke-test fixes)

## Identity

**LLM-UsageStatus** — a dockless macOS HUD that shows usage status for multiple LLM CLIs
(Codex/ChatGPT, Claude/Claude Code, Mistral/Vibe) in one panel. Successor concept to
CodexUsageStatus (which covers Codex only and stays as is). Intended for publication:
Developer ID signed, notarized, zero configuration for end users.

- **Stack:** Swift / SwiftUI, macOS 15+, XcodeGen, non-sandboxed (reads CLI-owned files in the user home).
- **Model:** reuse of the proven CodexUsageStatus architecture (NSPanel HUD, global hotkey,
  in-memory token reading), extended with a multi-provider service layer.

## Now

- **V1 complete, plus two post-v1 smoke-test fixes (2026-11-06).** The 17/17-task plan stays
  retired as the permanent record. Notarized 0.1.0 shipped, but `dist/0.1.0` is now **stale vs
  source**: the running app is a fresh Debug build carrying (a) the Claude local-fallback glance
  line with sign-in-state hint (the collapsed degraded section previously looked blank) and
  (b) partial Vibe cost sums under the renamed multi-vendor `VibeRateCard` (adds `zai-glm-5-3`,
  the model this machine's sessions actually run). **Next:** user smoke-tests the two fixes in
  the running Debug build; before any redistribution, rebuild + re-sign + re-notarize dist.
  Remaining candidates: Inbox items (app icon, provider logos, Vibe "all time" fluctuation) and
  public distribution (needs its own go-ahead and a remote).

## Recent

- 2026-11-06: Smoke-test diagnosis (endpoint 401 = stale token; collapsed fallback looked blank)
  and the two approved fixes: Claude fallback glance line + hint, partial Vibe cost sums with
  `VibeRateCard` (zai-glm-5-3 priced at Z.ai's published rates). 140/140 tests green; fresh Debug
  build handed off and running; dist/0.1.0 now stale vs source.
- 2026-10-29: **E2 passed** — 0.1.0 Developer ID signed, Apple verdict Accepted, stapled, spctl clean; notarized build handed off and running. The whole plan is complete.
- 2026-10-29: Task 4.4 (user-selected at the panel review): Vibe without a budget shows a last-24-hours glance line (estimated spend + tokens); fixed an aggregator control-flow bug found on the way. Provider-logo idea captured to Inbox. Utilization-scale defect fixed from the panel review; collapsed sections gained small secondary-window lines; fresh Release build handed off.
- 2026-10-29: E1 passed (live compare against all three vendor dashboards; Claude endpoint proven 2xx after the sign-in refresh). Wave 4 executed serially: headline-first sections, expand/hover detail, Vibe monthly budget; Claude window diagnostics landed — five-hour window confirmed present with over-limit utilization. Utilization-scale defect fixed from the panel review; collapsed sections gained small secondary-window lines; fresh Release build handed off.
- 2026-10-29: Wave 3 executed (2 parallel fresh-context agents): 3.1 release pipeline + repo surface (universal build verified, CI unverified — no remote), 3.2 full verification (119/119 green, 15 fixture renders). Claude endpoint diagnosis resolved (401 = stale token). Fresh dist/0.1.0 Release build handed off and running.
- 2026-10-29: Post-wave HUD review (user screenshots) drove three fixes: malformed-line misclassification (structural records skip silently), Keychain match-all errSecParam (match-one fallback), and 401/403-blind diagnostics (HTTP status + blob key-name logging). Claude endpoint outcome pending the Keychain prompt; Vibe all-time totals instability captured to Inbox.
- 2026-10-29: Wave 2 executed serially (coordinator): HUD views + provider conformances + composition root, Claude local-fallback and Vibe cost rules, persisted 5-hour toggle and renewal refreshes. 116/116 tests green; three task commits; fresh build launched.
- 2026-10-29: Wave 1 executed (5 parallel fresh-context agents + coordinator integration): XcodeGen shell with Control-Option-Command-L hotkey, Provider protocol + normalized section model, verbatim Codex port, Claude OAuth service + log aggregator + Keychain token provider, Vibe journal aggregator + rate card. Build green; 91/91 tests green.

## Handoff

- Current handoff: `docs/sessions/2026-11-06.md` → **Resume (end of 2026-11-06 — session 9)** —
  smoke-test the two fixes in the running Debug build; dist/0.1.0 needs a release rebuild +
  re-notarization before redistribution.
- Decisions: `docs/decisions.md`
