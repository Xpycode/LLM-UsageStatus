# Web research — Settings window for a dockless macOS HUD

Agent: web-research. Produced during `/make-plan`, 2026-11-06. All claims URL-cited at the end of
each section. Context assumed: macOS 15+, Swift 6, Developer ID + notarized, non-sandboxed,
no Dock icon (LSUIElement), Carbon `RegisterEventHotKey` hotkey currently hardcoded to
Control-Option-Command-L.

---

## 1. SMAppService (launch at login)

### Findings

**The modern API and what registration means.** `SMAppService` (macOS 13+) replaces
`SMLoginItemSetEnabled`; "SMAppService should be used now to register any new Login Item"
(theevilbit). For the main app bundle — a non-sandboxed Developer ID app registering *itself* —
the correct object is `SMAppService.mainApp`. No helper bundle, no entitlement, no LaunchAgent
plist required.

**API semantics (official):**
- `register() throws` — for the main app, the application launches on subsequent logins. Already
  registered → `kSMErrorAlreadyRegistered`; not approved by the user → `kSMErrorLaunchDeniedByUser`.
- `unregister() throws` — opposite; already-unregistered returns `kSMErrorJobNotFound`.
- **Current state**: `SMAppService.mainApp.status` — `.notRegistered`, `.enabled`,
  `.requiresApproval`, `.notFound`. (Note: `.requiresApproval`, not `.requiresAttention`.)
- The user can flip or remove the item in System Settings → General → Login Items at any time —
  **read the state from `status` rather than persisting your own mirror in UserDefaults**. Re-read
  on appear AND when the window regains activity. `SMAppService.openSystemSettingsLoginItems()`
  deep-links the user to the Login Items pane — use it when status is `.requiresApproval`.
- **Async timing**: register/unregister/status are synchronous, throwing, XPC-backed calls into
  backgroundtaskmanagementd; no documented promise about when the BTM database is durably
  updated. More importantly: real 2025/2026 projects have hit macOS occasionally not answering
  SMAppService queries at all, freezing the Settings window when queried synchronously on the
  main actor; one project moved the query to its own thread with a 3-second timeout and reported
  "unknown" rather than "off" when the system didn't answer. Treat these as *potentially slow*
  calls, not instant property reads.

**When registration legitimately fails / behaves badly (2025–2026 gotchas):**
- **App location is the #1 gotcha.** BTM stores a *concrete URL*. Registration from `~/Downloads`,
  an App Translocation mount, a mounted DMG, a `.build/` directory, or a bare executable creates
  a login item pointing there which then breaks. Evidence gatherable via `sfltool dumpbtm`.
