# Session Index

| Date | Log | Summary |
|---|---|---|
| 2026-11-06 | [2026-11-06.md](2026-11-06.md) | Post-v1 smoke-test fixes: Claude 401 root-caused (stale token, expected); collapsed fallback looked broken → Claude fallback now carries an estimate-labeled glance line with sign-in-state hint. Vibe cost line suppressed by all-unpriced rule → `VibeRateCard` (multi-vendor, adds `zai-glm-5-3`) with visibly labeled partial sums; budget headline still requires full pricing. 140/140 tests green; fresh Debug build handed off (dist/0.1.0 notarized artifact now stale vs source). Next: user smoke test; release rebuild + re-notarization before redistribution |
| 2026-10-29 | [2026-10-29.md](2026-10-29.md) | Spec + 13-task plan; Waves 1–3; Claude token-path diagnosis closed; E1 passed; Wave 4 headline-first redesign + task 4.4 Vibe glance line; panel review fixed the Claude utilization percentage scale and added small secondary windows; provider-logo idea to Inbox. **E2 passed: 0.1.0 signed, notarized (Accepted), stapled, spctl-clean; notarized build handed off. Plan complete — v1 done.** Next: user smoke test; post-v1 work from Backlog/Inbox; distribution needs its own go-ahead |
