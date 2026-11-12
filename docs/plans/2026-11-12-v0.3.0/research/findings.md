# 0.3.0 research findings (2026-11-12)

Coordinator code reading on this Mac (R1) plus two parallel web research agents (R2 Claude usage
endpoint fields, R3 Sparkle facts). No project files were edited during research.

## R1 — Local code findings

### Headlines and the Codex 5-hour toggle

- `ProviderSection.headline: SectionHeadline?` (`Sources/Shared/Models/ProviderModels.swift:84`);
  `SectionHeadline` has no stable id — it is identified by `windowLabel`.
- Claude picks **one** headline, the next-resetting window
  (`ClaudeUsageProvider.swift:81-102`), so the 7-day window is nearly always only a grey
  collapsed caption (`UsageStatusView.swift:139-146`, `secondaryMeters`).
- Codex emits one weekly headline with the credit daily-budget quote
  (`CodexUsageProvider.swift:67-81`).
- Vibe emits one budget headline (unchanged by this release).
- **Latent quirk:** `ProviderSectionView` receives `showFiveHourLimit: preferences.showCodexFiveHourLimit`
  for **every** store (`UsageStatusView.swift:33-34`) and filters meters by
  `id != "five-hour-limit"` (`:185-186`) and deadlines by `id != "five-hour-reset"` (`:207`).
  Claude uses the same ids, so with the Codex toggle off the expanded Claude section hides its
  5-hour meter and countdown. The new always-on Claude 5-hour headline must not be subject to the
  Codex toggle; scope the toggle to `store.providerID == "codex"`.
- Consumers of `headline`: the view (headline render, `secondaryMeters`, tooltip), the three
  providers, `SectionStateCache` (Codable), tests `ProviderModelsTests`, `SectionStateCacheTests`
  (`testFullSectionSurvivesEncodeDecodeRoundTrip`), `SectionFixtures` (codex/claude/vibe
  sections and the collapsed headline scenarios), `ClaudeUsageProviderTests` (:55, :70),
  `CodexUsageProviderTests`, `VibeUsageProviderTests`, `UsageStoreTests`.
- `SectionStateCache` decodes `[String: ProviderSection]` with synthesized Codable
  (`SectionStateCache.swift:45`). A key rename without a compatibility decoder makes the whole
  file fail to decode: `[:]` plus one error log — accepted by the user, but a `decodeIfPresent`
  compatibility path (`headlines` else `[headline]`) costs a few lines and keeps the relaunch seed
  for users updating from 0.2.2.
- Render tests (`SectionFixtureRenderTests`) write PNGs under derived data; the checked-in copies
  live in `docs/verification/2026-10-29-multi-provider-hud/fixtures/` and are **not** compared
  against — a layout change needs no golden update, only plausible non-empty renders.

### Claude OAuth usage decoder

- `ClaudeOAuthUsageService.Envelope` decodes only `five_hour` and `seven_day`
  (`ClaudeOAuthUsageService.swift:124-143`); every other top-level key is dropped. A 2xx logs
  presence + rounded utilization per window at `.notice` (`:108-109`), never timestamps or ids.
- `utilization` is a percentage (2.0 = 2 % used; verified live 2026-10-29), normalized to 0...1.
- `resets_at` accepts ISO-8601, epoch number or epoch string (`FlexibleReset`).
- A key-names-only diagnostic fits at `:103` after a successful decode: `JSONSerialization` on the
  body, sorted top-level keys plus, for each object value, its sorted sub-keys; `.debug` level,
  `privacy: .public`, no values. Key names carry no account data.
- The Codex side already has the "reset passes" shape to mirror: row `reset-passes`
  (`CodexUsageProvider.swift:63-64`) and the `pass-expiry` deadline (`:51-59`), from
  `ResetSummary` (`UsageSnapshot.swift:45-77`).

### Sparkle integration points

- No Sparkle anywhere in the project today (`grep -ril sparkle` empty). The 0.2.2 app has **no**
  `Contents/Frameworks` — Sparkle will be the first nested framework the release pipeline meets.
- `project.yml` uses `GENERATE_INFOPLIST_FILE: YES` with `INFOPLIST_KEY_*` settings. Sparkle's
  `SUFeedURL`/`SUPublicEDKey` are not on Apple's allowlist (cookbook 156 / 16): they need the
  **Method 3** partial `Info.plist` via `INFOPLIST_FILE`, verified with `PlistBuddy` on the built
  bundle. The `Resources` glob must exclude that plist like it excludes the entitlements file.
