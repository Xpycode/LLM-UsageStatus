# Implementation Plan — 0.3.0 (Sparkle auto-updates, Claude two headlines, Fable allowance)

> **Persists across sessions.** Execute using the shared `commands/execute.md` procedure.
> Repair scheduling errors while preserving task IDs, completed evidence and approved scope.
> Task state/evidence is authoritative here; TASKS links here and holds backlog/inbox.
> Follow the master's `reference/task-state.md` for legacy reconciliation and archival.

**Progress:** 8/10 tasks complete (0.1, 1.1–1.4, 2.1–2.3); E0 passed; E1–E5 open. D2, D4, D10
and D11 confirmed by the user 2026-11-12. Wave 0 done 2026-11-12 (`109957c`); Wave 1 done 2026-11-12
(`1581e8a`, `0349627`, `2835494`, `0ffbc79`); Wave 2 done 2026-11-12 (`b327b10`, `b987e61`,
`04d0ece`, `3c83c41`; CI green on `04d0ece`, 279 tests). Wave 3 (3.1 → 3.2) is ready. Execution so
far was requested wave by wave (Wave 0, Wave 1, Wave 2).
**Task states:** unchecked = pending / implemented-unverified / blocked (name gate);
checked = complete with required evidence. Task identity includes this plan path plus ID.

## Goal

Ship a Developer ID–notarized **0.3.0 (300)** release with three outcomes:

1. **The app updates itself.** Sparkle 2 with an EdDSA-signed `appcast.xml` in this repository
   (branch `main`) pointing at the notarized DMGs on GitHub Releases. "Check for Updates…" in the
   right-click menu and a Settings **Updates** section; automatic daily checks with no first-launch
   prompt; the update installs only after the user accepts the alert.
2. **Claude's weekly limit is as prominent as the 5-hour one.** The Claude section shows two full
   headlines (percent left, countdown, bar) for the 5-hour and the 7-day limit. Codex shows a second
   5-hour headline while its "Show 5-hour limit" toggle is on. The Codex toggle no longer hides
   Claude's 5-hour meter.
3. **Claude's Fable allowance is visible.** A debug-level, key-names-only diagnostic of the usage
   response ships, and a smaller **Fable allowance** meter sits under the 7-day headline when the
   endpoint reports the Fable limit. The "Limit resets" inventory is **deferred** (D10).

Journeys:
- **Updates:** right-click → **Check for Updates…** → Sparkle's alert comes to the front and says
  the app is up to date (the feed holds items up to the running build). When a newer item exists,
  the alert offers it; **Install Update** downloads the DMG from GitHub Releases, verifies the EdDSA
  signature, replaces the app and relaunches it. Settings → Updates → untick **Check for updates
  automatically** → no scheduled checks. Proof before a 0.3.1 exists: E5 updates a local,
  lower-versioned build to the published 0.3.0 through the live feed.
- **Claude headlines:** open the panel. The Claude section reads "N% left · 5-hour limit · Resets
  in …" with a bar, then "M% left · 7-day limit · Resets in …" with a bar. With Claude Code signed
  in on a Max account, a smaller "Fable allowance: K% left" bar sits under the 7-day headline.
  Codex: turn **Show 5-hour limit** on → a second "5-hour limit" headline appears under "Weekly
  limit"; off → it disappears, and the Claude section is unchanged either way.
- **Release:** `scripts/notarize-release.sh 0.3.0` signs the nested Sparkle framework inside-out and
  the outer app, notarizes and staples; `scripts/package-dmg.sh 0.3.0` makes the DMG; the GitHub
  Release carries the DMG; `scripts/make-appcast-item.sh 0.3.0` signs the DMG with the EdDSA key and
  inserts the item; the cask gains `auto_updates true`; the website follows `docs/homebrew.md`.

Research: `research/findings.md` (R1 local code, R2 Claude usage endpoint fields, R3 Sparkle facts),
with sources.

## Scope decisions

Recorded 2026-11-12 from the TASKS Inbox, `docs/decisions.md` (2026-11-12, Sparkle feed in this
repo) and the 2026-11-12 session log. Items marked **planner** were recommendations; the user
confirmed all four (D2, D4, D10, D11) as written on 2026-11-12.

- **D1 — Feed and enclosures.** `SUFeedURL` is
  `https://raw.githubusercontent.com/Xpycode/LLM-UsageStatus/main/appcast.xml` (the syncthingStatus
  pattern). Each item's enclosure is the notarized DMG attached to the GitHub Release
  (`…/releases/download/vX.Y.Z/LLM-UsageStatus-X.Y.Z.dmg`), `sparkle:version` = build number,
  `sparkle:shortVersionString` = marketing version, `sparkle:minimumSystemVersion` = 15.0, an
  embedded HTML `<description>` from the CHANGELOG entry and `sparkle:fullReleaseNotesLink` to the
  GitHub **Release page** (`…/releases/tag/vX.Y.Z`; raw-GitHub HTML would render as plain text,
  R3). The live `appcast.xml` on `main` is production: an item is added only after its DMG is live
  (E3 order). Raw GitHub caches for five minutes.
- **D2 — EdDSA key (confirmed 2026-11-12; security-sensitive).** Generate on this Mac with the resolved Sparkle
  package's `generate_keys` (login Keychain, service `https://sparkle-project.org`). Use a key **of
  its own** for this app with `generate_keys --account LLM-UsageStatus` (option confirmed in R3;
  `sign_update --account LLM-UsageStatus` then signs with it) so loss or compromise never touches
  syncthingStatus's key in the default `ed25519` account. Export it once with `generate_keys -x` to
  `/Users/sim/ProgrammingProjects/99-AUTH/LLM-UsageStatus-sparkle-eddsa.key` (outside the repo;
  `*.key` is gitignored anyway) because syncthingStatus lost its first key and broke one update hop.
  The public key goes into the partial `Info.plist`; `docs/sparkle-signing.md` records the public
  key, the Keychain item and the import command for the other Mac (`generate_keys -f`). Never
  commit, print or log the private key. **Go-ahead given 2026-11-12** for the Keychain write and the
  one-time `99-AUTH` export in 0.1.
- **D3 — Check policy.** `SUEnableAutomaticChecks` = true in the plist (no first-launch permission
  prompt, as syncthingStatus), default 24-hour interval, no `SUAutomaticallyUpdate` (install only
  after the user accepts), no system profiling. Settings exposes the automatic-check toggle.
- **D4 — UI placement (confirmed 2026-11-12 as drawn below; UI-changes protocol satisfied).** Modelled on the existing items: "Settings…" (`AppDelegate.makeMenu`) and the
  AppKit checkboxes/buttons of `SettingsWindowController`.
  - **Right-click menu:** "Check for Updates…" directly **after "Settings…"**, before "LLM Usage
    Status Help". Disabled while Sparkle reports it cannot check (a check in progress). Like
    Settings…, it hides the panel first because the alert is a window.

    ```
    Show 5-hour limit · Set Vibe Monthly Budget…
    ──────────
    Settings…
    Check for Updates…          ← new
    LLM Usage Status Help
    Restart LLM Usage Status
    ──────────
    Send Feedback… · Leave a Tip
    ──────────
    Quit LLM Usage Status
    ```

  - **Hotkey-fallback status-item menu:** the same item after "Settings…".
  - **Settings window:** a new **Updates** section between **Shortcut** and **About**:

    ```
    UPDATES
    [x] Check for updates automatically
    [ Check for Updates… ]
    Last checked 12 Nov 2026 at 14:02     (or "Never checked")
    ```

    `NSButton(checkboxWithTitle:)` and `NSButton(title:)`, as in Startup and Shortcut; the window
    keeps sizing to fit. No SwiftUI controls (`47_project-ui-conventions.md`).
- **D5 — Version 0.3.0, build 300** (monotonic; `sparkle:version` compares builds: 300 > 202). Set in
  0.1 so every build and test in this plan reports 0.3.0 (300).
- **D6 — Info.plist.** `SUFeedURL`, `SUPublicEDKey` and `SUEnableAutomaticChecks` are not on Apple's
  `INFOPLIST_KEY_` allowlist (cookbook 156). Use **Method 3**: a committed partial
  `01_Project/Resources/Info.plist` holding only those three keys, `INFOPLIST_FILE` pointing at it,
  `GENERATE_INFOPLIST_FILE: YES` and the existing `INFOPLIST_KEY_*` settings kept; the `Resources`
  glob excludes the plist like the entitlements. Verified on the **built** bundle with `PlistBuddy`
  and by a unit test on `Bundle.main`.
