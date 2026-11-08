# Implementation Plan — Settings Window (launch at login, shortcut, About)

> **Persists across sessions.** Execute using the shared `commands/execute.md` procedure.
> Repair scheduling errors while preserving task IDs, completed evidence and approved scope.
> Task state/evidence is authoritative here; TASKS links here and holds backlog/inbox.
> Follow the master's `reference/task-state.md` for legacy reconciliation and archival.

**Progress:** **COMPLETE 2026-11-08** — 8/8 tasks (Waves 1–3), **E1 passed** (items 1–6, user-confirmed). Plan retired; it stays in place as the permanent execution record. Follow-ups live in TASKS Backlog/Inbox.
**Task states:** unchecked = pending / implemented-unverified / blocked (name gate);
checked = complete with required evidence. Task identity includes this plan path plus ID.

## Goal

A small, modeless Settings window, opened with Command-Comma or from the panel's right-click menu,
where the user turns launch at login on or off, changes the show/hide shortcut, and sees the app's
version.

Journey: right-click the panel → **Settings…** (or Command-Comma while the panel is up) → Settings
window comes to the front → user (a) ticks *Launch at login* and macOS adds the login item, (b) clicks
the shortcut field, presses a new chord, and the panel now toggles with it (also after a restart),
(c) reads `Version 0.1.0 (100)` under About → closes with Esc, Command-W or the close button.

## Scope decisions (2026-11-08, user)

- **Hotkey rebinding extends the app's own `GlobalHotKey`** plus a small AppKit recorder — not
  ShortcutKit. ShortcutKit is a path package outside this repo, which would break GitHub CI.
  Revisit if zPackages gets a remote.
- **Settings holds exactly three sections:** Startup, Shortcut, About. The 5-hour toggle and the
  Vibe budget stay in the right-click menu only.
- Not in scope: Feedback/Donate, Help, Sparkle (separate Inbox items), a 0.2.0 release (follows E1).

## Acceptance Criteria

- [x] **Settings…** appears in the panel's right-click menu and in the shortcut-failure status-item
      menu, and opens the window in front with keyboard focus (dockless app; no Dock icon appears).
- [x] Command-Comma opens Settings while the panel is showing; it is not claimed while the panel is
      hidden (other apps keep their own Command-Comma).
- [x] The window is modeless: changes apply immediately, no Save/Cancel; Esc and Command-W close it;
      reopening reuses one window.
- [x] **Launch at login** reflects macOS's real state (read from `SMAppService.mainApp.status`, never a
      stored copy) and re-reads it each time the window becomes active, so changes made in System
      Settings show up.
- [x] When macOS needs approval (`.requiresApproval`), the window says so and offers
      **Open Login Items…** (deep link) instead of pretending the switch worked.
- [x] When the app is not running from an Applications folder (build directory, Downloads, DMG,
      translocated), the checkbox is disabled with a one-line reason; nothing is registered.
- [x] A failed register/unregister puts the checkbox back to the real state and shows the error.
      A status query that macOS doesn't answer within 3 seconds shows "unknown", not "off", and never
      freezes the window.
- [x] The shortcut field shows the current chord spelled out (`Control–Option–Command–L`). Clicking it
      starts recording; the live hotkey is suspended while recording; Esc cancels; the next valid chord
      is committed.
- [x] A chord is rejected with a reason when it has no Command or Control modifier (this covers the
      Sequoia Shift/Option-only restriction and bare keys), or uses a key that can't be a hotkey (bare
      modifier, function/media keys). Command-Comma itself is rejected (reserved for Settings).
- [x] A chord another app already holds (`eventHotKeyExistsErr`) is refused with "already in use by
      another app"; the previous shortcut is re-registered and stays active; nothing is persisted.
- [x] A committed shortcut persists (keyCode + Carbon modifiers in UserDefaults) and is used at the next
      launch; **Reset to Default** restores Control-Option-Command-L.
- [x] Every user-visible mention of the shortcut (panel footer, failure status-item messages) shows the
      current chord, not the hardcoded default.
