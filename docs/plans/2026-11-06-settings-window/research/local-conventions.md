# Local conventions research — Settings window for LLM-UsageStatus

Agent: local-conventions. Produced during `/make-plan`, 2026-11-06. All paths verified by direct
read; nothing modified.

---

## A) ShortcutKit API findings

**Package location:** `/Users/sim/ProgrammingProjects/1-macOS/zPackages/Sources/ShortcutKit/`
(1 package product `ShortcutKit`, declared in `/Users/sim/ProgrammingProjects/1-macOS/zPackages/Package.swift`,
macOS 14+, swift-tools 6.2, targets pinned to Swift-5 language mode). 15 source files, ~2,000 lines.

**Public API surface (signatures as declared):**

- `ShortcutAction` protocol — `ShortcutAction.swift:36`:
  ```swift
  public protocol ShortcutAction: CaseIterable, Codable, Hashable {
      var displayName: String { get }
      var category: String { get }
      var defaultShortcut: CustomKeyboardShortcut { get }
  }
  ```
- `CustomKeyboardShortcut` — `CustomKeyboardShortcut.swift:10`: `Codable, Hashable, Equatable,
  Sendable` with `keyCode: Int`, `modifiers: NSEvent.ModifierFlags`, `displayName: String`.
  `init(keyCode:modifiers:displayName:)` (:15), `init?(from keyEvent: NSEvent)` (:28),
  `.none` sentinel with keyCode −1 (`isUnbound` :148), `resolvedDisplayName` (:166, live
  layout-correct label), `hasModifier(in:)` (:189, modifier floor check).
- `ShortcutStore<Action>` — `ShortcutStore.swift:14`: `@Observable @MainActor public final class`.
  `init(userDefaultsKey: String, defaults: UserDefaults = .standard)` (:32). Persists
  `[Action: CustomKeyboardShortcut]` as one JSON UserDefaults key; seeds defaults on first
  launch, backfills new actions, preserves corrupt bytes in memory without saving (`lastError`,
  :40). Accessors: `shortcut(for:)`, `setShortcut(_:for:)`, `resetToDefaults()`,
  `isShortcutAssigned(_:excluding:)`, `action(boundTo:)`.
- `ShortcutRecorder` — `ShortcutRecorder.swift:25`: SwiftUI drop-in settings row; the capsule
  itself is the record trigger (no Record button). `ShortcutRecorder.swift:55`:
  ```swift
  public init(shortcut: Binding<CustomKeyboardShortcut>, title: String,
              onRecordingChange: @escaping (Bool) -> Void = { _ in },
              onCandidateChange: @escaping (CustomKeyboardShortcut?) -> Void = { _ in },
              isCommitEnabled: @escaping (CustomKeyboardShortcut) -> Bool = { _ in true })
  ```
  Companion `ShortcutRow`; shared constants `titleColumnWidth = 180`, `columnSpacing = 8`.
- Global hotkey path:
  - `GlobalHotKeyMonitor` — `GlobalHotKeyMonitor.swift:65`: `@MainActor public final class`;
    `init(signature: OSType = 'SKGH')` (:87), `convenience init(signature string: String)` (:94).
    Implements `HotKeyRegistering` (:54): `register(_ shortcut: CustomKeyboardShortcut, id: UInt32,
    onTrigger: @escaping () -> Void) -> Bool`, `unregister(id:)`, `unregisterAll()`,
    `isRegistered(id:)`. Rebind = re-register same id; permission-free Carbon.
  - `GlobalHotkeyBinder<Action>` — `GlobalHotkeyBinder.swift:35`: `@Observable @MainActor`;
    `init(store:policy:monitor:)` (:89), `setHandler(_:for:)` (:106), `activate()` (:115),
    `deactivate()` (:124), `beginRecording()` (:134) — stands down Carbon so the live hotkey
    cannot fire mid-record — `finishRecording()` (:142, idempotent), `commit(_:for:) -> Bool`
    (:163), `conflicts(for:assigning:)` (:198), `advisories(for:)` (:203), `binding(for:)` (:209),
    `onRecordingChange(_:)` (:218). Error enum `GlobalHotkeyError` (:59): `.refused(ShortcutConflict)`
    and `.rejectedByOS(attempted:kept:)` (Carbon −9868 → silent revert).
  - `ShortcutPolicy` — `ShortcutPolicy.swift:26` with `.globalHotkey` default policy
    (modifier floor, system scope, reserved combos).
  - No `deinit` teardown under Swift 6 — clean up from `applicationWillTerminate`
    (also `ClipSmartApp.swift:1935`).

**Fleet-adoption context:** `zPackages/docs/SHORTCUTKIT-FLEET-SURVEY.md` — ClipSmart/Aloft is the
only `import ShortcutKit` app in the fleet; six apps (SearchAway, QuickScreenShot, LaunchAway,
QuickStatsPanel, WindowManagement, Contour) carry drifted hand-rolled copies.

**Integration steps (as done by ClipSmart / Aloft):**
1. XcodeGen `project.yml` (`/Users/sim/ProgrammingProjects/1-macOS/ClipSmart/01_Project/ClipSmart/ClipSmart/project.yml:13-18, 65-66`):
   ```yaml
   packages:
     ShortcutKit:
       path: ../../../../zPackages
   # target → dependencies:
     - package: ShortcutKit
       product: ShortcutKit
   ```