- **D7 — Pinned Sparkle.** `project.yml` adds the package with `exactVersion: 2.10.1` (latest
  stable, 2026-10-25, minimum macOS 12 — R3) because `Package.resolved` is gitignored; CI
  (`macos-15`, Xcode 16.4) and release builds resolve the same revision. XcodeGen embeds the dynamic
  framework; the built app must contain `Contents/Frameworks/Sparkle.framework`.
- **D8 — Release pipeline.** Sparkle is the first nested framework this pipeline meets. New
  `scripts/sign-app.sh <App.app>` signs **inside-out** with the Developer ID, hardened runtime and
  timestamp: `Sparkle.framework/Versions/B/XPCServices/*.xpc`, `Autoupdate`, `Updater.app`, the
  framework, then the app; verifies with `codesign --verify --deep --strict --verbose=2`. `--deep`
  is used for **verification only**, never for signing (Sparkle docs, R3). `notarize-release.sh`
  calls it instead of its single outer `codesign`. Both zip steps (`release.sh`,
  `notarize-release.sh`) become `ditto -c -k --sequesterRsrc --keepParent` so AppleDouble `._*`
  files can never break the nested `Installer.xpc` signature when a user extracts with `unzip`. A
  `SIGN_ONLY=1` mode (or running `sign-app.sh` alone) exercises signing on a scratch Release build
  without contacting Apple (2.3). New `scripts/make-appcast-item.sh VERSION`: runs the resolved package's `sign_update`
  (deterministic path `dist/VERSION/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/`) on
  `dist/VERSION/LLM-UsageStatus-VERSION.dmg`, HEAD-checks the Release asset URL (refuses unless
  `--allow-missing`), inserts or **replaces** the `<item>` for that version (newest first; never two
  items for one version — the `61_distribution-notarization.md` same-version gotcha), validates with
  `xmllint --noout`, and prints the diff. Appcast items are hand-reviewed before the push.