- [x] About shows app name, `Version <short> (<build>)` from Info.plist, a one-line description and a
      copyright line. No dead source/licence links (no public repo yet).
- [x] UI conventions: AppKit controls (house rule, same as `VibeBudgetEditor`), dark appearance, title
      "LLM Usage Status Settings", fixed size from content, `.titled + .closable` only.

## Research annex

- `research/web-research.md` — SMAppService semantics and location/translocation gotchas, Carbon
  rebinding order and error codes, Sequoia Shift/Option-only restriction, LSUIElement window-focus
  landmines, version/About conventions. URL-cited.
- `research/local-conventions.md` — house patterns: cookbook #71 self-managed settings `NSWindow`
  (chosen), QuickStatsPanel launch-at-login reference (lacks a location guard; we add one),
  ShortcutKit API (not adopted, see scope decisions).

## Current-code facts the plan relies on

- `Sources/App/GlobalHotKey.swift`: one Carbon registration, hardcoded `kVK_ANSI_L` +
  Control-Option-Command, signature `LUHS` id 1, injectable `Backend` with tests in
  `Tests/App/GlobalHotKeyTests.swift`. The Carbon handler calls one `callback` regardless of id.
- `Sources/App/AppDelegate.swift`: composition root; right-click menu via `makeMenu()`; failure
  status item with hardcoded "Control–Option–Command–L" strings; `restart()` releases the hotkey.
- `Sources/App/LLMUsageStatusApp.swift`: `Settings { EmptyView() }` placeholder scene.
- `Sources/Features/UsageStatus/Views/UsageStatusView.swift:18`: hardcoded footer hint.
- The panel is a `.nonactivatingPanel` that never becomes key, so a local key monitor can't see
  Command-Comma; a second Carbon registration that exists only while the panel is visible can.
- `Sources/App/VibeBudgetEditor.swift`: existing AppKit window precedent (`NSApp.activate` +
  `makeKeyAndOrderFront`; uses deprecated `activate(ignoringOtherApps:)` — new code uses `activate()`).
- Version: `MARKETING_VERSION 0.1.0`, `CURRENT_PROJECT_VERSION 100` in `project.yml`.

---

## Execution schedule and ownership

- Execution scope/limits: plan written 2026-11-08; user requested **Wave 1 only** (2026-11-08); Wave 1 done (c337166). User requested **Wave 2** (2026-11-08); Wave 2 done (c8d3ce7). User requested **Wave 3** (2026-11-08); Wave 3 done (288f5ab). Only E1 remains (user-operated).
- Coordinator-owned files/resources: `01_Project/project.yml` + `xcodegen generate` (new files are
  picked up by the `Sources`/`Tests` globs, but regeneration is serialized), `AppDelegate.swift`,
  `LLMUsageStatusApp.swift`, `UsageStatusView.swift`, `README.md`, DerivedData, git, tracking docs.
- **Test-running limit:** the test target is app-hosted (XcodeGen sets `TEST_HOST` to the app), so
  `xcodebuild test` launches a second app instance next to the user's running build. Local
  backpressure is `build-for-testing`; the full suite runs on GitHub CI (macos-15, Xcode 16.4). A local
  `xcodebuild test` needs the user's go-ahead. Write test code that compiles on Xcode 16.4: async
  `setUp`/`tearDown` in `@MainActor` classes **without** `super` calls (see commit 947650b).
- Interfaces to establish before dispatch (fixed here so Wave 1 runs in parallel):