- `.gitignore` ignores `Package.resolved` and `**/*.xcodeproj/project.xcworkspace/`, so the
  Sparkle dependency must be pinned with `exactVersion` in `project.yml` for reproducible release
  builds and CI.
- `scripts/release.sh` builds with `-derivedDataPath dist/<version>/DerivedData`; after the build
  the Sparkle tools are deterministic at
  `dist/<version>/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/{sign_update,generate_keys}`.
- `scripts/notarize-release.sh` signs **only the outer app** (`codesign --force --options runtime
  --timestamp --sign "$identity" "$app"`, no `--deep`). The tracked project sets no
  `CODE_SIGN_IDENTITY`, so Xcode's Release build is ad-hoc signed; the re-sign flips the outer
  bundle to Developer ID. With Sparkle embedded, the nested `Sparkle.framework` (and its
  `Autoupdate`, `Updater.app`, `XPCServices/*.xpc`) would keep a non-Developer-ID signature:
  hardened-runtime library validation rejects a framework from another team id at launch, and
  notarization rejects unsigned/non-Developer-ID nested executables. The script must sign the
  nested components **inside-out** with the same identity, hardened runtime and timestamp before
  the outer app, and verify with `codesign --verify --deep --strict`.
- Menu structure (`AppDelegate.makeMenu`, `:227-251`): [Show 5-hour limit, Set Vibe Monthly
  Budget…] | Settings…, LLM Usage Status Help, Restart LLM Usage Status | Send Feedback…, Leave a
  Tip | Quit. The hotkey-fallback status-item menu (`:200-225`) repeats Show HUD, Retry Shortcut,
  Settings…, Help, Quit. Windows opened from the menu hide the panel first (`openSettings`,
  `openHelp`).
- Settings sections (`SettingsWindowController.buildContent`, `:132-137`): Providers, Startup,
  Shortcut, About; AppKit `NSButton` checkboxes and buttons; the window sizes to fit.
- `LaunchAtLogin.refreshRegistrationIfEnabled()` already runs at launch "after an app update the
  login item can point at the old copy" — a Sparkle-installed update keeps launch-at-login valid.
- The vendored `AppCitizenshipKit`/`FeedbackKit` contain no updater support (grep empty); the
  cookbook's `UpdaterCommands` pattern is SwiftUI `.commands`, not applicable to this AppKit menu.
- syncthingStatus (the reference app): Sparkle 2.8.1 via SPM (`from: 2.6.0`), feed
  `https://raw.githubusercontent.com/Xpycode/syncthingStatus/main/appcast.xml`,
  `SUEnableAutomaticChecks` true (no first-launch prompt), DMG enclosures from GitHub Releases
  with `sparkle:version` = build number, hand-edited appcast items, `sign_update` on the DMG,
  cask `auto_updates true`. Its EdDSA key lives in the login Keychain (account `ed25519`, label
  "Private key for signing Sparkle updates"); the key was **lost once** (2025-12-31) and broke the
  update chain for one version — the private key must be backed up outside the repo at creation.
  syncthingStatus is sandboxed and needed `SUEnableInstallerLauncherService`; this app is not
  sandboxed, so no XPC accommodations apply.