- **D9 — Headlines model.** `ProviderSection.headline: SectionHeadline?` becomes
  `headlines: [SectionHeadline]` in display order; `SectionHeadline` gains a stable `id`
  (`five-hour`, `seven-day`, `weekly`, `budget`) and `subMeters: [SectionMeter]` (default empty, for
  Fable). Order: the shorter window first (5-hour, then 7-day or weekly); the credit daily-budget
  quote stays on Codex's weekly headline. The view hides the `five-hour` headline, meter and deadline
  **only for the Codex store** while the toggle is off (fixes the latent quirk from R1: today the
  Codex toggle also hides Claude's 5-hour meter and countdown). The 0.2.2 cache file decodes through
  a compatibility path (`headline` → `[headline]`, missing `id` → `primary`), so a relaunch after
  updating keeps its last-seen seed (strictly better than the accepted "decodes as empty" outcome;
  no extra format work).
- **D10 — Fable in, limit resets out (confirmed 2026-11-12, from R2).** The Fable meter is the `limits[]` row with
  `kind == "weekly_scoped"` and a scope whose model display name is "Fable" (`scope` as object or
  legacy string); `percent` is used-percent of Fable's own allowance; `resets_at` equals the weekly
  reset. No extra request parameters are needed. The names are code-confirmed in two public tools
  and three response dumps, and **E0 confirms them live on this Mac before 2.1 is accepted**. The
  "Limit resets" inventory (`cedar_ember`) is served only with `?cedar_ember=1` **and** a
  Claude-CLI user agent; it is gated to the Claude Code surface (`ineligible_reason: "surface"`) and
  polling it caused persistent 429s in October 2026. Presenting this app as the CLI is not a
  field-name question but a product decision → **deferred to Backlog #16** with the evidence; the
  user can bring it back as its own item.
- **D11 — Hygiene (confirmed 2026-11-12; in scope).** Test tearDowns
  also delete the empty `~/Library/Preferences/<suite>.plist` that `removePersistentDomain` leaves
  behind; the 96 existing leftovers are deleted once (go-ahead); the two compiler warnings
  (`ShortcutRecorderField.swift:30`, `ClaudeLogAggregator.swift:144`) are fixed.
- **Not in scope:** Backlog #14 (budget since reset day), #15 (system hotkeys), provider logos,
  limit resets (new #16), Sparkle delta updates, silent installs, the website redesign (App-Websites
  session; E3 only bumps version, date, checksum and adds the GitHub/Homebrew links if still open).

## Acceptance Criteria

- [x] The built app's `Info.plist` has `SUFeedURL` (D1), a 32-byte base64 `SUPublicEDKey` and
      `SUEnableAutomaticChecks` true, **and** keeps `CFBundleDisplayName` and `LSUIElement`;
      `Contents/Frameworks/Sparkle.framework` is present.
- [ ] "Check for Updates…" exists in the right-click menu and the fallback menu; Settings has the
      Updates section (D4). In a 0.3.0 build against a feed whose newest item is 202, the alert
      appears **in front** and says the app is up to date. Unticking automatic checks persists.
- [ ] The updater does not start inside the app-hosted test process (no network from tests).
- [ ] A lower-versioned, Developer-ID-signed local build updates to the published 0.3.0 through the
      live feed, verifies the signature, relaunches and shows Version 0.3.0 (300) (E5).
- [ ] `notarize-release.sh` output passes `codesign --verify --deep --strict`; the nested
      `Sparkle.framework` and its executables carry the Developer ID team `FDMSRXXN73` and the
      hardened runtime; Apple's verdict is Accepted with no issues in `notarytool log`.
- [ ] `appcast.xml` validates, holds one item per version, newest first, with `length` and
      `sparkle:edSignature` matching the published DMG; the raw URL serves it with HTTP 200.
- [ ] Claude (endpoint path): headlines are exactly `five-hour` then `seven-day`, each with percent
      left, countdown and bar; no grey collapsed caption remains for the 7-day window. Codex:
      `weekly` always, `five-hour` only while the toggle is on; the daily-budget quote is on `weekly`
      only. Vibe: unchanged (`budget`). The Codex toggle never changes the Claude section.
- [ ] A 0.2.2-format `last-sections.json` decodes into one-headline sections without a log line; a
      0.3.0 file round-trips every field including `subMeters`.
- [ ] With a `limits[]` Fable row in the response, the 7-day headline carries one sub-meter
      `fable-allowance` "Fable allowance" with fraction = percent / 100 (clamped), rendered as a
      smaller bar under the headline and in the tooltip; without the row, nothing is rendered and no
      log line appears. The diagnostic logs key names only (top level and one level down), at
      `.debug`, never values.
- [x] E0 shows the live response's key names; the Fable row's presence or absence is recorded.
- [ ] Help, README, CHANGELOG, `docs/homebrew.md`, `ThirdPartyNotices.txt` (Sparkle MIT) and the
      cask (`auto_updates true`) describe the new behaviour; no "Updates are installed manually for
      now" text remains; no shortcut glyphs; the help manifest is valid JSON.
- [ ] Notarized 0.3.0 (300): GitHub Release, appcast item, cask, website and `dl.php` all serve the
      same DMG checksum; About shows Version 0.3.0 (300) after installation.
- [ ] (D11) After a full local or CI test run no `LLMUsageStatusTests.*`/`VibeUsageProviderTests.*`
      plist is left in `~/Library/Preferences`; the Release build log has zero Swift warnings.

## Execution schedule and ownership

- **Execution scope and limits.** Execution has been requested wave by wave (Wave 0, then Wave 1, both
  2026-11-12). Each of these needs an explicit go-ahead from the user when reached:
  - ~~generating the EdDSA key (login Keychain write) and exporting it to `99-AUTH` (D2)~~ —
    **given 2026-11-12**;
  - ~~deleting the 96 leftover test plists in `~/Library/Preferences` (D11)~~ — **given and done
    2026-11-12** (Wave 2);
  - pushing (CI) — **given for Wave 2 2026-11-12** (pushed `04d0ece`); later pushes ask again;
  - notarization (contacts Apple, uses the `99-AUTH` notarytool key);
  - creating the GitHub Release and pushing `appcast.xml` / the cask (the feed is production);
  - deploying the website;
  - installing into `/Applications`;
  - the E5 self-update test (quits the installed copy, launches a lower-versioned local build;
    the install click itself is user-operated).
  The standing fresh-build handoff authorization covers launching fresh Debug/Release builds
  after gracefully quitting the identified running instance; clicks and keystrokes stay with the
  user. No in-app profile replacement, no app-hosted test runs without a go-ahead.
- **Coordinator-owned files and resources:**
  - `01_Project/project.yml`, `xcodegen generate`, the tracked `.xcodeproj`, package resolution;
  - `01_Project/Resources/Info.plist` (created in 0.1), `01_Project/Resources/Licenses/ThirdPartyNotices.txt`,
    `01_Project/Resources/Help/*`, `README.md`, `CHANGELOG.md`, `Casks/*`, `docs/*` (plan, state,
    tasks, decisions, `homebrew.md`; `docs/sparkle-signing.md` is owned by 1.4 in Wave 1);
  - `appcast.xml` content after Wave 1 (1.4 writes the skeleton; items are coordinator-added);
  - the Keychain key, `99-AUTH`, `dist/`, DerivedData and scratch build folders, git.
- **New files** are pre-created as empty stubs by the coordinator in 0.1, followed by
  `xcodegen generate`, before agents are dispatched: `Sources/App/UpdateController.swift`,
  `Tests/App/UpdateControllerTests.swift`, `Tests/Support/TestDefaults.swift`,
  `Resources/Info.plist`, `scripts/sign-app.sh`, `scripts/make-appcast-item.sh`, `appcast.xml`,
  `docs/sparkle-signing.md`. Sources and tests are folder globs, so agents never touch the project.
- **Test-running limit (carried over).** The test target is app-hosted: running it launches the app
  and registers its hotkey. Local backpressure is `xcodebuild build-for-testing`; the full suite
  runs on GitHub CI (244 tests on 0.2.2). A local `xcodebuild test` needs a go-ahead and a check of
  startup effects first (`34_testing.md`) — new in 0.3.0: the host app must not start the Sparkle
  updater under XCTest (1.1). Tests must compile on Xcode 16.4 (no `super` in async
  `setUp`/`tearDown` of `@MainActor` classes). No test may contact the network or the Keychain.
- **Interfaces fixed before dispatch:**

```swift
// 1.1 — Sources/App/UpdateController.swift (AppKit; no SwiftUI)
@MainActor final class UpdateController: NSObject {
    /// Wraps SPUStandardUpdaterController; `startingUpdater: false` under XCTest and in tests.
    init(startingUpdater: Bool)
    var canCheckForUpdates: Bool { get }                 // mirrors SPUUpdater.canCheckForUpdates (KVO)
    var canCheckForUpdatesChanged: ((Bool) -> Void)?     // menu/Settings enablement
    var automaticallyChecksForUpdates: Bool { get set }  // SPUUpdater property (Sparkle persists it)
    var lastUpdateCheckDate: Date? { get }
    func checkForUpdates()                               // NSApp.activate() first: agent app, alert in front
}
// SettingsWindowController.init gains `updates: UpdateController` (Updates section, D4).

// 1.2 — Sources/Shared/Models/ProviderModels.swift
struct SectionHeadline: Equatable, Sendable, Codable {
    let id: String                       // "five-hour" | "seven-day" | "weekly" | "budget"
    let windowLabel: String
    let fractionLeft: Double             // clamped 0...1
    let resetsAt: Date?
    let dailyBudget: SectionDailyBudget?
    var isEstimate = false
    var subMeters: [SectionMeter] = []   // smaller bars under the headline; decodeIfPresent → []
    init?(id: String, windowLabel: String, fractionLeft: Double, resetsAt: Date? = nil,
          dailyBudget: SectionDailyBudget? = nil, isEstimate: Bool = false, subMeters: [SectionMeter] = [])
}
struct ProviderSection {                 // `headline` removed
    let headlines: [SectionHeadline]     // display order
    init(rows: = [], meters: = [], deadlines: = [], headlines: [SectionHeadline] = [],
         glanceLine: = nil, note: = nil, lastUpdated: Date)
    // Codable: decode "headlines"; else legacy "headline" → [headline] (id "primary" when absent);
    // encode "headlines" only.
}

// 1.3 — Sources/Shared/Services/Claude/ClaudeOAuthUsageService.swift
struct ClaudeOAuthUsage: Equatable, Sendable {
    let fiveHour: ClaudeUsageWindow?
    let sevenDay: ClaudeUsageWindow?
    let fable: ClaudeUsageWindow?        // limits[] row: kind "weekly_scoped", scope model display name "Fable"
    let fetchedAt: Date
    init(fiveHour: ClaudeUsageWindow?, sevenDay: ClaudeUsageWindow?, fable: ClaudeUsageWindow? = nil, fetchedAt: Date)
}
enum ClaudeUsageKeyDiagnostic {
    /// Sorted top-level key names plus, for object values, their sorted sub-keys; arrays report
    /// the sub-keys of their first object. Never values. e.g. `five_hour{resets_at,utilization} limits[is_active,kind,…]`
    static func summary(_ data: Data) -> String
}

// 1.4 — scripts (zsh, `set -euo pipefail`, syntax-checked with `zsh -n`)
scripts/sign-app.sh <App.app>            # inside-out Developer ID signing + --deep --strict verify; SIGN_ID env as today
scripts/make-appcast-item.sh <VERSION> [--allow-missing]   # sign_update the DMG, HEAD-check the Release URL, insert/replace <item>
```

| Wave | Tasks | Mode | Why |
|---|---|---|---|
| 0 | 0.1 | coordinator | Shared files only: package, version, plist, key, stubs, `xcodegen generate` |
| 1 | 1.1, 1.2, 1.3, 1.4 | 4 parallel agents | No mutual prerequisites; disjoint files (table below) |
| 2 | 2.1, 2.2 (agents), 2.3 (coordinator) | parallel | 2.1 needs 1.2 + 1.3 integrated; 2.2 needs 1.1 + 1.2 (shared test files); 2.3 needs 1.1 + 1.4 and this Mac's identity |
| 3 | 3.1 → 3.2 | serial, coordinator | Shared docs; review needs everything integrated |

Wave 1 ownership (exclusive):

| Task | Owns |
|---|---|
| 1.1 | `Sources/App/UpdateController.swift`, `Sources/App/AppDelegate.swift`, `Sources/App/SettingsWindowController.swift`, `Tests/App/UpdateControllerTests.swift`, `Tests/App/ShortcutRecorderFieldTests.swift` (only the `SettingsWindowController` smoke-test call site) |
| 1.2 | `Sources/Shared/Models/ProviderModels.swift`, `Sources/Features/UsageStatus/Views/UsageStatusView.swift`, `Sources/Shared/Services/Claude/ClaudeUsageProvider.swift`, `Sources/Shared/Services/CodexUsageProvider.swift`, `Sources/Shared/Services/Vibe/VibeUsageProvider.swift` (headline → headlines only), `Tests/Shared/Models/ProviderModelsTests.swift`, `Tests/Features/UsageStatus/SectionStateCacheTests.swift`, `Tests/Features/UsageStatus/SectionFixtures.swift`, `Tests/Features/UsageStatus/SectionFixturePreviews.swift`, `Tests/Features/UsageStatus/UsageStoreTests.swift`, `Tests/Shared/Services/Claude/ClaudeUsageProviderTests.swift`, `Tests/Shared/Services/CodexUsageProviderTests.swift`, `Tests/Shared/Services/Vibe/VibeUsageProviderTests.swift` |
| 1.3 | `Sources/Shared/Services/Claude/ClaudeOAuthUsageService.swift`, `Tests/Shared/Services/Claude/ClaudeOAuthUsageServiceTests.swift` |
| 1.4 | `scripts/sign-app.sh`, `scripts/notarize-release.sh`, `scripts/release.sh` (zip flag only), `scripts/make-appcast-item.sh`, `appcast.xml` (skeleton), `docs/sparkle-signing.md` |

Wave 2 ownership (exclusive):

| Task | Owns |
|---|---|
| 2.1 | `ClaudeUsageProvider.swift`, `UsageStatusView.swift` (sub-meter rendering only), `SectionFixtures.swift`, `ClaudeUsageProviderTests.swift` |
| 2.2 | `Tests/Support/TestDefaults.swift`, `Tests/Features/UsageStatus/UsagePreferencesTests.swift`, `Tests/App/HotKeyShortcutTests.swift`, `Tests/App/ShortcutRecorderFieldTests.swift`, `Tests/Shared/Services/Vibe/VibeUsageProviderTests.swift` (tearDown only), `Sources/App/ShortcutRecorderField.swift`, `Sources/Shared/Services/Claude/ClaudeLogAggregator.swift` |
| 2.3 | scratch build folders, `dist/` dry-run output, the 2.3 report |

## Tasks

### Wave 0 (coordinator preparation — shared files)

- [x] **0.1**: Sparkle package, version 0.3.0 (300), partial Info.plist, EdDSA key, stubs
  - Depends on: none. External gates: none — the key go-ahead (D2) was given 2026-11-12.
  - Owns: `project.yml`, `.xcodeproj`, `Resources/Info.plist`, the stubs listed above.
  - Success:
    - `project.yml`: `packages.Sparkle` (`url: https://github.com/sparkle-project/Sparkle`,
      `exactVersion` per R3/D7); app target `dependencies: - package: Sparkle`;
      `MARKETING_VERSION "0.3.0"`, `CURRENT_PROJECT_VERSION "300"`; app target
      `INFOPLIST_FILE: Resources/Info.plist`; `Resources` excludes `Info.plist`.
    - `xcodebuild -resolvePackageDependencies` succeeds; the Sparkle tools exist under the
      DerivedData `SourcePackages/artifacts/sparkle/Sparkle/bin/`.
    - Key: `generate_keys` (with the account option per D2) → public key recorded; `generate_keys -x`
      export to `99-AUTH`; `ls -l` of the export (name and size only) in the log. Nothing printed
      beyond the public key.
    - `Resources/Info.plist`: `SUFeedURL`, `SUPublicEDKey`, `SUEnableAutomaticChecks` only.
    - Built Debug app (`build-for-testing`): `PlistBuddy` shows `SUFeedURL`, `CFBundleDisplayName`,
      `LSUIElement`, `CFBundleShortVersionString` 0.3.0 / `CFBundleVersion` 300, and
      `Contents/Frameworks/Sparkle.framework` exists.
    - Stubs created; `xcodegen generate`; the project file committed before dispatch.
  - Backpressure: `build-for-testing` succeeds; the PlistBuddy lines above.
  - **Evidence (2026-11-12, `109957c`):** Sparkle 2.10.1 resolved; tools in
    `SourcePackages/artifacts/sparkle/Sparkle/bin/` (`generate_keys`, `sign_update`,
    `generate_appcast`, `BinaryDelta`). **Public key** `8giDlCjMm8dDBkP3qu2C4hv80xmLg//AACmoHRnn624=`
    (32 bytes), login Keychain item service `https://sparkle-project.org`, account `LLM-UsageStatus`
    (no prior key under that account). Export `99-AUTH/LLM-UsageStatus-sparkle-eddsa.key`, 44 bytes,
    mode 600; a CryptoKit check confirmed the export derives the same public key. Built Debug app:
    `SUFeedURL` per D1, `SUPublicEDKey` as above, `SUEnableAutomaticChecks` true, `CFBundleDisplayName`
    "LLM Usage Status", `LSUIElement` true, 0.3.0 / 300, `Contents/Frameworks/Sparkle.framework`
    present (`Versions/B`: `Autoupdate`, `Updater.app`, `XPCServices/{Downloader,Installer}.xpc`);
    no `Contents/Resources/Info.plist` copy. **TEST BUILD SUCCEEDED**; only the two known D11
    warnings (2.2).

### Wave 1 (parallel — no mutual dependencies; disjoint ownership)

- [x] **1.1**: Sparkle wiring — `UpdateController`, menu items, Settings Updates section (D3, D4)
  - Depends on: 0.1. External gates: E1 (alert in front, toggle persistence). D4 confirmed 2026-11-12.
  - Owns: see table. Interface: `UpdateController` as fixed above.
  - Success:
    - `UpdateController` wraps `SPUStandardUpdaterController(startingUpdater:updaterDelegate:userDriverDelegate:)`,
      observes `canCheckForUpdates` by KVO, and is the `SPUStandardUserDriverDelegate`:
      `supportsGentleScheduledUpdateReminders` returns true (Sparkle otherwise warns for dockless
      apps), and `standardUserDriverWillHandleShowingUpdate(_:forUpdate:state:)` brings the alert
      to the front for scheduled updates too — since 2.2.0 Sparkle shows them **behind** other
      apps for LSUIElement apps; use `NSApp.activate(ignoringOtherApps: true)` and, if that proves
      unreliable on macOS 27, the documented temporary `.regular` activation policy, restored to
      `.accessory` in `standardUserDriverWillFinishUpdateSession` (R3). User-initiated checks are
      activated by Sparkle 2.9.4+ itself; `checkForUpdates()` still activates first as belt and
      braces. A later release may replace the activation with an "update available" line in the HUD.
    - `AppDelegate` creates one controller at launch with `startingUpdater: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil`
      (no updater under XCTest), adds **Check for Updates…** after Settings… in `makeMenu` and in
      the fallback menu, enabled from `canCheckForUpdates`, hiding the panel first.
    - `SettingsWindowController(…, updates:)` adds the **Updates** section (D4): the checkbox reads
      and writes `automaticallyChecksForUpdates`; the button calls `checkForUpdates()` and follows
      `canCheckForUpdates`; the caption shows `lastUpdateCheckDate` ("Last checked …" /
      "Never checked") and refreshes when the window becomes key.
    - Tests (`UpdateControllerTests`, app-hosted, no network): the built bundle's `SUFeedURL` equals
      D1, `SUPublicEDKey` base64-decodes to 32 bytes, `SUEnableAutomaticChecks` is true,
      `Contents/Frameworks/Sparkle.framework` exists; `UpdateController(startingUpdater: false)`
      constructs and toggles `automaticallyChecksForUpdates` without starting a check. The
      `ShortcutRecorderFieldTests` smoke test passes the new `updates:` argument with a non-starting
      controller.
  - Backpressure: `build-for-testing`; the test list is reported to the coordinator.
  - **Evidence (2026-11-12, `0349627`; implemented, unverified until CI):** `UpdateController` per the
    interface; KVO hop to the main actor re-reads the updater (no stale payload); delegate via
    `@preconcurrency SPUStandardUserDriverDelegate`; activation = `NSApp.activate(ignoringOtherApps:)`
    in `checkForUpdates()` and `standardUserDriverWillHandleShowingUpdate` (the `.regular` fallback is
    **not** implemented — E1 confirms a scheduled alert reaches the front on macOS 27). Right-click
    menu enablement via `NSMenuItemValidation`; fallback menu (`autoenablesItems = false`) via
    `menuNeedsUpdate`. Sparkle 2.10.1 source check: setting `automaticallyChecksForUpdates` on a
    non-started updater only writes `SUEnableAutomaticChecks` to the host defaults (observer is
    registered in `startUpdater`), so the toggle test is safe and restores the host's real value in
    tearDown. Tests: `UpdateControllerTests` (6: feed URL, 32-byte key, automatic checks, display
    name/LSUIElement kept, framework embedded, non-starting toggle); smoke call site updated.
    **Gate closed 2026-11-12:** CI green on `04d0ece` (run 43150527567, macos-15 / Xcode 16.4: 279 tests, 0 failures). In the signed 2.3 build a user-initiated Check for Updates…
    showed "You're up to date!" in front (user). E1 still covers scheduled alerts and toggle persistence.

- [x] **1.2**: Two headlines — model, view, Claude/Codex/Vibe mapping, cache compatibility (D9)
  - Depends on: 0.1. External gates: E1 (visual check).
  - Owns: see table. Interface: `SectionHeadline(id:…)`, `ProviderSection.headlines`.
  - Success:
    - **Model:** `SectionHeadline` has `id` and `subMeters`; `ProviderSection.headlines` replaces
      `headline`; custom Codable with the legacy path (D9). No other model changes.
    - **View:** `SectionHeadlineView` renders each headline in order with its own percent, label,
      countdown and bar; `subMeters` render as smaller labelled bars under the headline's bar (the
      structure is in place even though no provider fills them until 2.1). The collapsed small
      caption lists only meters that have **no** headline of the same label. The Codex toggle filter
      (`five-hour-limit` meter, `five-hour-reset` deadline, `five-hour` headline) applies only when
      `store.providerID == "codex"`. The tooltip lists every headline, then meters, rows, deadlines.
    - **Claude:** `headlines` = `five-hour` then `seven-day`, each present only when its window has a
      utilization; `resetsAt` from the window. The old "next-resetting window" selection is removed.
    - **Codex:** `headlines` = `five-hour` (when the window exists) then `weekly` with the credit
      daily budget (shorter window first, D9).
    - **Vibe:** `headlines: [budget headline]` when a budget exists; otherwise empty.
    - **Tests:** `ProviderModelsTests` (id, clamping, `subMeters` default); `SectionStateCacheTests`
      adds a 0.2.2-format JSON fixture that decodes into one headline (`id` "primary") and a full
      0.3.0 round trip including `subMeters`; provider tests assert the exact `headlines` arrays;
      `SectionFixtures` Claude/Codex sections carry two headlines and the collapsed headline
      scenarios render both; `UsageStoreTests` compile against the new init.
  - Backpressure: `build-for-testing`; `grep -rn "\.headline\b" 01_Project/Sources` is empty.
  - **Evidence (2026-11-12, `2835494`; implemented, unverified until CI and E1):** model, Codable
    compatibility (legacy `headline` → one `primary` headline; a stored headline failing validation
    is dropped, not fatal), view (`SectionVisibility` helpers; the toggle filter applies only to
    `codex`), and the three providers as specified. Claude's log-estimate path never had a headline
    and still has none. The `.headline` grep returns only SwiftUI's `Font.headline`
    (`UsageStatusView.swift:97`), no model use. The live 0.2.2 `last-sections.json` on this Mac has
    the key shape the legacy decoder handles (`headline` without `id`/`subMeters`; read-only `jq`
    key listing). Sub-meter bar is `scaleEffect(y: 0.6)` and keeps full layout height — 2.1 may
    replace it with a genuinely thinner bar; E1 checks it visually. New/changed tests in
    `ProviderModelsTests` (5 new), `SectionStateCacheTests` (3 new incl. the literal 0.2.2 fixture),
    `CodexUsageProviderTests` (2 new), `ClaudeUsageProviderTests` (2 new/renamed), Vibe assertions,
    fixtures with two headlines.
    **Gate closed 2026-11-12:** CI green on `04d0ece` (run 43150527567, macos-15 / Xcode 16.4: 279 tests, 0 failures). Live panel (user screenshot, signed 2.3 build): Claude shows
    5-hour (43% left) and 7-day (86% left) headlines with countdowns and bars; Codex shows only its
    weekly headline while Claude keeps its 5-hour one (the toggle quirk is gone). E1 repeats the visual check.

