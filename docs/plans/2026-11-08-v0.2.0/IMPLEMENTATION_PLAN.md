# Implementation Plan — 0.2.0 (layout-aware names, Help, Feedback + Tip, notarized release)

> **Persists across sessions.** Execute using the shared `commands/execute.md` procedure.
> Repair scheduling errors while preserving task IDs, completed evidence and approved scope.
> Task state/evidence is authoritative here; TASKS links here and holds backlog/inbox.
> Follow the master's `reference/task-state.md` for legacy reconciliation and archival.

**Progress:** 4/11 tasks (Wave 1: 1.2–1.4 done; 1.1 implemented, awaiting CI; Wave 2: 2.1–2.4 implemented, awaiting CI; Wave 3: 3.1 implemented, awaiting CI; Wave 4: 4.1 done, 4.2 done except CI on the release candidate — needs a push); external acceptance: E1 (site roster), E2 (manual, Debug), E3 (notarize),
E4 (notarized smoke test), E5 (publish — optional, decision pending).
**Task states:** unchecked = pending / implemented-unverified / blocked (name gate);
checked = complete with required evidence. Task identity includes this plan path plus ID.

## Goal

Ship a Developer ID–notarized **0.2.0 (200)** that contains the finished Settings window plus three
additions: shortcut names that match the user's keyboard layout, an in-app Help window, and
Send Feedback… / Leave a Tip items — all reachable from the dockless panel's right-click menu.

Journeys:
- **Names:** user on a German layout records Control-Command-(key labelled Z) → recorder and footer
  read `Control–Command–Z` (today: `…–Y`); the hotkey fires as before.
- **Help:** right-click panel → **LLM Usage Status Help** → Help window in front (dark), topics in a
  sidebar, search works → Esc or Command-W closes it.
- **Feedback:** right-click → **Send Feedback…** → feedback window in front → submit → server
  accepts `llm-usagestatus` (after E1). **Leave a Tip** opens
  `https://apps.lucesumbrarum.com/donate.html?app=llm-usagestatus` in the browser.
- **Release:** `scripts/notarize-release.sh 0.2.0` from a clean tree → Accepted, stapled, spctl
  "Notarized Developer ID" → zip + checksums in `dist/0.2.0/`.

Research: `research/findings.md` (R1–R4, with sources).

## Scope decisions

Proposed 2026-11-08 by the planner; **all confirmed by the user 2026-11-08** (D3 menu placement, D5 Feedback in 0.2.0).

- **D1 — Use the ASCII-capable layout** (`TISCopyCurrentASCIICapableKeyboardLayoutInputSource`), not
  the *current* input source as Backlog 11 says: Cyrillic/Greek/IME sources would yield non-Latin or
  no names, and macOS resolves Command chords through the ASCII-capable layout too (R1). Record in
  `docs/decisions.md` when 1.1 lands.
- **D2 — Vendor all three packages in-repo** (`01_Project/HelpMenu/`,
  `01_Project/Vendor/{AppCitizenshipKit,FeedbackKit}/`): the citizenship repos are private and CI has
  no token; same reasoning as the ShortcutKit rejection (R2, R3). Provenance in
  `01_Project/Vendor/README.md` and a header note in `HelpMenu/`.
- **D3 — Menu placement (UI-changes protocol; confirmed 2026-11-08):** right-click panel menu becomes

  ```
  Show 5-hour limit
  Set Vibe Monthly Budget…
  ──────────
  Settings…                      Command-Comma
  LLM Usage Status Help
  Restart LLM Usage Status
  ──────────
  Send Feedback…
  Leave a Tip
  ──────────
  Quit LLM Usage Status          Command-Q
  ```

  The shortcut-failure status-item menu gains **LLM Usage Status Help** after Settings….
  `LLMUsageStatusApp.swift` `.commands` adds `HelpMenuCommands` so Command-? works while the Help or
  Settings window is in front. Command-? is **not** claimed as a global hotkey.
