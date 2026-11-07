# TASKS

- **Plan (retired 2026-10-29):** `docs/plans/2026-10-29-multi-provider-hud/IMPLEMENTATION_PLAN.md` — **COMPLETE**: 17/17 code tasks, E1 passed, E2 passed (notarized 0.1.0, Apple verdict Accepted, stapled, spctl clean). It stays in place as the permanent execution record.
- **Active plan (2026-11-08):** `docs/plans/2026-11-06-settings-window/IMPLEMENTATION_PLAN.md` — Settings window (launch at login, shortcut rebinding, About). 8 tasks + E1; first ready: Wave 1 tasks 1.1–1.4 (no prerequisites). Execution not yet requested.

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
9. **Claude OAuth primary path on this Mac** (2026-10-29, resolved same day): root cause chain
   complete. The `errSecParam` match-all failure was fixed with the match-one fallback (32d2d89);
   after the user answered the pending access prompts, the instrumented build (ce7349f) read the
   item, decoded the expected blob shape (`claudeAiOauth`/`mcpOAuth`), extracted
   `claudeAiOauth.accessToken`, and the usage endpoint returned **HTTP 401** — the stored access
   token is rejected (stale: Claude Code only refreshes it when Claude Code itself runs; this app
   never writes to the item by design). Implementation verified correct end-to-end; the labeled
   local fallback engaged exactly as specified. Endpoint stays primary. Remaining E1 check: run
   Claude Code once to refresh the sign-in, then confirm the HUD's Claude section shows endpoint
   utilization (2xx) instead of estimates.
10. **Vibe cost line with mixed/unresolved models** (2026-10-29; resolved 2026-11-06): the
    all-or-nothing rule had suppressed the cost line for real mixed-model usage (this machine's
    sessions run `zai-glm-5-3`). Resolved by decision 2026-11-06: `MistralRateCard` renamed
    multi-vendor `VibeRateCard` (Z.ai GLM-5.3 rates added), and partial sums render visibly
    labeled (`total+ · N sessions unpriced`); the budget headline still requires full pricing.
    Rate-card prices are bundled literals needing hand-updates when vendors change them.

## Inbox

- Post-v1 baseline features (scoping session 2026-11-06, mapped against Directions
  `33_app-minimums.md` HUD/agent tier; user raised these as "what next" candidates):
  - → **Planned 2026-11-08** in the active plan above. **Settings window (Command-Comma)** including launch-at-login (`SMAppService`) — the
    most-skipped agent-app minimum — hotkey rebinding (ShortcutKit or recorder view), and a
    version-visible About section (version is currently nowhere in the UI). Recommended first:
    local code only, no infrastructure.
  - **Feedback + Donate** via `AppCitizenshipKit` (right-click menu items): needs the app slug
    in `feedback-submit.php` allow-list and `donate.html` registration on the user's site.
  - **In-app help** via the vendored HelpMenu approach, adapted to the dockless panel/menu
    (document Control-Option-Command-L, the Claude sign-in refresh behavior, estimates labeling).
  - **Sparkle auto-update** with EdDSA appcast: gated on the public-distribution go-ahead and
    where the appcast is hosted; last in the sequence by design. Build numbers must stay
    monotonic (`sparkle:version` = build).
- Short-session token-lifetime question (2026-11-06): record how long the Claude OAuth access
  token actually lives between Claude Code runs, to set expectations for seeing "Sign-in expired".


- Provider logos/icons in the HUD sections (suggested 2026-10-29 at the Wave 4 handoff): show
  each provider's logo next to its section title to speed up visual scanning of the panel.
  Considerations before scoping: trademark/licensing of vendor marks in a published,
  notarized app; monochrome/template rendering to fit the HUD aesthetic (and dark material);
  sourcing simple official marks vs. custom glyphs; asset size overhead. Related existing
  Inbox item: app icon design in `02_Design/`.
- Icon design in `02_Design/` (independent of plan waves; does not gate E1/E2 — default Xcode icon acceptable for 0.1.0).
- Vibe "Tokens (all time)" fluctuated across consecutive HUD refreshes (46.9M → 35.2M → 36.8M while
  session count stayed 14, observed 2026-10-29 via user screenshots): the unified store appears to
  rotate/compact sessions, so "all time" may be a mislabel for "all sessions currently in the
  store". Unconfirmed — investigate per-session totals across scans, then consider relabeling.