2. An action enum conforming to `ShortcutAction` (ClipSmart has `GlobalHotkeyAction`
   `Models/GlobalHotkeyAction.swift`, header: "The set of globally-bindable actions for
   ShortcutKit's ShortcutStore… paired with `GlobalHotkeyBinder`/`GlobalHotKeyMonitor`").
3. Unique UserDefaults key per store: `ShortcutStore<GlobalHotkeyAction>(userDefaultsKey: "Aloft.GlobalHotkey")`
   (`ClipSmartApp.swift:1755`); migration/seed messaging at `ClipSmartApp.swift:1805+`.
4. Settings row binding — `KeyboardSettingsView.swift:128-145`: `shortcut:` binding get/`binder.commit(candidate,
   for: .toggleOverlay)` set, `onRecordingChange: binder.onRecordingChange`, `isCommitEnabled:`
   gating on non-advisory conflicts, `.onDisappear { binder.finishRecording() }`.

---

## B) Settings-window precedent in the user's dockless apps

Two house patterns:

**B1 — self-managed `NSWindow` (cookbook #71, source QuickStatsPanel):** the documented default
for "no regular activation" HUD apps.
- Files: `/Users/sim/ProgrammingProjects/1-macOS/QuickStatsPanel/01_Project/Sources/QuickStatsPanel/Panel/SettingsWindowController.swift`
  + `AppDelegate.swift` (`AppDelegate.swift:239`: `settingsHotKey.register(.commaSettings)` opens
  settings while the panel is up).
- Why: in an LSUIElement app the SwiftUI `Settings` scene + `showSettingsWindow:` silently
  no-op; fix is one's own `NSWindow` with `NSHostingController`, `isReleasedWhenClosed = false`,
  then `NSApp.activate(ignoringOtherApps: true)` + `makeKeyAndOrderFront(nil)`.
- Command-Comma: NOT via a menu alone — the Settings scene auto-installs a ⌘, "Settings…" item
  that hijacks ⌘, before your window's responders; house fix is
  `CommandGroup(replacing: .appSettings) { }` to drop the auto item, then ⌘, reaches your own
  local key handling (cookbook #71 Gotchas; source LaunchAway `LaunchAwayApp.swift`).

**B2 — SwiftUI `Settings` scene + activation dance (Aloft/ClipSmart):** works only because Aloft
already runs a full SwiftUI app scene with a key-overlay path.
- `ClipSmartApp.swift:19-30`: `Settings { ThemedContainer { SettingsView() } }`.
- `Views/ContentView.swift:882-894` `openSettingsWindow()`: close overlay →
  `NSApp.activate(ignoringOtherApps: true)` →
  `SettingsWindowPresenter.shared.request { openSettings() }` (@Environment(\.openSettings)).
- `Utilities/SettingsWindowAttachment.swift:7-51` `SettingsWindowPresenter`: observes
  `NSWindow.willClose`; on present `NSApp.unhide(nil)` → activate → deminiaturize →
  `makeKeyAndOrderFront(nil)` — "accessory apps can't open a regular window without activating".
- Command-Comma as an overlay-local rebindable action: `AloftShortcutAction.swift:218`
  `.openSettings` default `.init(keyCode: 43, modifiers: [.command], displayName: "⌘,")`,
  dispatched via `KeyboardNavigationModifier.swift:328`.

**Fleet shell package:** `zPackages/Sources/MacUIKitSettings/` — settings-panel chrome
(`SettingsSidebarShell` — HSplitView sidebar shell; `SettingsTab` protocol +
`SettingsTabPlacement`: house convention **General first → domain tabs → Advanced
second-to-last → About last**; `PermissionStatusRow`, `ResetToDefaultsButton`,
`SettingsSectionFooter`). Adopters: Penumbra, VAM, ClipSmart, Mural (~8 apps). For a 3-section
single-pane window this is overkill; noted for future growth.

**Recommendation for LLM-UsageStatus: B1** — self-managed window per cookbook #71; the app is an
AppKit-composed HUD without Aloft's scene structure.

---

## C) Launch-at-login precedent

Only precedent: **QuickStatsPanel**
(`/Users/sim/ProgrammingProjects/1-macOS/QuickStatsPanel/01_Project/Sources/QuickStatsPanel/Views/SettingsView.swift:382-472`).
A SwiftUI `Toggle("Launch at login", isOn:)` in a `Form { Section("Startup") }`.

```swift
private func setLaunchAtLogin(enabled: Bool) {
    do {
        if enabled {
            if SMAppService.mainApp.status != .enabled {     // guard: redundant register() throws
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        }
    } catch {
        // toggle already flipped — re-sync to real registry state so it can't lie
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }
}
```

Checks encoded there (doc comment :444-455): non-sandboxed ⇒ `SMAppService.mainApp` enrols the
main bundle, no login-helper target needed; idempotency guard on `.status` before acting;
failure honesty — on throw, re-sync the switch to the real registry state; **OS as single source
of truth** — the toggle is view-local `@State` (not persisted), re-read in `.onAppear` (:404) so
System Settings ▸ Login Items changes are reflected. `.requiresApproval` status called out as
possible.

Non-finding, stated plainly: **there is no numbered launch-at-login cookbook pattern**; cookbook
`SMAppService` matches only concern a privileged helper (#150/#152). QuickStatsPanel's
SettingsView is the reference. (Caveat vs. web research: QuickStatsPanel has **no location
guard** — see web-research.md §1; dev builds run from build directories, so LLM-UsageStatus
needs the guard.)