- **D4 — Settings stays at three sections;** no Help button in About in this plan (would need its own
  approval).
- **D5 — Feedback/Tip is in 0.2.0 (confirmed 2026-11-08),** so E3 waits on E1 (the site roster entry).
  Alternative: move 1.3/2.2 and the menu items to 0.3.0 and release without E1.
- **D6 — Version 0.2.0 build 200** (monotonic; build 100 already names two different binaries).
- Not in scope: Sparkle (stays last, gated), DMG packaging, Help Book, positional-refusal fixes from R1
  (new Backlog items), App Store.

## Acceptance Criteria

- [ ] On a non-US Latin layout (e.g. German), recorder, footer and shortcut-failure menu name the
      key printed on the keycap; switching layouts updates an open recorder; F-keys, arrows, Space,
      Return, Tab, Delete, Escape and keypad keys keep their spelled-out names; the binding itself is
      unchanged.
- [ ] On a non-Latin input source (e.g. Russian) names come from the last ASCII-capable layout; when
      no layout data exists the US name is shown.
- [ ] **LLM Usage Status Help** in the right-click menu and the shortcut-failure menu opens one reused
      Help window in front with keyboard focus, dark appearance, sidebar topics per the R3 outline,
      working search; Esc and Command-W close it; no Dock icon appears.
- [ ] A missing or broken help manifest shows a "Help unavailable" topic instead of failing; every
      bundled topic loads without the fallback page (test-enforced).
- [ ] Help text labels Claude-local and Vibe figures as estimates and Codex as authoritative, and
      states that feedback is the app's only outgoing send besides provider usage requests.
- [ ] **Send Feedback…** opens one reused feedback window in front; a submission reaches the server
      and is accepted for slug `llm-usagestatus` (after E1); no logs, usage data or credentials are
      attached.
- [ ] **Leave a Tip** opens the donate URL for `llm-usagestatus` in the default browser; a failure
      shows an alert instead of failing silently.
- [ ] Third-party notices for MarkdownUI, NetworkImage and cmark ship in the app bundle.
- [ ] About shows `Version 0.2.0 (200)`; CHANGELOG has a `[0.2.0]` entry; README matches shipped
      behavior and the actual download location.
- [ ] `notarize-release.sh 0.2.0` refuses a dirty tree, records the source commit, and produces an
      Accepted, stapled, spctl-clean zip with SHA-256 sums.
- [ ] CI green (macos-15, Xcode 16.4) on the release commit.

---

## Execution schedule and ownership

- Execution scope/limits: user approved the plan and requested execution starting with **Wave 1** (2026-11-08). Notarization (contacts
  Apple, uses the `99-AUTH` key), installing into `/Applications`, deploying the website, creating
  tags/Releases and changing repo visibility each need an explicit user go-ahead.
- Coordinator-owned files/resources: `01_Project/project.yml` + `xcodegen generate` + the tracked
  `.xcodeproj`, `AppDelegate.swift`, `LLMUsageStatusApp.swift`, `README.md`, `CHANGELOG.md`,
  `scripts/*`, DerivedData/build dirs, git, tracking docs (`docs/*`).
- **Test-running limit (carried from the Settings plan):** the test target is app-hosted, so
  `xcodebuild test` starts a second app instance beside the user's running copy. Local backpressure is
  `xcodebuild build-for-testing`; the full suite runs on GitHub CI. A local `xcodebuild test` needs the
  user's go-ahead. Test code must compile on Xcode 16.4 (async `setUp`/`tearDown` in `@MainActor`
  classes without `super` calls — commit 947650b).
- Vendored packages are built standalone in Wave 1 (`swift build` inside the package folder) so their
  integration in Wave 2 is only project wiring.
- Interfaces fixed before dispatch:

