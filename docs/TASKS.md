# TASKS

- **Active plan:** `docs/plans/2026-10-29-multi-provider-hud/IMPLEMENTATION_PLAN.md` — 13 tasks, 3 waves; 8/13 complete, next ready IDs: **3.1, 3.2** (Wave 3), then gates E1/E2. The plan owns task status/evidence.

## Backlog

Retained for discoverability; items map into plan tasks (executed work tracks there).

1. Scaffold the XcodeGen app project → plan task 1.1.
2. Provider protocol + HUD layout → plan tasks 1.2, 2.1–2.2.
3. Codex provider port → plan tasks 1.3, 2.1.
4. Claude provider (OAuth endpoint + transcript fallback) → plan tasks 1.4, 2.2.
5. Vibe provider (journal aggregator + rate card) → plan tasks 1.5, 2.2.
6. Preference persistence + renewal timers → plan task 2.3.
7. Tests/fixtures → embedded in every task's backpressure; full pass in 3.2.
8. Distribution pipeline → plan tasks 3.1, E2.
9. **Claude OAuth primary path unverified on this Mac** (2026-10-29, from the running HUD): the
   Keychain item `Claude Code-credentials` exists (metadata read only), but the app got no usable
   token at launch and the section degraded to labeled local aggregates as designed. Next step is
   user-operated: reopen the HUD and watch for a Keychain access prompt (approve it). If no prompt
   appears and the section stays on estimates, the `claudeAiOauth.accessToken` blob decode
   assumption needs verification. Gates the E1 Claude endpoint acceptance criterion.
10. **Vibe cost line with mixed/unresolved models** (2026-10-29): the cost row suppresses entirely
    when any used session's model is not in the rate card (currently only mistral-medium-3.5), so
    real mixed-model usage never shows a cost line. Possible alternative: a per-model or partial
    sum visibly labeled. Scope decision before/with E1.

## Inbox

- Icon design in `02_Design/` (independent of plan waves; does not gate E1/E2 — default Xcode icon acceptable for 0.1.0).