```swift
// 1.1 — Sources/App/HotKeyShortcut.swift
struct HotKeyShortcut: Codable, Equatable, Sendable {
    var keyCode: UInt32          // HIToolbox virtual key code (== NSEvent.keyCode)
    var carbonModifiers: UInt32  // cmdKey | optionKey | controlKey | shiftKey bits
    static let defaultToggle: HotKeyShortcut        // kVK_ANSI_L, control|option|cmd
    static let settings: HotKeyShortcut             // kVK_ANSI_Comma, cmd
    var displayName: String                          // "Control–Option–Command–L" (en dash, spelled out)
    init?(event: NSEvent)                            // nil for bare modifiers
    enum Rejection: Equatable { case needsCommandOrControl, unsupportedKey, reserved }
    func validate() -> Rejection?
}
@MainActor final class HotKeyShortcutStore {         // UserDefaults key "hotkey.toggleShortcut"
    init(defaults: UserDefaults = .standard)
    var current: HotKeyShortcut { get }              // default when missing or undecodable
    func save(_: HotKeyShortcut); func reset()
}

// 1.2 — GlobalHotKey changes (raw values; no dependency on 1.1)
enum HotKeyID: UInt32 { case toggle = 1, settings = 2 }
func register(id: HotKeyID, keyCode: UInt32, modifiers: UInt32,
              _ action: @escaping () -> Void) -> Result<Void, RegistrationFailure>
func unregister(id: HotKeyID); func unregisterAll()
// Handler dispatches by EventHotKeyID.id; events for an id with no live registration are ignored.

// 1.3 — Sources/App/LaunchAtLogin.swift
enum LaunchAtLoginState: Equatable {
    case enabled, disabled, requiresApproval, unknown
    case unavailable(reason: String)                 // location guard or .notFound
}
actor LaunchAtLogin {
    init(backend: Backend = .live, bundleURL: URL = Bundle.main.bundleURL)
    func state() async -> LaunchAtLoginState         // 3 s timeout → .unknown
    func setEnabled(_: Bool) async -> Result<LaunchAtLoginState, LaunchAtLoginError>
    func refreshRegistrationIfEnabled() async        // re-register at launch after updates
    nonisolated static func openSystemSettings()     // SMAppService.openSystemSettingsLoginItems()
}

// 1.4 — Sources/App/AppVersion.swift
struct AppVersion: Equatable {
    init(infoDictionary: [String: Any]?)             // safe unwraps, "0.0.0" / "0" fallbacks
    static var current: AppVersion
    var displayString: String                        // "Version 0.1.0 (100)"
    var copyright: String                            // "© 2026 Luces Umbrarum"
}
```

## Tasks

### Wave 1 (parallel — four independent units, disjoint files)

- [x] **1.1**: Shortcut model, validation, display name and persistence
  - Depends on / external gates: none
  - Owns: `Sources/App/HotKeyShortcut.swift`, `Tests/App/HotKeyShortcutTests.swift`
  - Interface: `HotKeyShortcut`, `HotKeyShortcutStore` as above → consumed by 2.1, 2.2
  - Success: NSEvent → shortcut mapping uses `intersection(.deviceIndependentFlagsMask)`, maps
    Command/Option/Control/Shift to Carbon bits, ignores Caps Lock/Fn; `displayName` spells out
    modifiers in Control–Option–Shift–Command order plus a key name from a keycode table (letters,
    digits, keypad digits distinct, F-keys, arrows, Space, Return, Tab, Delete, punctuation);
    `validate()` rejects no Command/Control, bare modifiers, media/unsupported keys and the reserved
    Command-Comma; the store round-trips through an injected defaults suite and falls back to the
    default for missing or corrupt data without overwriting it.
  - Backpressure: `xcodebuild … build-for-testing` green; unit tests cover mapping, labels,
    every rejection and corrupt-data fallback (run on CI).

- [x] **1.2**: Multi-registration `GlobalHotKey` with safe rebind
  - Depends on / external gates: none
  - Owns: `Sources/App/GlobalHotKey.swift`, `Tests/App/GlobalHotKeyTests.swift`
  - Interface: `HotKeyID`, `register(id:keyCode:modifiers:_:)`, `unregister(id:)`, `unregisterAll()`
    → consumed by 2.2. Keep a temporary `register(_:)` overload that registers `.toggle` with the old
    default so `AppDelegate` compiles unchanged until 2.2 removes it.
  - Success: one handler installed once; callbacks stored per id; handler reads `EventHotKeyID` from
    the event and dispatches only to a live registration of that id (stale events are dropped);
    re-registering an id unregisters its previous reference first; a failed register returns the
    OSStatus and leaves no partial reference; the DEBUG conflict-marker fixture keeps working;
    `Backend.register` takes keyCode/modifiers/id instead of hardcoding them.
  - Backpressure: build-for-testing green; tests with the fake backend for two ids, per-id
    unregister, re-register order, failure cleanup and the conflict marker (run on CI).