```swift
// 1.1 — Sources/App/HotKeyShortcut.swift + Sources/App/KeyboardLayoutNames.swift
extension HotKeyShortcut {
    /// Pure; `keyName` returns a layout-specific name for single-character keys or nil (→ US name).
    func displayName(keyName: (UInt32) -> String?) -> String
    @MainActor var displayName: String { get }        // == displayName(keyName: KeyboardLayoutNames.current)
}
@MainActor enum KeyboardLayoutNames {
    static func current(_ keyCode: UInt32) -> String?  // ASCII-capable layout via UCKeyTranslate
    static let changedNotification: Notification.Name   // kTISNotifySelectedKeyboardInputSourceChanged
}

// 2.2 — Sources/App/CitizenshipSupport.swift
@MainActor final class CitizenshipSupport {
    static let shared: CitizenshipSupport
    let config: CitizenshipConfig                      // appID "llm-usagestatus", appName "LLM Usage Status"
    func showFeedback()                                 // one reused window, activates app
    func leaveTip()                                     // opens config.donateURL; NSAlert on failure
}

// 2.3 — Sources/App/HelpSupport.swift
@MainActor enum HelpSupport {
    static func loadContent(bundle: Bundle = .main) -> HelpContent  // fallback topic on error, no try?
    static func show()                                  // HelpWindowController.showHelp(content:)
}
```

## Tasks

### Wave 1 (parallel — no mutual dependencies; disjoint ownership)

- [ ] **1.1**: Layout-aware shortcut names (Backlog 11) → `HotKeyShortcut.swift`, new `KeyboardLayoutNames.swift`
  - Depends on / external gates: none
  - Owns: `01_Project/Sources/App/HotKeyShortcut.swift`, `01_Project/Sources/App/KeyboardLayoutNames.swift`,
    `01_Project/Tests/App/HotKeyShortcutTests.swift`
  - Interface: as fixed above; US `keyNames` table kept for `validate()` and fallback.
  - Success: translation only for single-character keys (R1 list); fallback on nil/empty/whitespace/
    control output; fake-translator tests (German Y/Z → `Control–Command–Z`; fake never called for
    F5, Space, Keypad 1, arrows); existing tests pinned to `{ _ in nil }`; one live check on L.
    D1 recorded in `docs/decisions.md` by the coordinator at integration.
  - Backpressure: `xcodebuild … build-for-testing` (after coordinator `xcodegen generate` for the new
    file); CI suite at integration.

- [x] **1.2**: Vendor HelpMenu with dockless adaptations → `01_Project/HelpMenu/**`
  - Depends on / external gates: none
  - Owns: `01_Project/HelpMenu/**` (copy of `CountClockWise/Vendor/HelpMenu`, provenance note)
  - Interface: `HelpContent(manifest:in:)`, `HelpWindowController.showHelp(content:)` (and
    `selectingTopic:`), `HelpMenuCommands`.
  - Success: `NSApp.activate()` replaces `activate(ignoringOtherApps:)`; window uses `.darkAqua`;
    Esc and Command-W close it (window subclass as in `SettingsWindowController.swift:9-27`); frame
    autosave name set; MarkdownUI stays pinned `exact: "2.4.1"`; no `try?` introduced. Same three
    fixes noted for upstream `appHELP/docs/TASKS.md` (coordinator records, does not edit upstream).
  - Backpressure: `swift build` in `01_Project/HelpMenu`.

- [x] **1.3**: Vendor AppCitizenshipKit + FeedbackKit → `01_Project/Vendor/**`
  - Depends on / external gates: none
  - Owns: `01_Project/Vendor/AppCitizenshipKit/**`, `01_Project/Vendor/FeedbackKit/**`,
    `01_Project/Vendor/README.md`
  - Interface: products `AppCitizenshipKit`, `FeedbackKit`; ACK depends on `../FeedbackKit` by path.
  - Success: byte-identical to ACK `a6c06af` / FK `8a240f1` sources (verify against
    `zPackages` HEADs; if HEADs moved, use them and record the SHAs); trimmed manifests (no tests);
    README records origin SHAs and the refresh procedure.
  - Backpressure: `swift build` in `01_Project/Vendor/AppCitizenshipKit`.