- [x] **1.3**: Claude usage decoder — key-names diagnostic and Fable window (D10)
  - Depends on: 0.1. External gates: **E0** (live key names) for acceptance of the Fable decode;
    the diagnostic needs no gate.
  - Owns: see table. Interface: `ClaudeOAuthUsage.fable`, `ClaudeUsageKeyDiagnostic.summary`.
  - Success:
    - **Diagnostic:** after a 2xx and before decoding, `ClaudeUsageKeyDiagnostic.summary(data)` is
      logged at `.debug` with `privacy: .public` (key names only, one level down, arrays by their
      first object). It never logs values, counts of items, or anything on non-2xx.
    - **Fable decode:** `Envelope` reads `limits` as an optional array of rows; a row with
      `kind == "weekly_scoped"` and a scope whose `model.display_name` (object form) or whose string
      form equals "Fable" (case-insensitive) becomes `fable: ClaudeUsageWindow(utilization: percent/100 clamped, resetsAt:)`.
      Missing, null, malformed or non-Fable rows yield `fable == nil` without failing the decode.
      `five_hour`/`seven_day` handling is unchanged.
    - **Tests:** fixtures for object-scope and string-scope Fable rows, a `weekly_all` row only, no
      `limits`, `limits` as a non-array, and the four 2026 dump shapes from R2; the diagnostic's
      summary for a known payload is asserted exactly and shown to contain no values.
  - Backpressure: `build-for-testing`; `grep -n "utilization\|percent" Tests/…/ClaudeOAuthUsageServiceTests.swift`
    shows the new fixtures.
  - **Evidence (2026-11-12, `1581e8a`; implemented, unverified until CI; Fable decode awaits E0):**
    diagnostic format `key{a,b}` / `key[a,b]` (first object element) / bare `key`, sorted, one level;
    non-object bodies give the fixed marker "body is not a JSON object"; logged at `.debug`, public,
    after the 2xx check and before decoding. Fable: `weekly_scoped` row with a finite `percent` and a
    scope naming Fable (object or legacy string, case-insensitive); rows never throw; absent/null
    `limits` is silent; an undecodable `limits` logs one `.debug` failure-kind line. 15 new tests;
    the grep shows 51 `utilization|percent` lines. Pre-existing `try?` in the unchanged
    `five_hour`/`seven_day` decoding was left as it was.
    **Gates closed 2026-11-12:** CI green on `04d0ece` (run 43150527567, macos-15 / Xcode 16.4: 279 tests, 0 failures); E0 passed (see E0).