- [x] **1.3**: Launch-at-login service with location guard and timeout
  - Depends on / external gates: none
  - Owns: `Sources/App/LaunchAtLogin.swift`, `Tests/App/LaunchAtLoginTests.swift`
  - Interface: `LaunchAtLogin`, `LaunchAtLoginState` as above → consumed by 2.1, 2.2
  - Success: injectable backend over `SMAppService.mainApp` (`status`, `register`, `unregister`);
    location guard returns `.unavailable` unless the bundle is a `.app` inside `/Applications` or
    `~/Applications` (subfolders allowed), on a writable volume, and not translocated (path not under
    `/private/var/folders/…/AppTranslocation/`); idempotent guards (no `register` when already
    `.enabled`, no `unregister` when not); after any throw, returns the re-read real state alongside
    the error; status calls run off the main actor with a 3-second timeout yielding `.unknown`;
    `.notFound` maps to `.disabled` (registering is still allowed); errors never logged with paths
    beyond the bundle path.
  - Backpressure: build-for-testing green; tests with a fake backend for each status, guard
    accept/reject paths (DerivedData, Downloads, `/Volumes/…`, translocated, `/Applications/X/App.app`),
    thrown errors, and a hung backend hitting the timeout (run on CI).

- [x] **1.4**: Version/About model
  - Depends on / external gates: none
  - Owns: `Sources/App/AppVersion.swift`, `Tests/App/AppVersionTests.swift`
  - Interface: `AppVersion` as above → consumed by 2.1
  - Success: reads `CFBundleShortVersionString`/`CFBundleVersion` with safe fallbacks; formats
    `Version 0.1.0 (100)`; copyright year from the build date is not needed — use a constant 2026.
  - Backpressure: build-for-testing green; tests for full, partial and missing dictionaries.

### Wave 2 (serial — 2.1 then 2.2; both need all of Wave 1, 2.2 also needs 2.1's window API)

- [x] **2.1**: Settings window and shortcut recorder (AppKit)
  - Depends on: 1.1, 1.3, 1.4
  - External gates: none
  - Owns: `Sources/App/SettingsWindowController.swift`, `Sources/App/ShortcutRecorderField.swift`,
    `Tests/App/ShortcutRecorderFieldTests.swift`
  - Interface → 2.2:
    ```swift
    @MainActor final class SettingsWindowController: NSObject, NSWindowDelegate {
        init(shortcuts: HotKeyShortcutStore, launchAtLogin: LaunchAtLogin, version: AppVersion,
             commitShortcut: @escaping (HotKeyShortcut) -> ShortcutCommitResult,
             recordingChanged: @escaping (Bool) -> Void)
        func show()   // reuse one window; NSApp.activate(); makeKeyAndOrderFront
    }
    enum ShortcutCommitResult: Equatable { case accepted, inUse, failed(OSStatus) }
    ```
  - Success: cookbook #71 shape — self-managed `NSWindow` (`.titled, .closable`), title "LLM Usage
    Status Settings", `isReleasedWhenClosed = false`, dark appearance, fixed content size, Esc and
    Command-W close. Three grouped sections built from AppKit controls: **Startup** (checkbox, status
    line, *Open Login Items…* button shown only for `.requiresApproval`, disabled checkbox + reason for
    `.unavailable`, "Checking…" while a status call runs); **Shortcut** (recorder field + inline
    message + *Reset to Default*); **About** (name, version line, one-line description, copyright).
    Login state re-read on `windowDidBecomeKey`. Recorder: click → recording mode (local key-down
    monitor, `recordingChanged(true)`), Esc cancels, first non-modifier key builds a candidate,
    `validate()` rejection shows the reason and stays in recording, otherwise calls `commitShortcut`;
    `.inUse` / `.failed` show the message and keep the previous chord displayed; recording ends on
    commit, cancel, focus loss or window close (`recordingChanged(false)` exactly once). If fronting
    fails in testing, fall back to temporary `.regular` activation restored on close (research §3).
  - Backpressure: build-for-testing green; unit tests for the recorder's state machine driven by
    synthetic `NSEvent`s (start, cancel, reject, inUse, accept, end-once); window behaviour verified
    in E1.