- [x] **1.4**: Help content → `01_Project/Resources/Help/**`
  - Depends on / external gates: none (format from 1.2's sources, read-only: manifest schema in the
    vendored `HelpContent`)
  - Owns: `01_Project/Resources/Help/help-manifest.json`, `01_Project/Resources/Help/*.md`
  - Interface: topic IDs used by 2.3's test; file names unique in the flat bundle (prefix `help-`).
  - Success: nine topics per the R3 outline, factual against current source/README (shortcut is
    named as configurable, default Control-Option-Command-L; estimates labeled; Claude sign-in states
    and "run Claude Code once, then reopen"; privacy incl. feedback send); shortcut names spelled out
    (no glyphs).
  - Backpressure: `python3 -m json.tool` on the manifest; every manifest entry has a file.

### Wave 2 (integration of project wiring + dependent code; 2.1 first, then 2.2–2.4 in parallel)

- [ ] **2.1**: Wire vendored packages into the project → `project.yml` (coordinator, serial)
  - Depends on: 1.2, 1.3 (and 1.1 for one regeneration)
  - Owns: `01_Project/project.yml`, `.xcodeproj`, `docs/decisions.md` (D1, D2)
  - Success: `packages:` HelpMenu, AppCitizenshipKit, FeedbackKit (paths); app target links all three
    products; `xcodegen generate`; app builds; CI resolves MarkdownUI. Reason for single task: shared
    project file.
  - Backpressure: `xcodebuild -scheme LLM-UsageStatus -configuration Debug build` + `build-for-testing`.

- [ ] **2.2**: Feedback + Tip support → `CitizenshipSupport.swift`
  - Depends on: 2.1
  - Owns: `01_Project/Sources/App/CitizenshipSupport.swift`, `01_Project/Tests/App/CitizenshipSupportTests.swift`
  - Success: interface above; feedback window 460×540, reused, delegate clears reference,
    `NSApp.activate()`, dark appearance, Esc/Command-W close; no `logProvider`; tip failure → NSAlert
    + log. Tests: `donateURL` contains `app=llm-usagestatus`; `feedbackConfig.appID` equals the slug.
  - Backpressure: `build-for-testing`.

- [ ] **2.3**: Help support → `HelpSupport.swift`
  - Depends on: 2.1, 1.4
  - Owns: `01_Project/Sources/App/HelpSupport.swift`, `01_Project/Tests/App/HelpSupportTests.swift`
  - Success: interface above; load error → single "Help unavailable" topic (logged); test loads the
    bundled manifest and asserts every topic resolves without the fallback page, and that a bad bundle
    yields the fallback.
  - Backpressure: `build-for-testing`.