- **Translocation**: quarantined apps run from a random path; translocation reported even for
  quarantined apps already moved to /Applications ("the login item then points to that path, and
  it stops working").
- **After an update/change of signature**, a previously good login item can stop working until
  re-registered — re-run `register()` on each launch when enabled (ignoring already-registered
  errors), or check status first.
- **`.requiresApproval` after the user turns the item off in System Settings**: a fresh
  `register()` does **not** fix it; the user must re-approve in System Settings — the UI must
  surface this state with the `openSystemSettingsLoginItems()` link, not a plain toggle.
- Codesigning failure `-67054` (`errSecCSBadResource`) on early Ventura 13.0/13.1 was an Apple
  bug, fixed in later 13.x. Unregister can also fail with "Could not find the specified service"
  leaving an unclean state.
- On `.notFound`/never-registered: don't treat as fatal — call `register()` anyway.
- No credible 2025/2026 requirement that a *subfolder* of ~/Applications needs special handling,
  but the stricter community pattern is to only register when the bundle is inside an
  Applications folder (includes /Applications subfolders and /Applications/Utilities; excludes
  `~/Downloads` and unstable locations). iCloud Drive: location-stability concern, no Apple
  statement either way (conflict noted).

### Recommended pattern for this app

Guard registration with location checks (proper `.app` bundle, volume not read-only, inside an
Applications domain); if registration is withheld, disable/annotate the toggle — this matters
because dev builds run from build directories. Bind the toggle directly to
`SMAppService.mainApp.status` (never a persisted bool), re-read when the window becomes active,
show an "approve in System Settings…" row + deep link when status is `.requiresApproval`.
Expect macOS's "login item was added" notification on first register. Notarized + Developer ID +
non-sandboxed is the *best case* for this API — no entitlements or helper needed.

Sources section 1:
- https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp
- https://developer.apple.com/documentation/servicemanagement/smappservice/register()
- https://developer.apple.com/documentation/servicemanagement/smappservice/unregister()
- https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum
- https://developer.apple.com/documentation/servicemanagement/smappservice/opensystemsettingsloginitems()
- https://nilcoalescing.com/blog/LaunchAtLoginSetting/
- https://theevilbit.github.io/posts/smappservice/
- https://developer.apple.com/forums/thread/747573
- https://developer.apple.com/forums/thread/707482
- https://github.com/chriskievit/ampersand/issues/4
- https://github.com/joaodavidsilva/brightboi/issues/97
- https://github.com/blamechris/Aeolus/issues/337
- https://github.com/crissmoldovan/agent-communications/pull/99
- https://eclecticlight.co/2023/05/09/what-causes-app-translocation/

---

## 2. Rebinding a Carbon global hotkey

### Findings

**Viability in 2026.** Carbon's `RegisterEventHotKey` is deprecated-but-alive and remains on
macOS 26 Tahoe; unlike `CGEventTap` or global NSEvent monitors it requires **no Accessibility
grant and shows no permission dialog** (go-macos/hotkey docs). Apple's modern doc pages no longer
resolve (404) — treat as legacy, not removed.

**Rebinding pattern.** `UnregisterEventHotKey(oldRef)` → `RegisterEventHotKey(keyCode,
carbonModifiers, EventHotKeyID(signature:id:), GetApplicationEventTarget(), 0, &newRef)`. From
shipping hotkey adapters:
- **Check the unregister result and gate dispatch on identity.** A refused Carbon removal leaves
  the *old* chord registered and still firing while the Settings UI shows the new one —
  production plugins store the binding each registration was made for, refuse events whose
  `EventHotKeyID` doesn't match the current binding, and retry the removal later.
- **Register → verify, always surface `RegisterEventHotKey`'s return code** — some chords
  register "successfully" only to be invisible failures in practice.
- **`eventHotKeyExistsErr` (−9878) is cross-process**: another Carbon hotkey holder (any process)
  claiming the combo blocks you. Reusing the same `EventHotKeyID` in your own process is fine —
  what collides is the *combo*, not the ID. Safe rebind order is always unregister first, then
  register.

**Recording UI → Carbon mapping.**
- `NSEvent.keyCode` **is** the HIToolbox virtual key code Carbon wants — no translation.
- Modifiers must be re-mapped: `NSEvent.ModifierFlags` → Carbon `cmdKey`/`optionKey`/`controlKey`/
  `shiftKey` bits (canonical table: soffes/HotKey NSEventModifierFlags+HotKey.swift; same
  approach inside Sindre Sorhus's KeyboardShortcuts). Filter with
  `intersection(.deviceIndependentFlagsMask)`.
- **Persist keycode + modifiers, not characters**: virtual keycodes are positional (ANSI layout),
  stable across Dvorak/azerty; `charactersIgnoringModifiers` is not. Keypad digits have distinct
  keycodes from top-row digits and can be distinguished.

**Pitfalls.**
- **macOS 15 Sequoia change (anti-keylogging):** registrations using **only Shift and/or Option**
  as modifiers fail with `-9868 eventInternalErr`; Apple confirmed intentional, addressed in
  15.2 Beta 2, with user reports of it resurfacing on 15.x after screen unlocks. Our default
  Control-Option-Command-L is unaffected — but the recorder should warn/reject shift-/option-only
  bindings proactively (conflict noted: scope of the restriction is ambiguous).
- Carbon does **not** conflict-check against macOS system shortcuts or other apps' menu key
  equivalents — only other Carbon holders, via `eventHotKeyExistsErr`. On conflict, tell the
  user the combo is taken.
- `com.apple.symbolichotkeys` is an override layer, not a catalogue — don't rely on it for
  conflict detection.

### Recommended pattern for this app

Keep one owning hotkey coordinator keyed by a stable `EventHotKeyID`. On rebind: unregister old,
**check the OSStatus**; register new with the same ID, **check the OSStatus**; on
`eventHotKeyExistsErr` keep the UI in "this combo is taken by another app" state rather than
silently persisting. Persist `keyCode + modifiers` in UserDefaults. Recorder: local `NSEvent`
monitor, convert with the standard mapping, restrict to Command/Option/Control/Shift, reject
option/shift-only with a Sequoia explanatory message, filter media/fn keys, render the label
from the keycode (position-stable), distinguish keypad keys.

Sources section 2:
- https://developer.apple.com/forums/thread/763878
- https://pkg.go.dev/github.com/go-macos/hotkey
- https://github.com/soffes/HotKey/blob/main/Sources/HotKey/NSEventModifierFlags%2BHotKey.swift
- https://github.com/soffes/HotKey/issues/2
- https://github.com/sindresorhus/KeyboardShortcuts/blob/main/Sources/KeyboardShortcuts/Shortcut.swift
- https://swiftpackageregistry.com/sindresorhus/KeyboardShortcuts
- https://github.com/saurabhav88/EnviousWispr/issues/3108
- https://github.com/saurabhav88/EnviousWispr/issues/3273
- https://github.com/yonatangross/tower/pull/44
- https://stackoverflow.com/questions/28281653/how-to-listen-to-global-hotkeys-with-swift-in-a-macos-app
- https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MenuList/Articles/SettingMenuKeyEquiv.html

---

## 3. Settings window conventions for a dockless/menu-bar utility (2026 norms)

### Findings

**Norms (2025/2026 codified):** opened via a "Settings…" menu item with Command-Comma always
assigned; **modeless** — changes apply immediately, no Save/Cancel; only the red close button
enabled; closable with Esc and Command-W; sidebar/toolbar item for *panes* in tabbed designs;
window title "APP_NAME Settings" for single-pane windows. For 3 sections (login, hotkey, About),
the single small non-tabbed window is the conventional choice.

**SwiftUI Settings scene + LSUIElement = active failure zone:**
- `SettingsLink` doesn't work reliably inside `MenuBarExtra`; assumes a regular app context.
- The legacy `sendAction("showSettingsWindow:")` escape hatch was removed in Sonoma 14;
  `@Environment(\.openSettings)` only works from a SwiftUI render-tree context.
- Even when it fires, **macOS won't make the settings window key without a Dock icon**: it opens
  *in the background*. Steinberger's working formula (Swift 6, macOS 14+) involves temporarily
  setting `.regular` activation policy with ~100–200 ms delays and restoring `.accessory` on
  close; scene declaration order matters.
- For launch behavior: set `.prohibited` in `willFinishLaunching`, then `.accessory` in
  `didFinishLaunching` so nothing steals focus at startup.
- For a plain window from a status item: either (a) temporarily promote to `.regular` while the
  settings window is open and restore `.accessory` in `windowWillClose` — arguably *correct*,
  since the Dock icon then represents the real window — or (b) a nonactivating `NSPanel`.
  A manually-managed `NSWindow` without some activation will not reliably become key for an
  `.accessory` app. Parts of the community still argue about ideal focus behavior here — treat
  the promotion trick as a tested fallback, not an assumption either way.
- Command-Comma only auto-fires via a *main menu* NSMenuItem if the app is frontmost; key
  equivalents belong to the app's menu bar, not a window. A no-Dock, no-MainMenu HUD gets a
  natively useful Command-Comma only with a (hidden) app menu or its own local event monitor.
- `NSApp.activate(ignoringOtherApps:)` is deprecated in macOS 14+; use `NSApp.activate()` in new
  code.

### Recommended pattern for this app

For an AppKit-composed HUD (not a SwiftUI-scene-lifecycle app), **avoid the SwiftUI `Settings`
scene entirely**: a small, `NSWindow` (or nonactivating `NSPanel` if zero focus-steal is wanted)
hosting the settings content via `NSHostingView`, `isReleasedWhenClosed` handled explicitly,
`.titled + .closable` only, modeless, Esc/Command-W to close, fixed size sized from content.
Open from the status menu: `NSApp.activate()` then `makeKeyAndOrderFront(nil)`; add the
`.regular`-promotion fallback only if fronting genuinely fails in testing. Add a local key-event
path for Command-Comma (menu item with `keyEquivalent = ","` and/or a window-local monitor).

Sources section 3:
- https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items
- https://github.com/orchetect/SettingsAccess
- https://artlasovsky.com/fine-tuning-macos-app-activation-behavior
- https://zenn.dev/usagimaru/articles/b2a328775124ef?locale=en
- https://developer.apple.com/documentation/swiftui/settings
- https://developer.apple.com/documentation/swiftui/environmentvalues/opensettings
- https://developer.apple.com/documentation/appkit/nsmenu/performkeyequivalent(with:)?language=objc
- https://philz.blog/nspanel-nonactivating-style-mask-flag/
- https://vburojevic.dev/blog/menu-bar-apps-swiftui-appkit/

---

## 4. Version / About conventions

### Findings

**Reading version reliably.** `CFBundleShortVersionString` (marketing version) and
`CFBundleVersion` (build) via safe unwraps:

```swift
let info = Bundle.main.infoDictionary
let version = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
let build  = info?["CFBundleVersion"] as? String ?? "1"
```

Common display form: `Version 1.2.0 (123)` — Apple's About panes show "Version X" plus build
underneath.

**Standard About content in small OSS Mac utilities:** app name + version + build, copyright
year + holder, license (embedded text or name + link), acknowledgments/"Open Source Licenses"
per bundled dependency, link to the public source repository. For a Developer ID app outside
the App Store, "Download from GitHub" framing and update feed URL are conventional only when
they exist.

### Recommended pattern for this app

An inline "About" section in the Settings window — a distinct About window is overkill for a
3-section utility. Content: app name, `Version (short) (build)` from Info.plist safe unwraps,
one-line HUD description, copyright line. License/source links only once a public repository
exists (currently a placeholder — leave link rows out rather than shipping dead links).

Sources section 4:
- https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleshortversionstring
- https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion
- https://stackoverflow.com/questions/24501288/getting-version-and-build-information-with-swift
- https://stackoverflow.com/questions/25965239/how-do-i-get-the-app-version-and-build-number-using-swift
- https://github.com/mthomason/MAD/pull/16
- https://github.com/jimeh/huterm/pull/259
- https://github.com/PeterBlessy/notesage/issues/949

---

## Cross-source conflicts noted

1. **Sequoia shift/option-only restriction scope (API-wide vs sandbox-only):** Apple described
   it as a general API change; community reporting saw it mostly hitting sandboxed apps. Our
   app is non-sandboxed and our combos include Command and Control — conservative move: the
   recorder warns on shift/option-only regardless.
2. **LSUIElement + plain NSWindow becoming key:** Steinberger needed the `.regular` promotion
   trick for the *SwiftUI Settings scene* window; properly-configured accessory windows/panels
   can become key with `NSApp.activate()`. Apply to different window types; implement promotion
   as a tested fallback, not an assumption.
3. **`.requiresApproval` is the actual case name** (not `.requiresAttention`).
4. **~/Applications subfolders / iCloud Drive:** the "only register inside an Applications
   folder" rule is community best practice extrapolated from BTM's URL storage; no Apple source
   either way.