- [x] **2.2**: Wire Settings, Command-Comma, configurable shortcut and launch refresh (coordinator)
  - Depends on: 1.1, 1.2, 1.3, 2.1
  - External gates: none
  - Owns: `Sources/App/AppDelegate.swift`, `Sources/App/LLMUsageStatusApp.swift`,
    `Sources/Features/UsageStatus/Views/UsageStatusView.swift`, `README.md`; removes 1.2's temporary
    `register(_:)` overload in `GlobalHotKey.swift` (coordinator-owned at this point)
  - Success: toggle hotkey registered from `HotKeyShortcutStore.current` at launch; **Settings…**
    (key equivalent ",") added to the right-click menu above Restart and to the failure status-item
    menu; Command-Comma registered as `.settings` when the panel shows and unregistered when it hides
    (the panel opening Settings hides itself first); `commitShortcut` = register new under `.toggle` →
    on success save to the store; on failure re-register the stored chord and return `.inUse` /
    `.failed`; `recordingChanged` unregisters `.toggle` while recording and restores it after;
    `restart()` and `applicationWillTerminate` use `unregisterAll()`; the failure status-item messages
    and the panel footer use `current.displayName` (footer gets it passed in, no store access from
    the view); `Settings { EmptyView() }` replaced so no auto Command-Comma item can hijack the key
    (`CommandGroup(replacing: .appSettings) {}`); `LaunchAtLogin.refreshRegistrationIfEnabled()`
    runs once at launch; README documents Settings, rebinding and launch at login.
  - Backpressure: `xcodegen generate` + Debug build green; build-for-testing green; push and CI
    green with the full suite (≥ 147 tests + the new ones).

### Wave 3 (verification — after 2.2; 3.1 and 3.2 parallel, different owners)

- [x] **3.1**: Full verification
  - Depends on: 2.2
  - External gates: none
  - Owns: verification evidence in the Execution Log
  - Success: CI green on the integrated commit with the test count recorded; local Release build of
    the universal app succeeds; `rg -n 'Control.Option.Command.L' Sources` only hits the default's
    definition and comments; no `try?` added (project rule).
  - Backpressure: `gh run view <id>` result; `xcodebuild -configuration Release build` exit 0.

- [x] **3.2**: Independent code review of the plan's diff
  - Depends on: 2.2
  - External gates: none
  - Owns: review report; findings return to the owning task, re-run 3.1 after fixes
  - Success: `/code-review` on the range since the plan commit; confirmed findings fixed or
    explicitly declined with a reason; focus on hotkey dispatch identity, recorder end-once,
    main-actor blocking and launch-at-login honesty.
  - Backpressure: review output recorded; affected checks re-run.

## External checks