- [ ] **2.4**: Recorder refreshes on layout change → `ShortcutRecorderField.swift`
  - Depends on: 1.1 (integrated in 2.1's regeneration)
  - Owns: `01_Project/Sources/App/ShortcutRecorderField.swift`, `01_Project/Tests/App/ShortcutRecorderFieldTests.swift`
  - Success: observes `KeyboardLayoutNames.changedNotification` on an injectable
    `DistributedNotificationCenter` (main queue, `MainActor.assumeIsolated`), refreshes label + AX
    value, removes observer on teardown; test posts to an injected center and sees the refresh.
  - Backpressure: `build-for-testing`.

### Wave 3 (serial integration — shared app files)

- [ ] **3.1**: Menu + commands wiring, notices, README → `AppDelegate.swift`, `LLMUsageStatusApp.swift` (coordinator)
  - Depends on: 2.2, 2.3, 2.4 (D3 confirmed 2026-11-08)
  - Owns: `AppDelegate.swift`, `LLMUsageStatusApp.swift`, `01_Project/Resources/Licenses/**`, `README.md`
  - Success: menus exactly as D3; `openHelp`/`sendFeedback`/`leaveTip` hide the panel first (like
    `openSettings`); `HelpMenuCommands` in `.commands`; license notices for MarkdownUI, NetworkImage,
    cmark bundled; README documents Help, Feedback, Tip and the layout-aware names. Reason for serial:
    shared app-entry files.
  - Backpressure: Debug build + `build-for-testing`; CI green.

### Wave 4 (release prep and verification)

- [x] **4.1**: Version, changelog, release-script hardening (coordinator)
  - Depends on: 3.1
  - Owns: `01_Project/project.yml` (version keys), `CHANGELOG.md`, `README.md` (download wording),
    `scripts/release.sh`, `scripts/notarize-release.sh`
  - Success: `MARKETING_VERSION` 0.2.0, `CURRENT_PROJECT_VERSION` 200; CHANGELOG `[0.2.0]`
    (Settings, 2026-11-06 fixes, names, Help, Feedback/Tip); README download text matches E5's
    decision (no broken "Releases page" link while the repo is private); scripts refuse a dirty tree
    and write the source commit SHA into `dist/<v>/SOURCE_COMMIT.txt`.
  - Backpressure: `bash -n scripts/*.sh`; dirty-tree refusal tried on a scratch change (then
    reverted); Debug build shows `Version 0.2.0 (200)` in About.

- [ ] **4.2**: Final verification + independent review — all but CI done (awaiting push)
  - Depends on: 4.1
  - Owns: review report; findings return to the owning task
  - Success: unsigned universal Release build (`release.sh`-equivalent into scratch, not `dist/`)
    succeeds; CI green on the release candidate commit; independent code review of the whole plan's
    diff with applicable findings fixed and checks re-run; fresh Debug build handed off for E2.
  - Backpressure: Release build log; CI run URL; review report.

## External checks

- [ ] **E1**: Site roster entry for `llm-usagestatus` (user-operated or user go-ahead)
  - Depends on: none (can happen any time)
  - Requires: user go-ahead to edit `3-Websites/App-Websites/APPS/apps.lucesumbrarum.com/public/apps.json`
    (entry in R2), `DRY_RUN=1 ./deploy.sh` then `./deploy.sh`, commit to `Xpycode/App-Websites`.
  - Gates: the Feedback acceptance criterion (server accepts), E3 under D5. Does not gate Waves 1–4.
  - Success / verification: feedback form lists "LLM Usage Status"; `donate.html?app=llm-usagestatus`
    renders the app name.
  - While unavailable: build and test proceed; submissions are rejected server-side.

- [ ] **E2**: Manual acceptance in a fresh Debug build (user-operated)
  - Depends on: 4.2; E1 for the submission step
  - Requires: the user at this Mac. Handoff under the standing fresh-build authorization (replaces
    the running `/Applications` copy only with a separate go-ahead; otherwise run from the build folder).
  - Gates: all UI acceptance criteria.
  - Success / verification:
    1. Right-click menu matches D3; shortcut-failure menu has Help.
    2. Help opens in front, dark; search finds "estimated"; Esc and Command-W close; reopening reuses
       the window; Command-? reopens it while Help or Settings is in front.
    3. Send Feedback… opens in front; one test submission is accepted (after E1).
    4. Leave a Tip opens the donate page for this app.
    5. Switch to German (or another non-US Latin) layout: footer and recorder show the keycap letter;
       with Settings open, switching layout updates the recorder label; hotkey still fires.
    6. About shows `Version 0.2.0 (200)`.

- [ ] **E3**: Notarize 0.2.0 (user go-ahead — contacts Apple, uses the `99-AUTH` key)
  - Depends on: 4.2, E2; E1 under D5
  - Gates: E4, E5, the release acceptance criterion.
  - Success / verification: clean tree; `scripts/notarize-release.sh 0.2.0` → Accepted, `stapler
    validate` ok, `spctl` "source=Notarized Developer ID", `SHA256SUMS.txt` and `SOURCE_COMMIT.txt`
    present in `dist/0.2.0/`.

- [ ] **E4**: Smoke test of the notarized artifact (user-operated; install needs go-ahead)
  - Depends on: E3
  - Requires: go-ahead to quit the running copy and replace `/Applications/LLM-UsageStatus.app`
    (currently the ad-hoc Debug E1 build) with the stapled 0.2.0 extracted via Finder/ditto.
  - Success / verification: launches without Gatekeeper complaint beyond the first-open notice;
    About `Version 0.2.0 (200)`; re-toggle Launch at login (registration made by the ad-hoc build) and
    confirm in System Settings; launch once with the login item enabled and check Console category
    LaunchAtLogin for "refresh failed" (closes that Inbox item either way); Help/Feedback/Tip spot check.

- [ ] **E5**: Publish (optional; decision pending)
  - Depends on: E4
  - Requires: user decision on where 0.2.0 is downloaded (public repo + GitHub Release, or hosted on
    the website) and go-ahead for `git tag v0.2.0`, `gh release create`, visibility changes or upload.
  - Success / verification: download link works from a signed-out browser; checksum matches
    `SHA256SUMS.txt`; README link updated in 4.1 matches.

---

## Operational Learnings

- zsh scripts: syntax-check with `zsh -n`, not `bash -n` (zsh regex/`print` syntax).
- `release.sh` runs `xcodegen generate` and then requires a clean tree, so regenerate and commit
  `project.pbxproj` before any release run.

## Blocked Tasks

- None. (D3/D5 confirmed 2026-11-08; E3 waits on E1 because Feedback ships in 0.2.0.)

---

## Execution Log

| Wave / task IDs | Assignments or serial reason | Validation / evidence | Commits or exception | Remaining gates / next action or stop reason |
|---|---|---|---|---|
| — | Plan written 2026-11-08 from four parallel research agents (`research/findings.md`) | — | — | D3/D5 confirmed; user requested execution (Wave 1 first) |
| W1: 1.1–1.4 | Four parallel fresh-context agents (developer ×3, technical-writer for 1.4); coordinator pre-created the `KeyboardLayoutNames.swift` stub + `xcodegen generate` so 1.1 needed no project edit | 1.1: agent `build-for-testing` ok; **coordinator fix** — pure `displayName(keyName:)` did not uppercase/filter (tests expecting "Z" and the US fallback would have failed); moved into `HotKeyShortcut.usableKeyName`. 1.2: `swift build` ok; 3 dockless fixes + frame autosave in `HelpWindowController.swift`; upstream `HelpContent.loadMarkdown` keeps one `try?` (vendored code, visible fallback body; accepted). 1.3: Sources byte-identical to zPackages ACK a6c06af / FK 8a240f1 and the CountClockWise copy; `swift build` ok. 1.4: 9 topics + manifest, JSON valid, no glyphs. Integrated: `xcodegen generate`, `build-for-testing` **TEST BUILD SUCCEEDED**, 10 help files flat in the bundle. D1 in `docs/decisions.md`. | Wave 1 commit | 1.1 unchecked until CI runs the suite (needs a push). Next: Wave 2 (2.1 first) — not yet requested |
| W2: 2.1–2.4 | 2.1 coordinator (shared `project.yml`; also pre-created the 2.2/2.3 source + test placeholders and regenerated so agents needed no project edit); 2.2–2.4 three parallel fresh-context developer agents, each with its own DerivedData | 2.1: three path packages linked to the app target only, `xcodegen generate`, `build-for-testing` ok (MarkdownUI 2.4.1 resolves locally); D2 recorded in `docs/decisions.md`. 2.2: `CitizenshipSupport` (`init(config:openURL:presentAlert:)` seams, `FeedbackView.onClose` closes the window), 4 tests. 2.3: `HelpSupport` + `fallbackTopicID`, content cached after first load, 2 tests (bundled 9 topics without the package's missing-file placeholder; test bundle → fallback). 2.4: center typed `NotificationCenter` (default distributed) + injectable `keyName`, observer removed in `deinit`, 3 tests. Coordinator review: no `try?`, no log provider. Integrated `build-for-testing` **TEST BUILD SUCCEEDED**, no warnings in app/test sources. | Wave 2 commit | 2.1–2.4 unchecked until CI runs the suite (needs a push; 2.1 also needs CI to resolve MarkdownUI). Next: Wave 3 (3.1, coordinator) — not yet requested |
| W3: 3.1 | Coordinator, serial (shared app-entry files `AppDelegate.swift`, `LLMUsageStatusApp.swift`); no agents | Right-click menu now matches D3 exactly; shortcut-failure menu gains **LLM Usage Status Help** after Settings…; `openHelp`/`sendFeedback`/`leaveTip` call `hidePanel()` first. `HelpMenuCommands(content: HelpSupport.content, appName: "LLM Usage Status")` in `.commands` (Command-? replaces the Help group; no global hotkey). **Integration adapter on 2.3's file:** `HelpSupport.content` (cached load) shared by commands and menus; `show()` uses it. Notices: `Resources/Licenses/ThirdPartyNotices.txt` (MarkdownUI 2.4.1 / NetworkImage 6.0.1 / swift-cmark 0.9.0 licenses, taken from checkouts at the `Package.resolved` revisions) — present in the built bundle. README: features, Quick Start, Help/Feedback/Tip section (feedback sends message, optional email, app + macOS version), layout-aware names, privacy outgoing-request line, architecture, notices. `xcodegen generate`; `build-for-testing` **TEST BUILD SUCCEEDED**, no errors/warnings in app sources. | Wave 3 commit | 3.1 unchecked until CI green (needs a push; with 1.1, 2.1–2.4). Manual menu check is E2. Next: Wave 4 (4.1) — not yet requested |
| W4: 4.1–4.2 | Coordinator, serial (4.1 owns shared `project.yml`/scripts/README/CHANGELOG; 4.2 depends on 4.1); one fresh-context `feature-dev:code-reviewer` agent for the independent review | 4.1: `MARKETING_VERSION` 0.2.0 / `CURRENT_PROJECT_VERSION` 200; CHANGELOG `[0.2.0] - Unreleased`; README download text says public downloads are not available yet (no Releases link; E5 pending). `release.sh` refuses a dirty tree (incl. untracked) before building and again after `xcodegen generate` (before creating `dist/<v>`), writes `SOURCE_COMMIT.txt`; `notarize-release.sh` refuses before touching credentials. `zsh -n` ok on both; dirty-tree refusal tried on the uncommitted 4.1 edits (both exit 1, no `dist/9.9.9` created). Debug `build-for-testing` ok; built Info.plist 0.2.0 / 200 (About renders `AppVersion.displayString`, unit-tested; visual check is E2 item 6). 4.2: unsigned universal Release build into scratch **BUILD SUCCEEDED**, `lipo` x86_64 arm64, 0.2.0/200, notices + help manifest in bundle. Review: no crash/concurrency/leak/privacy bugs; **2 doc fixes applied** — README + privacy help claimed no usage history stored (SectionStateCache keeps `last-sections.json`); shortcut-refusal claims now say "US key position". Rebuilt `build-for-testing` ok. Pre-existing `try?` in `SectionStateCache` → Backlog 13. Fresh Debug build for E2: `04_Exports/0.2.0-E2-Debug/…/Debug/LLM-UsageStatus.app` (not launched). | e497d36 (4.1), da93b10 (4.2 review fixes) | 4.2 + 1.1, 2.1–2.4, 3.1 need CI → **push needs user go-ahead**. Then E2 (manual), E1 any time, E3 after E1+E2. |

---
*Keep active while required work or acceptance is incomplete. On completion, retire in place (as the
v1 and Settings plans) with execution evidence and updated incoming links.*
