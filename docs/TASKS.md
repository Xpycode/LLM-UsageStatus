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
9. **Claude OAuth primary path on this Mac** (2026-10-29, updated same day): root cause of the
   silent failure found — `SecItemCopyMatching` with `kSecMatchLimitAll` + `kSecReturnData`
   returns `errSecParam` on this macOS build; fixed with a match-one fallback (32d2d89). The
   read now reaches the item and blocks on the standard macOS access prompt; a prompt is
   **pending on screen** for the running instance (PID 66578). Next: user clicks Always Allow,
   then read the app log — the instrumented build (ce7349f) logs the exact HTTP status and the
   credentials blob's key names (privacy-safe). If 401/403, scope/token acceptance is the
   remaining question for the E1 Claude criterion.
10. **Vibe cost line with mixed/unresolved models** (2026-10-29): the cost row suppresses entirely
    when any used session's model is not in the rate card (currently only mistral-medium-3.5), so
    real mixed-model usage never shows a cost line. Possible alternative: a per-model or partial
    sum visibly labeled. Scope decision before/with E1.

## Inbox

- Icon design in `02_Design/` (independent of plan waves; does not gate E1/E2 — default Xcode icon acceptable for 0.1.0).
- Vibe "Tokens (all time)" fluctuated across consecutive HUD refreshes (46.9M → 35.2M → 36.8M while
  session count stayed 14, observed 2026-10-29 via user screenshots): the unified store appears to
  rotate/compact sessions, so "all time" may be a mislabel for "all sessions currently in the
  store". Unconfirmed — investigate per-session totals across scans, then consider relabeling.