- `ThirdPartyNotices.txt` lists MarkdownUI and NetworkImage only; Sparkle (MIT) must be added.
- Help, README (`:150` "Updates are installed manually for now; built-in automatic updates are
  planned.", Privacy section `:202-216`), `docs/homebrew.md` (step 3 + the closing Sparkle line)
  and the cask all have update-related text to change.

### Test hygiene

- Four test files create `UserDefaults(suiteName:)` domains with UUID names
  (`UsagePreferencesTests:8`, `HotKeyShortcutTests:12`, `ShortcutRecorderFieldTests:19`,
  `VibeUsageProviderTests:320`). All call `removePersistentDomain(forName:)`, yet
  `~/Library/Preferences` holds 84 `LLMUsageStatusTests.UsagePreferences-*.plist` and 12
  `VibeUsageProviderTests.Budget*.plist` files of 42 bytes (an empty `{}` plist). cfprefsd leaves
  the empty file behind; tearDown must also remove the file at
  `~/Library/Preferences/<suite>.plist` after the domain removal. The HotKey/ShortcutRecorder
  suites leave nothing (they never write a value, so no file is created).
- Two Swift warnings (`ShortcutRecorderField.swift:30` unnecessary `nonisolated(unsafe)`;
  `ClaudeLogAggregator.swift:144` deprecated `String(cString:)`) are still in the TASKS Inbox.

## R2 — Claude OAuth usage endpoint: Fable window and limit resets (web)

Web research agent, 2026-11-12. No official schema exists; everything is community
reverse-engineering. Confidence: **C** = code that parses live responses, **D** = pasted response
dump, **P** = prose only. Live confirmation on this Mac (E0) is still required before anything ships.

**Top-level keys seen in 2026**

| Key | Shape | Source | Conf. |
|---|---|---|---|
| `five_hour`, `seven_day`, `seven_day_oauth_apps`, `seven_day_opus`, `seven_day_sonnet` | `{utilization: 0–100, resets_at: ISO}`; each may be `null` | [CodexBar ClaudeOAuthUsageFetcher.swift](https://github.com/steipete/CodexBar/blob/main/Sources/CodexBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthUsageFetcher.swift); [iwato usage.go](https://github.com/mtsmfm/iwato/pull/112) (2026-11-11) | C |
| `limits[]` | row: `kind` (`"session"` / `"weekly_all"` / `"weekly_scoped"`), `group` (`"session"` / `"weekly"`), `percent` (0–100 **used**), `resets_at` (ISO), `scope` (`null` or `{model: {id: null, display_name: "Fable"}, surface: null}`), `is_active` (bool) | dumps: [onWatch #121](https://github.com/onllm-dev/onWatch/issues/121) (2026-09-01), [claude-code #87419](https://github.com/anthropics/claude-code/issues/87419) (2026-08-17), [Claude-Code-Usage-Monitor #56](https://github.com/CodeZeno/Claude-Code-Usage-Monitor/issues/56) (2026-07-11); code: CodexBar `ClaudeWebExtraRateWindowParser.swift`, iwato | C + D |
| `extra_usage` | `is_enabled`, `monthly_limit`, `used_credits`, `utilization`, `currency` | CodexBar | C |
| `weekly_scoped_shares[]` | per scoped limit, its share of the weekly limit (Fable = 50 %); appeared about 2026-10-08 | [shepherdjerred #4033](https://github.com/shepherdjerred/monorepo/pull/4033) (2026-10-23) | P |
| `seven_day_breakdown` | `as_of`, `window_started_at`, `rows[] {display_name, key, percent}` | [opscope #245](https://github.com/stealth-factory/opscope/issues/245) (2026-09-16) | P |
| `cedar_ember` | reset inventory, **opt-in** (see below) | [CodexBar #3895](https://github.com/steipete/CodexBar/issues/3895) (2026-09-23) | D + C |
| `iguana_necktie`, `seven_day_routines`, `seven_day_cowork`, `spend`, `locked_reason` | other surfaces; not needed here | CodexBar docs / probe list | C / P |

`seven_day_opus` / `seven_day_sonnet` are `null` on current accounts in every 2026 dump.

**Fable window.** No `seven_day_fable` key exists in any public source
([claude-code #88137](https://github.com/anthropics/claude-code/issues/88137), open, 2026-08-20,
confirms its absence). The Fable meter is the `limits[]` row with `kind == "weekly_scoped"` and
`scope.model.display_name == "Fable"` (code-confirmed in CodexBar and iwato, matching the dumps).
`scope` was a string before about 2026-11 and is now an object
([claude-limits #1](https://github.com/Livecounter86/claude-limits/pull/1)) — decode both.
`resets_at` of the Fable row equals the weekly reset in every dump; the help centre states a Fable
reset does not move the weekly reset
([What is a limit reset?](https://support.claude.com/en/articles/17007452-what-is-a-limit-reset)).
`percent` is **relative to Fable's own cap**, not to the weekly limit — inferred: in all four dumps
Fable % exceeds the all-models % (12 vs 7, 16 vs 14, 43 vs 26, 19 vs 11), impossible for a slice of
the weekly total; the [dev.to status-line author](https://dev.to/suruseas/and-in-my-claude-code-status-line-now-watching-fable-5fln)
reads it the same way. Anthropic states nothing. Fable is included (50 % cap) on Max / Ultra /
premium Team / Enterprise; Pro uses credits
([Fable models on your plan](https://support.claude.com/en/articles/15424964-claude-fable-models-on-your-plan)),
so the row may be absent on Pro — parse every key as optional.

**Reset credits ("Limit resets: N available").** Only returned with the query `?cedar_ember=1`
**and** a `User-Agent: claude-cli/<version> (external, cli)` header; otherwise `cedar_ember` is
`null` or `{eligible: false, ineligible_reason: "surface"}` (`"cli_version"` when the version is
stale). Shape (verbatim from CodexBar #3895):

```json
"cedar_ember": {"eligible": true, "grants": [{"id": "<grant id>", "label": "<description>",
  "resets_total": 1, "resets_left": 1, "starts_at": "<ISO>", "ends_at": "<ISO>",
  "clears": ["five_hour", "seven_day"], "paused": false, "usable_now": true,
  "use_requires_limit": false}], "next_grant_id": "<grant id>"}
```

"N available" = sum of `resets_left` over unpaused, started, unexpired grants; expiry = min
`ends_at`. Whether a grant is a full or a Fable-only reset is contested between tools
([oh-my-pi #18661](https://github.com/can1357/oh-my-pi/pull/18661) vs
[frugalbar #162](https://github.com/seankoji-com/frugalbar/pull/162)). Polling `?cedar_ember=1`
every five minutes produced persistent 429s with long `Retry-After` in October 2026
([OpenTokenUsage #33](https://github.com/poweruserz/OpenTokenUsage/pull/33),
[mimir #88](https://github.com/erayendes/mimir/issues/88)).

**Planner reading.** The resets inventory is deliberately gated to the Claude Code surface
(`ineligible_reason: "surface"`); reaching it means presenting a Claude-CLI user agent this app is
not, and it carries a documented 429 cost that would also hit the primary usage fetch. That is a
product decision for the user, not a field-name question → **deferred out of 0.3.0** (Backlog), see
plan decision D10. The Fable sub-meter needs no extra parameters and is in scope.

**429 / polling.** 429 body `{"error": {"type": "rate_limit_error", …}}`, `retry-after` often
`0` or absent; about five requests per token and then minutes-to-hours of 429s (unverified; Anthropic
closed the reports as not planned — [#30930](https://github.com/anthropics/claude-code/issues/30930),
[#31637](https://github.com/anthropics/claude-code/issues/31637)). Expired tokens also yield 429
([TokenTracker #608](https://github.com/xiufengsun/TokenTracker/issues/608)). Community practice:
poll no more than every five minutes per account; honour `Retry-After`. This app refreshes only on
panel open and on passed deadlines, which already fits.

## R3 — Sparkle facts as of November 2026 (web)

Web research agent, 2026-11-12. Sources: Sparkle source and docs at tag 2.10.1, GitHub API, live
HTTP headers, Homebrew docs, actions/runner-images.

**Release and package**
- Latest stable **2.10.1** (2026-10-25). 2.10.0 (2026-09-13) raised the minimum deployment to
  macOS 12 and removed CocoaPods; `Package.swift` declares `platforms: [.macOS(.v12)]`, binary
  target `Sparkle-for-Swift-Package-Manager.zip`. https://github.com/sparkle-project/Sparkle/releases
- SPM URL `https://github.com/sparkle-project/Sparkle`. `SPUStandardUpdaterController` keeps
  `init(startingUpdater:updaterDelegate:userDriverDelegate:)`; `SPUUpdater.setFeedURL:` is
  deprecated (use `SUFeedURL` or `feedURLString(for:)`). 2.9.0 (2026-02-22) added signed feeds
  (`SURequireSignedFeed`), Markdown release notes, `sparkle:minimumUpdateVersion`; 2.9.4
  (2026-07-03) fixed backgrounded/dockless apps not bringing user-initiated windows to the front
  (#2890). https://raw.githubusercontent.com/sparkle-project/Sparkle/2.10.1/Sparkle/SPUUpdater.h
- **Open risk:** issue #2880 (2026-05-28, closed "completed" with no linked fix) — on macOS 26
  Tahoe, `Autoupdate` failed with EPERM creating `~/Library/Caches/<bundle-id>/…/Installation` for
  non-sandboxed Developer-ID apps (2.9.1/2.9.2). Which release fixed it is unconfirmed → E5 on this
  Mac (macOS 27) is the proof. https://github.com/sparkle-project/Sparkle/issues/2880

**Tools**
- `generate_keys` stores a generic-password item in the login Keychain: service
  `https://sparkle-project.org`, account `ed25519` by default (**`--account <name>` overrides**),
  label "Private key for signing Sparkle updates", comment carrying the public key. `-p` prints the
  public key; `-x <file>` exports (base64 seed); `-f <file>` imports on another Mac.
  https://raw.githubusercontent.com/sparkle-project/Sparkle/2.10.1/generate_keys/main.swift
- `sign_update` signs any file (DMG is fine: "put the app in a .dmg, .zip, .tar.* or .aar"; the
  EdDSA signature is over the file). `generate_appcast` supports `--download-url-prefix`, `--link`,
  `--full-release-notes-url`, `-o`, `--ed-key-file`, `--account`, `--embed-release-notes`,
  `--maximum-versions`; it rewrites only items whose archive is present in the folder and preserves
  the rest. Hand-rolled items (syncthingStatus) remain valid. https://sparkle-project.org/documentation/publishing/

**Hosting on GitHub**
- `raw.githubusercontent.com` serves `text/plain; charset=utf-8`, `cache-control: max-age=300`,
  HTTPS/ATS-fine. Sparkle's parser ignores the MIME type (`NSXMLDocument`), so the feed works; a
  five-minute cache delay after a push is the only cost. Precedent: Maccy (LSUIElement menu-bar app)
  uses a raw-GitHub `SUFeedURL`, and its cask livechecks it with `strategy :sparkle`.
  https://github.com/p0deje/Maccy/blob/master/Maccy/Info.plist
- **Caveat:** release notes fetched through `sparkle:releaseNotesLink` from raw GitHub render as
  plain text (MIME). Embed the notes in `<description>` and point `sparkle:fullReleaseNotesLink` at
  the GitHub Release page instead. (`SUUpdateAlert.m` 225–243)

**Dockless (LSUIElement) apps**
- Since 2.2.0, scheduled-update alerts for dockless apps are shown **behind** other apps except at
  launch; user-initiated checks activate the app. Implement `SPUStandardUserDriverDelegate` with at
  least `supportsGentleScheduledUpdateReminders`; the docs' "Background App" example switches the
  activation policy to `.regular` while the alert is up and back to `.accessory` afterwards.
  `NSApp.activate()` alone is unreliable for background apps on recent macOS;
  `activate(ignoringOtherApps:)` or the temporary policy switch works.
  https://sparkle-project.org/documentation/gentle-reminders/ ; https://developer.apple.com/forums/thread/836619
- With `SUEnableAutomaticChecks` **absent** Sparkle prompts on the second launch; YES or NO
  suppresses the prompt. `SUScheduledCheckInterval` default 86400 (minimum 3600);
  `SUAutomaticallyUpdate` default NO. https://sparkle-project.org/documentation/customization/

**Signing and notarization**
- XPC services are not needed for non-sandboxed apps (`SUEnableInstallerLauncherService` /
  `SUEnableDownloaderService` default NO; "don't enable for non-sandboxed apps").
  https://sparkle-project.org/documentation/sandboxing/
- Shipped helpers are ad-hoc signed with the hardened runtime; Xcode's Archive → Distribute
  re-signs them. **Never add `--deep` to signing** (verification with `--deep --strict` is fine).
  A scripted re-sign must therefore sign the nested components itself, inside-out.
- "App is damaged" after download: `ditto` AppleDouble-encodes xattrs (`com.apple.provenance`);
  a plain `unzip` materializes `._*` files that break the nested `Installer.xpc` signature. Create
  zips with `ditto -c -k --sequesterRsrc --keepParent`; extract with `ditto -x -k`.
  https://furbo.org/2020/12/01/codesign-the-saga-continues/ ; https://sparkle-project.org/documentation/publishing/

**Homebrew**
- `auto_updates true`: "Asserts that the cask artifacts auto-update. Use if Check for Updates… is
  present in an app menu." `brew upgrade` compares the installed bundle's version with the cask
  version: a Sparkle-updated app ahead of the cask is skipped, an older one is upgraded; `--greedy`
  forces. Add `livecheck { url <appcast>; strategy :sparkle }`.
  https://docs.brew.sh/Cask-Cookbook ; https://docs.brew.sh/FAQ

**CI**
- `macos-15` runner image (2026-08-24) defaults to Xcode 16.4 (`macos-latest` is now macOS 26 on
  arm64, so keep `runs-on: macos-15`). Binary-target resolution downloads from GitHub release
  assets (network is standard). Pitfall: stale cached binary artifacts → "checksum does not match";
  clear SourcePackages/DerivedData. No Xcode 16.4-specific Sparkle 2.10.1 issue was found.
  https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md