- [x] **1.4**: Release pipeline — inside-out signing, appcast tooling, signing notes (D1, D2, D8)
  - Depends on: 0.1 (public key for `docs/sparkle-signing.md`). External gates: 2.3 (dry run on
    this Mac), E2/E3 (real use).
  - Owns: see table.
  - Success:
    - `scripts/sign-app.sh`: given an `.app`, signs every nested bundle/executable inside-out
      (discover `Contents/Frameworks/*.framework`, their `Versions/*/XPCServices/*.xpc`,
      `Autoupdate`, `Updater.app`, then the framework), then the app, with
      `--force --options runtime --timestamp --sign "$SIGN_ID"`; ends with
      `codesign --verify --deep --strict --verbose=2` and prints each component's
      `TeamIdentifier`. Idempotent; refuses a path that is not an `.app`.
    - `scripts/notarize-release.sh`: calls `sign-app.sh` instead of its single `codesign`; keeps the
      rest; `SIGN_ONLY=1` stops after signing and verification (no notarytool, no staple). Its two
      `ditto -c -k` zip steps and the one in `scripts/release.sh` gain `--sequesterRsrc` (D8).
    - `scripts/make-appcast-item.sh`: as D8; takes the item's HTML notes from
      `dist/VERSION/release-notes.html` when present, else a one-line description linking the
      CHANGELOG; sets `length` from `stat -f%z`; writes `sparkle:minimumSystemVersion` 15.0;
      preserves other items byte-for-byte.
    - `appcast.xml`: a valid RSS 2.0 channel with the Sparkle namespace, title "LLM Usage Status",
      link to the repo, **no items yet** (2.3 adds the first). `xmllint --noout` passes.
    - `docs/sparkle-signing.md`: public key, Keychain item (label/account), export file name and
      location (no content), import command for another Mac, how to sign a release, what happens if
      the key is lost (never silently rotate; a lost key means one manual-download hop, as
      syncthingStatus learned). No private material.
  - Backpressure: `zsh -n` on all three scripts; `xmllint --noout appcast.xml`; a shell dry run of
    `make-appcast-item.sh --allow-missing` against a dummy file in scratch producing a parseable
    item (the EdDSA signature step may be skipped with `SKIP_SIGN=1` in that dry run only).
  - **Evidence (2026-11-12, `0ffbc79`; implemented, unverified until 2.3):** `zsh -n` ok on all four
    scripts, `xmllint --noout appcast.xml` ok (coordinator re-ran both after integration). Dry run in
    scratch (`ROOT=`, `APPCAST=`, `SKIP_SIGN=1`, 9.9.9 `--allow-missing`, HEAD 404 tolerated) produced
    a valid item; a rerun replaced it (one item); 9.9.8 and 9.9.10 inserted in order. Without
    `--allow-missing` it refused with "Release asset not live (HTTP 404)". Ad-hoc `SIGN_ID=-` run of
    `sign-app.sh` on a copy of a Debug build signed Downloader.xpc (entitlements preserved),
    Installer.xpc, Autoupdate, Updater.app, the framework and the app; verify passed; rerun
    idempotent; no `get-task-allow`. Outer app is signed with the tracked
    `Resources/LLM-UsageStatus.entitlements` (deterministic). Env overrides added: `ROOT=`,
    `APPCAST=`, `BUILD=`, `SKIP_SIGN=1`, `SIGN_ONLY=1`. **For 2.3:** the Developer ID TeamIdentifier
    printout and the `sign_update` output parse (`sparkle:edSignature="…"`) are unproven;
    `notarize-release.sh` still checks the notary key files before `SIGN_ONLY` applies, so 2.3 runs
    `sign-app.sh` directly on the scratch build. Coordinator fixes at integration: feed description
    wording (dockless HUD, as the README) and the signing notes name `scripts/package-dmg.sh`.
    **Gate closed 2026-11-12 by 2.3:** Developer ID signing prints `TeamIdentifier FDMSRXXN73` for all six
    components and the deep strict verify passes; `sign_update --account LLM-UsageStatus` output parsed into
    a valid `sparkle:edSignature` (verified with CryptoKit against `SUPublicEDKey`). 2.3 added a
    `SIGN_UPDATE=` override for releases whose own build has no Sparkle (0.2.2).

### Wave 2 (parallel — disjoint; prerequisites integrated and validated)