- [x] **E1**: Manual acceptance in a fresh build (user-operated)
  - Depends on: 3.1, 3.2
  - Requires: the user at this Mac. A fresh Debug build can be handed off under the standing
    fresh-build authorization. The launch-at-login part needs the app in `/Applications`, which
    replaces the installed copy — **separate user go-ahead**; recovery: untick the checkbox (or remove
    the item in System Settings → General → Login Items) and reinstall the previous copy from
    `dist/0.1.0` if wanted.
  - Owns: acceptance evidence (screenshots or the user's confirmation per item)
  - Gates: overall plan completion and every acceptance criterion above; does not gate Waves 1–3.
  - Success / verification:
    1. From the build directory: Settings opens from the right-click menu and with Command-Comma
       while the panel is up; Command-Comma does nothing for this app while the panel is hidden.
       Window is in front and focused; no Dock icon; Esc and Command-W close it.
    2. Launch at login is disabled with the "move to Applications" reason.
    3. Rebind to e.g. Control-Option-Command-U; panel toggles with the new chord, not the old one;
       footer shows the new chord; Restart keeps it; Reset to Default brings back L.
    4. Shift-Option-K and a bare key are rejected with reasons. With the DEBUG conflict marker
       (`LUHS_HOTKEY_CONFLICT_FILE`) present, a commit reports "already in use" and the old chord
       still works.
    5. From `/Applications` (after go-ahead): tick Launch at login → macOS "login item added"
       notice; System Settings shows it; turn it off there → reopening Settings shows the real state;
       untick in Settings removes it.
    6. About shows `Version 0.1.0 (100)`.
  - While unavailable: Waves 1–3 proceed; acceptance criteria stay unverified.
  - **Result 2026-11-08 (user, build 288f5ab, PID 38110 from the build folder):** items 1, 2, 3, 4
    and 6 **pass** (user confirmation). Item 4's "already in use" sub-check was not run live
    (instance launched without `LUHS_HOTKEY_CONFLICT_FILE`; covered by unit tests). Item 5 open —
    needs the `/Applications` install go-ahead. **Item 5 pass** (same day): build installed to `/Applications` (SHA matches), launched as PID 57292; tick → notice, System Settings off → Settings shows real state, untick removes (user confirmation). Launch-time refresh-log check not yet run (needs a launch with the item enabled).

---

## Wave 1 as-built deviations (accepted at integration)

- `HotKeyID` is nested: `GlobalHotKey.HotKeyID` (avoids a top-level name clash). 1.2 also kept a
  temporary `unregister()` (toggle only) next to `register(_:)`; 2.2 removes both. `dispatch(id:)` /
  `dispatch(rawID:)` are internal test seams. A failed re-register leaves the id unbound — 2.2's
  `commitShortcut` re-registers the stored chord, as planned.
- `LaunchAtLogin.Backend` also carries `isWritableVolume`, `homeDirectory` and `timeout` (3 s live);
  `LaunchAtLoginError` = `.unavailable(reason:)`, `.failed(message:state:)`, `.timedOut(state:)`, each
  with `.state`. Backend calls race a `DispatchQueue.global` block against a timer (a hung
  synchronous SMAppService call can't pin a cooperative thread). An `.unknown` initial read blocks
  `setEnabled` with `.timedOut`.
- Coordinator fix: `.requiresApproval` counts as registered — enabling is a no-op, disabling
  unregisters (the plan's "no unregister when not `.enabled`" would have left a pending
  registration behind when the user switched it off).
- `HotKeyShortcut` accepts Escape as a key; 2.1's recorder should treat a bare Escape as cancel.

## Wave 2 as-built notes (accepted at integration)

- 2.1 fronts the window with `NSApp.activate()` + `makeKeyAndOrderFront` only; the `.regular`
  activation fallback was **not** added — E1 item 1 must confirm the window comes to the front.
- Reset to Default goes through `commitShortcut(.defaultToggle)`; the window never saves to the store.
  `.unknown` login state leaves the checkbox enabled (off) so the user is not stuck.
- 2.2: the temporary `register(_:)` / `unregister()` overloads now live as a `fileprivate` test-only
  extension in `GlobalHotKeyTests.swift` (production API has only the id-based calls). A failed
  Command-Comma registration is logged (os `notice`) and not surfaced — Settings… stays in the menu.
  The fallback status-item hint now also suggests choosing another shortcut in Settings.

## Wave 3 review triage (3.2, `/code-review high 021402b..c85859a`, 10 findings)

Fixed in 288f5ab (tests added except the Restart path):
- Standard Command(-Shift) chords (Command-C/V/Q/W/Space/Tab…) are refused as `.systemShortcut` — a
  global toggle on them would take Copy, Quit, Spotlight from every app.
- A stored chord that fails `validate()` falls back to the default (stored bytes untouched).
- Recorder: only a bare, non-repeating Space/Return starts recording (holding a just-recorded
  Control-Space no longer restarts it).
- Settings clears a stale shortcut error when it becomes key again.
- A failed Restart restores Command-Comma while the panel is showing.

Declined / deferred, with reasons:
- Command-Comma held while the HUD shows and the user switches apps by keyboard: by design (plan
  criterion; any click hides the HUD and releases it). Narrow keyboard-only case → TASKS Inbox.
- US-ANSI key names on non-US layouts: presentational, not a correctness bug → TASKS Backlog.
- `register()` on an already-enabled login item at launch: Apple documents re-registering to
  refresh the path; unregister-then-register risks a new approval prompt. Check the launch log in
  E1 item 5 → TASKS Inbox.
- Toggle registered twice per commit: idempotent; `commitShortcut`'s own restore is needed for
  Reset to Default, which commits outside recording.
- `HotKeyShortcutStore.reset()` (tested API, harmless) and the writable-volume guard (defence in
  depth) kept.

## Operational Learnings

- GitHub CI runs Xcode 16.4 / Swift 6.1, older than this Mac's Xcode 27.2. Main-actor test classes
  must use async `setUp`/`tearDown` without `super` calls; a `View`-returning static helper needs an
  explicit `@MainActor`. Local success doesn't prove CI success.

## Blocked Tasks

None.

---

## Execution Log

| Wave / task IDs | Assignments or serial reason | Validation / evidence | Commits or exception | Remaining gates / next action or stop reason |
|---|---|---|---|---|
| Wave 1: 1.1, 1.2, 1.3, 1.4 | Four parallel fresh-context developer agents, disjoint files; coordinator pre-created the six files + `xcodegen generate`, each agent built into its own DerivedData | Integrated `build-for-testing` green (scratch DerivedData); CI run 42426466709 green, **189 tests, 0 failures** (was 147) | c337166 (all four — one reviewable building-block set, not wired in) | Wave 2 (2.1 window, then 2.2 integration) ready; not yet requested |
| Wave 3: 3.1 ∥ 3.2 | 3.1 coordinator; 3.2 `/code-review high` as a forked background reviewer (independent context) on 021402b..c85859a; coordinator triaged and fixed | Release universal build exit 0 (x86_64 + arm64, scratch DerivedData, no new warnings); `Control.Option.Command.L` 0 hits in Sources; no `try?` in the plan diff; review: 5 fixed, 5 declined (see triage); post-fix `build-for-testing` green; **CI run 42437157432 green, 204 tests, 0 failures** | c85859a (Wave 2 docs), 288f5ab (review fixes) | E1 only: fresh Debug build `build/e1-2026-11-08-288f5ab/…/Debug/LLM-UsageStatus.app` launched and verified running (PID 38110); launch-at-login part needs a separate /Applications go-ahead |
| Wave 2: 2.1 → 2.2 (serial) | 2.1: one fresh-context developer agent (owned 3 pre-created files); 2.2: coordinator (owned files + shared project) after reviewing 2.1's diff | `xcodegen generate` + integrated Debug `build-for-testing` green (no new warnings); no `try?`; `Control.Option.Command.L` no longer in Sources (only via `HotKeyShortcut` names); CI run 42433815828 green, **200 tests, 0 failures** (+11 recorder tests) | 2dbec79 (Wave 1 bookkeeping docs), c8d3ce7 (2.1 + 2.2 — one reviewable feature outcome) | Wave 3 (3.1 verification ∥ 3.2 code review) ready; not yet requested. No app build handed off (E1 waits for Wave 3) |

---
*Keep active while required work or acceptance is incomplete. On completion, archive with execution
evidence and update incoming links before retiring the active copy.*