- [x] **2.1**: Fable sub-meter under the 7-day headline (D10)
  - Depends on: 1.2, 1.3. External gates: **E0** for acceptance (live confirmation that the
    `limits[]` Fable row exists; if E0 shows no such row on this account, the code stays data-driven
    and dormant, Help describes the meter conditionally, and the task is recorded as
    implemented-unverified live with E0's evidence).
  - Owns: see Wave 2 table.
  - Success:
    - `ClaudeUsageProvider.section(for:)`: when `usage.fable` has a utilization, the `seven-day`
      headline gets `subMeters: [SectionMeter(id: "fable-allowance", label: "Fable allowance", fraction:)]`;
      no meter, row or deadline is added elsewhere (the Fable reset equals the weekly reset).
    - View: the sub-meter renders as a smaller "Fable allowance: K% left" caption plus a thinner bar
      under the headline bar, collapsed and expanded, and appears in the tooltip.
    - Fixtures: the Claude endpoint section carries a Fable sub-meter; the render tests still pass
      the non-empty check.
    - Tests: with and without the Fable window; the sub-meter is on `seven-day` only.
  - Backpressure: `build-for-testing`.
  - **Evidence (2026-11-12, `b327b10` + follow-up `3c83c41`):** fresh-context agent in a scratch worktree.
    `ClaudeUsageProvider.section(for:)` puts `fable-allowance` "Fable allowance" (fraction = Fable
    utilization) on the `seven-day` headline only; without a seven-day headline it is not shown and nothing
    else is added. Sub-meters draw a real 4 pt `ThinMeterBar` (capsule track and fill; the old
    `scaleEffect` kept full height), shown collapsed and expanded (every visible headline renders through
    `SectionHeadlineView`), tooltip unchanged. Follow-up after the user saw the live panel: the fill uses the
    accent colour only in the key window, secondary grey otherwise, like the native headline bars (user's
    choice). Fixture: Claude endpoint seven-day carries Fable 0.35. Tests: 4 new in `ClaudeUsageProviderTests`
    (Fable on seven-day only, clamping 1.4 → 1, no Fable, Fable without seven-day). Validation: agent and
    integrated `build-for-testing` green; CI green on `04d0ece` (279 tests); `3c83c41` validated by fresh
    `build-for-testing` and Release builds (zero Swift warnings). **Live (E0):** the signed 2.3 build showed
    "Fable allowance: 87% left" under the 7-day headline (user screenshot).

- [x] **2.2**: Hygiene — test defaults cleanup, compiler warnings (D11)
  - Depends on: 1.1, 1.2 (shared test files). External gates: go-ahead to delete the 96 leftovers
    (coordinator, once, after the fix lands).
  - Owns: see Wave 2 table.
  - Success:
    - `Tests/Support/TestDefaults.swift`: a helper that creates a uniquely named suite and, on
      teardown, calls `removePersistentDomain(forName:)` **and** removes
      `~/Library/Preferences/<suite>.plist` if it exists (`FileManager`, errors tolerated). The four
      test files adopt it.
    - `ShortcutRecorderField.swift:30` and `ClaudeLogAggregator.swift:144` compile without warnings
      on the current Xcode.
  - Backpressure: `build-for-testing` log has zero Swift warnings; after the next CI run (3.2) a
    local `ls ~/Library/Preferences | grep -c LLMUsageStatusTests` stays at 0 once the leftovers
    are deleted (the CI machine's home is not ours; the local proof comes at E1's test run if any,
    otherwise at the first local `xcodebuild test` the user authorizes).
  - **Evidence (2026-11-12, `b987e61`):** fresh-context agent in a scratch worktree. `TestDefaults(prefix:)`
    makes `<prefix>-<UUID>`; `tearDown()` removes the domain, `CFPreferencesAppSynchronize`s it, then deletes
    `NSHomeDirectory()/Library/Preferences/<suite>.plist` (guarded to its own UUID name, never the app or
    test bundle id; `do/catch`, missing file is normal, other errors printed). Adopted in `UsagePreferencesTests`,
    `HotKeyShortcutTests`, `ShortcutRecorderFieldTests`, `VibeUsageProviderTests` (cleanup site only).
    Warnings: `ShortcutRecorderField` keeps `(center, token)` in one `nonisolated(unsafe) var` (no reliance on
    `NotificationCenter` being `Sendable`, which only newer SDKs declare); coordinator replaced the agent's
    `String(cString: realpath(...)!)` (pointer aliasing a call-scoped `&buffer`) with
    `String(decoding: buffer.prefix { $0 != 0 }…, as: UTF8.self)`. Integrated and Release builds: **zero Swift
    warnings**; CI (Xcode 16.4) green on `04d0ece`. The 96 leftovers (84 UsagePreferences, 12 Vibe Budget; all
    empty dicts) were deleted with the user's go-ahead after a negative pattern check; the app's own
    `com.sim.LLM-UsageStatus.plist` untouched; 0 remain. **Still open (acceptance D11):** proof that a local
    test run leaves no new plist (no local `xcodebuild test` authorized yet).

- [x] **2.3**: Pipeline dry run and first appcast item (coordinator)
  - Depends on: 1.1, 1.4; the key from 0.1. External gates: none (no Apple contact; local signing
    identity only).
  - Owns: scratch Release build, `dist/` dry-run output (deleted afterwards), the first `appcast.xml`
    item.
  - Success:
    - A universal Release build into scratch, then `scripts/sign-app.sh` on it: verification passes,
      every nested component reports team `FDMSRXXN73` and `runtime` flags; `spctl -a -t exec`
      on the signed scratch app (expected: rejected only for missing notarization, never for a
      signature error). Launch of the signed scratch build under the standing handoff: it starts,
      the hotkey works, **Check for Updates…** reaches the feed (an empty-channel error at this
      point is expected and recorded).
    - `make-appcast-item.sh 0.2.2` against the existing `dist/0.2.2` DMG (its GitHub asset is live)
      produces the **0.2.2 item (build 202)** — the feed's first valid item, so a 0.3.0 build sees
      "You're up to date" at E1 and Sparkle never shows the empty-feed error to users. The item is
      committed and pushed with a push go-ahead; `curl -fsSL` of the raw URL returns it.
    - The signed scratch app's **Check for Updates…** now says up to date (300 > 202).
  - Backpressure: the `codesign --verify --deep --strict` and `curl` outputs in the log; `dist/`
    dry-run output removed so E2 can create `dist/0.3.0`.
  - **Evidence (2026-11-12, `04d0ece`; coordinator):** universal Release builds into scratch (`rel-2.3a` on
    `3a6d5c0`; `rel-2.3d` on integrated Wave 2 — an incremental rebuild in `rel-2.3b` broke the Sparkle
    artifact, see Operational Learnings). `scripts/sign-app.sh` (Developer ID `D3002F50…`): all six components
    `TeamIdentifier FDMSRXXN73`, `flags=0x10000(runtime)`, secure timestamps; `codesign --verify --deep
    --strict` valid and satisfies its DR; outer entitlements only `app-sandbox = false` (no `get-task-allow`);
    `spctl -a -t exec` → `rejected, source=Unnotarized Developer ID` (expected). `dist/0.2.2` DMG SHA-256
    `a4fbe57a…136a` equals the downloaded GitHub asset; `SIGN_UPDATE=<rel-2.3a>/…/bin/sign_update
    scripts/make-appcast-item.sh 0.2.2` (no Keychain prompt) → item build 202, length 3294714, edSignature
    verified with CryptoKit against the app's `SUPublicEDKey` over the downloaded asset; `xmllint` ok. Pushed
    with the user's go-ahead (`bf2d640..04d0ece`); raw feed HTTP 200 and byte-identical. No `dist/` output
    created. Handoff (standing authorization): quit the `/Applications` 0.2.2 instance (pid 60772) via a quit
    Apple Event, confirmed exit, launched `04_Exports/0.3.0-W2-signed-Release/LLM-UsageStatus.app` (pid 15554,
    executable SHA-256 `abbf160b…a6add3c0` matched); hotkey registered (Carbon status 0), panel opened by
    the user with Control-Option-Command-L; **Check for Updates… → "You're up to date!" in front** (user;
    Sparkle strings in the log). The empty-feed error step was skipped because the feed went live before
    the launch. After the bar-colour follow-up the build was replaced the same way: pid 15554 quit and exited,
    `04_Exports/0.3.0-W2b-signed-Release/LLM-UsageStatus.app` launched (pid 49601, SHA-256
    `9b96ab47…845951e0`, 0.3.0 (300)) and left running for the user.

### Wave 3 (serial integration — shared docs and version files)

- [ ] **3.1**: Docs, decisions, cask, notices (coordinator)
  - Depends on: 1.1–1.4, 2.1–2.3.
  - Owns: `README.md` (features: automatic updates; Installation: replace "Updates are installed
    manually for now…" with an Updates paragraph incl. Homebrew `auto_updates`/`--greedy` note;
    Privacy: the daily appcast request to GitHub and the download on accept; What's New 0.3.0),
    `CHANGELOG.md [0.3.0]` (Added: in-app updates, Check for Updates…, Settings Updates; Claude
    5-hour and 7-day as two headlines; Codex 5-hour headline with the toggle; Fable allowance meter
    when reported. Fixed: the Codex toggle no longer hides Claude's 5-hour meter and countdown;
    relaunch seed survives the update), `Resources/Help/help-settings-and-shortcuts.md` (Updates
    section), `help-privacy-and-data.md` (network: GitHub appcast check, DMG download; nothing else
    is sent), `help-reading-the-panel.md` (one headline per limit window), `help-claude-code.md`
    (two headlines; Fable allowance meaning — percent of your Fable allowance, up to 50 % of the
    weekly limit, resets with the week; Pro accounts may not show it), `help-codex.md` (5-hour
    headline), `help-troubleshooting.md` (update errors: "An error occurred in retrieving update
    information" means the feed was unreachable; extract zips with ditto), `ThirdPartyNotices.txt`
    (Sparkle MIT with its copyright line), `Casks/llm-usagestatus.rb` (`auto_updates true` plus
    `livecheck { url <appcast>; strategy :sparkle }` as Maccy does; version and sha at E3),
    `docs/homebrew.md` (appcast step; `brew upgrade` compares the installed bundle's version with
    the cask and skips an app Sparkle already moved ahead; `--greedy` forces),
    `docs/decisions.md` (D1–D11 as taken), `docs/TASKS.md` (Backlog #16).
  - Success: no "manually for now" text; `jq . help-manifest.json` ok; no shortcut glyphs;
    `build-for-testing` green; built Info.plist 0.3.0 / 300.
  - Backpressure: `grep -rn "manually for now" README.md 01_Project/Resources` empty;
    `jq . 01_Project/Resources/Help/help-manifest.json`; `build-for-testing`.

- [ ] **3.2**: Final verification, independent review, CI, fresh build for E1
  - Depends on: 3.1. External gates: push go-ahead (CI).
  - Owns: the review report; findings return to the owning task.
  - Success:
    - An unsigned universal Release build into scratch succeeds with zero Swift warnings and
      contains `Contents/Frameworks/Sparkle.framework`.
    - An independent `feature-dev:code-reviewer` review of the whole diff (focus: signing script
      correctness, Codable compatibility, no values in the diagnostic, no network in tests), with
      applicable findings fixed and checks re-run.
    - CI is green on the release-candidate commit with at least 244 plus the new tests (the Sparkle
      package resolves on the runner).
    - A fresh Debug build is handed off for E1 under the standing authorization (full artifact path
      reported).
  - Backpressure: Release build log; CI run URL; review report.

## External checks

- [x] **E0**: Live key names of the Claude usage response (after Wave 1; user-operated panel open)
  - Depends on: 1.3 integrated; a fresh Debug build handed off. Requires: Claude Code run recently
    (a stale token gives 401 and no 2xx diagnostic); the user allows the Keychain prompt for the new
    build and opens the panel once.
  - Gates: acceptance of 2.1 (Fable row present or not); the Help wording in 3.1.
  - Success / evidence: coordinator runs
    `log show --predicate 'subsystem == "com.sim.LLM-UsageStatus" AND category == "ClaudeOAuth"' --debug --info --last 15m`
    (read-only) and records the key-name line in the execution log. Expected: `limits[…]` with
    `kind`, `percent`, `resets_at`, `scope` and a Fable row (R2); any surprise is recorded verbatim
    (key names only) and 2.1 is re-scoped before it is accepted.
  - While unavailable: 2.1 proceeds provisionally on the R2 field names with fixtures; it is not
    marked complete.
  - **Evidence (2026-11-12, signed 2.3 build, panel opened by the user):** captured with
    `/usr/bin/log stream --level debug` (debug lines are not persisted; `log` alone is a zsh builtin). Key
    names (os_log truncated the line at about 1 KB): `amber_cistern amber_cistern_offer amber_gauge amber_ladder
    brass_thimble cedar_ember cinder_cove copper_kite extra_usage{credits_ever_enabled,currency,daily,
    decimal_places,disabled_reason,is_enabled,monthly_limit,spend_limit_reached,used_credits,user_disabled,
    utilization,weekly} five_hour{limit_dollars,locked_reason,remaining_dollars,resets_at,used_dollars,
    utilization} granite_teacup harbor_lantern iguana_necktie indicator juniper_tide
    limits[group,is_active,kind,percent,resets_at,scope,severity] member_dashboard_available nimbus_quill
    omelette_promotional pace promo_credits seven_day{limit_dollars,locked_reason,remaining_dollars,resets_at,
    used_dollars,utilization} seven_day_breakdown{as_of,rows,window_started_at} seven_day_cowork
    seven_day_oauth_apps seven_day_omelette seven_day_opus seven_day_sonnet spend{auto_reload,balance,
    can_purchase_credits,can_toggle,cap,disabled_reason,disclaimer,enabled,limit,percent,severity,used}
    starry_waterfall tangelo wattle_ember weekly_scoped_shares[allowance_percent<…>`. `limits[]` carries the
    R2 names (`kind`, `percent`, `resets_at`, `scope`). **Fable row present:** the panel rendered "Fable
    allowance: 87% left", which only a decoded `weekly_scoped` Fable row produces. No re-scope of 2.1 needed.
- [ ] **E1**: Manual acceptance in a fresh Debug build (user-operated)
  - Depends on: 3.2. Gates: the UI acceptance criteria; E2.
  - Success:
    1. Claude section: two headlines (5-hour, 7-day) with countdowns and bars; expanded shows meters
       and reset times; the Fable allowance sub-meter if E0 confirmed it; "Show 5-hour limit" off →
       Claude unchanged, Codex loses its 5-hour headline; on → it returns.
    2. Right-click → Check for Updates… → the Sparkle alert is frontmost and says up to date
       (feed newest item 202 < 300). Settings → Updates: untick automatic checks, close and reopen
       Settings → still unticked; "Last checked" shows the time of the manual check.
    3. Launch with the 0.2.2 cache file present: the last-seen values appear at once (compat
       decode), then refresh.
    4. About shows Version 0.3.0 (300).
  - Evidence: the user's report; screenshots if provided go to `docs/verification/2026-11-v0.3.0/`.
- [ ] **E2**: Notarize 0.3.0 (go-ahead — Apple, `99-AUTH` key)
  - Depends on: E1.
  - Success: clean tree; `scripts/notarize-release.sh 0.3.0` → Accepted, stapled, `spctl`
    "Notarized Developer ID"; `codesign --verify --deep --strict` passes; `codesign -dv` on
    `Contents/Frameworks/Sparkle.framework` shows team `FDMSRXXN73` and `runtime`; `notarytool log`
    has no issues; `dist/0.3.0/` has `SHA256SUMS.txt` and `SOURCE_COMMIT.txt`.
- [ ] **E3**: Publish — DMG, GitHub Release, appcast item, cask, website (go-aheads)
  - Depends on: E2. Order is part of the success criteria.
  - Success:
    1. `scripts/package-dmg.sh 0.3.0` → Accepted, stapled DMG; SHA-256 recorded.
    2. Tag `v0.3.0` on the release commit; GitHub Release with the DMG and the CHANGELOG entry as
       notes; the asset URL downloads with the same checksum.
    3. `scripts/make-appcast-item.sh 0.3.0` (asset live) → item reviewed (version 300, 0.3.0,
       length, signature, notes); `xmllint` ok; commit and push; `curl -fsSL` of the raw feed shows
       the 0.3.0 item above 0.2.2.
    4. Cask: version 0.3.0, sha256, `auto_updates true`; `brew style` and
       `brew audit --cask --online` pass; push.
    5. Website (App-Websites): DMG upload, page and roster version/date (and the GitHub/Homebrew
       links if still missing); `dl.php` serves 0.3.0; README SHA-256 line updated.
    6. Verify live: GitHub asset, `brew fetch`, `dl.php` and the appcast `length` agree.
- [ ] **E4**: Install and smoke test (go-ahead to replace the `/Applications` copy)
  - Depends on: E3.
  - Success: graceful quit of the identified 0.2.2 instance, notarized 0.3.0 copied in, `spctl` ok,
    launched from `/Applications`, About 0.3.0 (300), Check for Updates… says up to date, Sparkle's
    scheduled check leaves a `com.sim.LLM-UsageStatus` defaults entry for the last check date.
- [ ] **E5**: Self-update smoke test through the live feed (go-ahead; install click user-operated)
  - Depends on: E3 (and E4 for the final relaunch of the installed copy).
  - Success: a scratch Release build with `MARKETING_VERSION=0.2.9 CURRENT_PROJECT_VERSION=299`
    overrides, signed with `scripts/sign-app.sh`; the installed 0.3.0 is quit (identified
    instance); the 0.2.9 build is launched; Check for Updates… offers 0.3.0 with the release notes;
    **Install Update** downloads from GitHub, verifies the EdDSA signature, replaces the scratch
    copy and relaunches it; About shows 0.3.0 (300). Then quit it and relaunch the `/Applications`
    copy. Evidence: the user's report plus
    `log show --predicate 'process == "LLM-UsageStatus" AND eventMessage CONTAINS "Sparkle"' --last 30m`.
  - If it fails: the signature, feed or signing step is wrong and 0.3.0 users could not update to
    0.3.1 — fix (re-sign the DMG and the item, never the key) before announcing the release.

---

## Operational Learnings

- Carried over: zsh scripts are syntax-checked with `zsh -n`; `release.sh` runs `xcodegen generate`
  and requires a clean tree, so commit `project.pbxproj` first; the Vibe store format is
  undocumented — fall back and log, never crash.
- Sparkle: `INFOPLIST_KEY_SUFeedURL` is silently dropped — only the built bundle's plist is the
  truth. Extract app zips with `ditto -x -k`, never `unzip` (framework symlink farm); create them
  with `--sequesterRsrc`. An appcast with no items makes Sparkle report an error, so the feed
  carries the previous release's item before the new app ships.
- Known risk (R3): Sparkle issue #2880 — on macOS 26 `Autoupdate` hit EPERM creating its
  `~/Library/Caches/<bundle-id>/…/Installation` folder for non-sandboxed Developer-ID apps in
  2.9.1/2.9.2; the fixing release is unconfirmed. E5 on this macOS 27 Mac is the proof; if it
  reproduces, the fix belongs in the pipeline or a Sparkle bump, not in a key or feed change.
- Parallel Swift agents (Wave 1): one git worktree per agent in the session scratchpad (outside
  Syncthing) plus its own DerivedData, so a half-done edit in one task never breaks another task's
  build; the coordinator applies each `git diff` to `main`, checks the files are byte-identical,
  runs one integrated build, then removes the worktrees.
- Xcode 27.2 (2026-11-12): an incremental build in an **existing** DerivedData re-extracted the Sparkle
  binary artifact incompletely (`Sparkle.xcframework` without `Info.plist`, `bin/` gone) → "There is no
  Info.plist found at …/Sparkle.xcframework/Info.plist". A fresh DerivedData builds cleanly; `release.sh`
  already uses a fresh `dist/VERSION/DerivedData`. For scratch builds, use a new folder per build.
- Logs: in zsh `log` is a builtin — call `/usr/bin/log`. `.debug` lines are only kept while a
  `log stream --level debug` is attached, so start the stream before the trigger (opening the panel
  refreshes every enabled provider). os_log truncates a long message at about 1 KB.
- `sign_update --account LLM-UsageStatus` read the Keychain key without a prompt on this Mac.

## Blocked Tasks

- None. D2, D4, D10 and D11 were confirmed 2026-11-12. Remaining go-aheads are per-step (see
  Execution scope and limits): further pushes, notarization, publishing, installation and E5.

---

## Execution Log

| Wave / task IDs | Assignments or serial reason | Validation / evidence | Commits or exception | Remaining gates / next action or stop reason |
|---|---|---|---|---|
| — | Plan written 2026-11-12 by the coordinator from on-disk code reading (R1) and two parallel web research agents (R2 Claude endpoint fields, R3 Sparkle); scope from the TASKS Inbox, the 2026-11-12 decision and session log | `research/findings.md` | — | Next: user confirms D2, D4, D10, D11; then Wave 0 (0.1), once execution is requested |
| — | Decisions confirmed by the user 2026-11-12: D2 (own key account + `99-AUTH` export; key go-ahead given), D4 (as drawn), D10 (limit resets deferred to Backlog #16), D11 (hygiene in scope; plist deletion still needs its own go-ahead) | User answers in session | — | Next: `/execute` Wave 0 (0.1) |
| Wave 0 (0.1), 2026-11-12 | Serial by coordinator (shared files only: `project.yml`, project file, Info.plist, Keychain, stubs); no agents | `xcodebuild -resolvePackageDependencies` ok (Sparkle 2.10.1); key generated under account `LLM-UsageStatus`, exported and verified (see 0.1 evidence); scratch `build-for-testing` (session scratchpad `dd-0.1`) **TEST BUILD SUCCEEDED**; PlistBuddy on the built app shows all 0.1 keys, 0.3.0 / 300, Sparkle.framework embedded. Two known warnings only (`ShortcutRecorderField.swift:30`, `ClaudeLogAggregator.swift:144` → 2.2). Tests not run (app-hosted; CI at 3.2) | `109957c` 0.1 (project + stubs). Not pushed | Next: Wave 1 (1.1, 1.2, 1.3, 1.4 as 4 parallel agents) when execution is requested. 1.4 records the public key above in `docs/sparkle-signing.md` |
| Wave 1 (1.1, 1.2, 1.3, 1.4), 2026-11-12 | 4 parallel fresh-context `developer` agents, exclusive ownership per the table, each in its **own git worktree in the session scratchpad** (outside Syncthing) with its own DerivedData, so no agent's half-done edit could break another's build. Schedule repair: `SectionFixtureRenderTests.swift` added to 1.2's ownership (fixture API consumer; ended up unchanged). Coordinator reviewed each diff, applied the four patches to `main` (worktree files byte-identical to the commits except the two 1.4 wording fixes), then removed the worktrees and branches | Each task: `build-for-testing` **TEST BUILD SUCCEEDED** alone on `c8e34b9`. Integrated (1.1+1.2+1.3 on `main`, scratch `dd-int`): **TEST BUILD SUCCEEDED**, only the two known D11 warnings (→ 2.2). 1.4 touches no Swift; `zsh -n` ×4 and `xmllint` re-run after integration. 275 test functions (244 + 31). Tests not run locally (app-hosted; CI at 3.2). Details in each task's Evidence | `1581e8a` 1.3 · `0349627` 1.1 · `2835494` 1.2 · `0ffbc79` 1.4. Not pushed | 1.1–1.3 unchecked until CI; 1.4 until 2.3. Next: Wave 2 — 2.1 (agent, Fable sub-meter), 2.2 (agent, hygiene; plist deletion needs its go-ahead), 2.3 (coordinator: Developer ID signing dry run, launch of the signed scratch build, first appcast item — its push needs a go-ahead) |
| Wave 2 (2.1, 2.2, 2.3), 2026-11-12 | 2.1 and 2.2: two parallel fresh-context `developer` agents, each in its own scratchpad worktree and DerivedData (exclusive ownership per the Wave 2 table); 2.3 by the coordinator in parallel. Coordinator applied both diffs to `main`, replaced 2.2's `realpath` pointer use, added `SIGN_UPDATE=` to `make-appcast-item.sh`, and after the user's screenshot changed the Fable bar colour (user's choice) | Integrated `build-for-testing` **TEST BUILD SUCCEEDED**, zero Swift warnings; universal Release zero Swift warnings; 279 test functions; **CI green on `04d0ece` (run 43150527567, 279 tests, 0 failures)**; Developer ID signing of all six components, deep strict verify, `spctl` rejects only for notarization; appcast 0.2.2 item signature verified against `SUPublicEDKey`, raw feed HTTP 200; signed build launched under the standing handoff, user saw two Claude headlines plus "Fable allowance: 87% left" and Check for Updates… "You're up to date!" in front; E0 key names captured. 96 leftover plists deleted (go-ahead). `3c83c41` validated by fresh `build-for-testing` and Release builds (not yet on CI). Tests not run locally (app-hosted) | `b327b10` 2.1 · `b987e61` 2.2 · `04d0ece` 2.3 (pushed with go-ahead) · `3c83c41` 2.1 follow-up (not pushed) | 1.1–1.4, 2.1–2.3 and E0 checked. Open: D11 local no-new-plist proof (first authorized local test run), E1–E5. Running: signed 0.3.0 test build pid 49601 from `04_Exports/0.3.0-W2b-signed-Release` (installed 0.2.2 quit; relaunching it is the user's or needs its own go-ahead). Next: Wave 3 (3.1 → 3.2, coordinator) |

---
*Keep active while required work or acceptance is incomplete. On completion, retire in place with
execution evidence and updated incoming links.*
