# Research findings — 0.2.0 plan (2026-11-08)

Four parallel research agents (local code + web). Condensed; the plan cites these sections.

## R1 — Layout-aware shortcut names (Backlog 11)

- `displayName` callers (all main-actor): `AppDelegate.swift` `showHUD()` footer (recomputed per
  show), `showShortcutFallback` messages, `ShortcutRecorderField.refreshDisplay()` (label + AX value).
  `GlobalHotKey` binds raw key codes; only names are layout-dependent (a virtual key code is a
  physical position — on QWERTZ the key labelled Z is `kVK_ANSI_Y` and must be *named* "Z").
- `validate()` uses the US `keyNames` table as the supported-key list → keep the table.
- API: `TISCopyCurrentASCIICapableKeyboardLayoutInputSource()` → `kTISPropertyUnicodeKeyLayoutData`
  → `UCKeyTranslate(…, kUCKeyActionDisplay, 0, LMGetKbdType(), kUCKeyTranslateNoDeadKeysBit, …)`,
  uppercased. Use the **ASCII-capable** source, not the current one (Russian/Greek/IME would give
  Cyrillic or no layout data) — matches KeyboardShortcuts and MASShortcut. TIS must run on main.
- Translate only single-character keys (letters, top-row digits, ANSI punctuation); never F-keys,
  arrows, Space/Return/Tab/Delete/Escape/Home/End/Page keys or keypad keys.
- Fallback to US name on nil layout, non-zero status, empty, whitespace or control characters.
- Refresh: footer already rebuilt per show; recorder observes
  `kTISNotifySelectedKeyboardInputSourceChanged` on `DistributedNotificationCenter` (main queue).
- Tests: inject fake translator (German Y/Z swap); existing tests pin `{ _ in nil }`; one live check
  on L (same key on US/QWERTZ/AZERTY → deterministic on CI).
- Out of scope, new backlog candidates: `systemKeyCodes` refusals are positional (QWERTZ Command-Z
  not refused, Command-Y is); "Command-Comma" text on AZERTY; ISO `<` key (`kVK_ISO_Section`)
  rejected as unsupported.
- Sources: sindresorhus/KeyboardShortcuts `Shortcut.swift`; shpakovski/MASShortcut `MASShortcut.m`;
  Clipy/Sauce; GTK issue 851.

## R2 — Feedback + Leave a Tip (AppCitizenshipKit)

- `Xpycode/AppCitizenshipKit` and `Xpycode/FeedbackKit` are **private** repos; CI has no token →
  a `url:` SPM dependency would not resolve. **Vendor in-repo** like CountClockWise
  (`CountClockWise/Vendor/{AppCitizenshipKit,FeedbackKit,README.md}`; byte-identical to ACK
  `a6c06af`, FK `8a240f1`; trimmed manifests, ACK → `.package(path: "../FeedbackKit")`).
- Tools 5.9, macOS 14; own module (Swift 5 mode). No Info.plist keys, no entitlements
  (non-sandboxed). ACK does **not** re-export FeedbackKit → link both products.
- `CitizenshipCommands` is useless for an LSUIElement app → AppKit pattern from CountClockWise
  `Sources/Clock/ClockSupport.swift`: `FeedbackView(config:onClose:)` hosted in an NSWindow
  (460×540, not released when closed, delegate clears ref, `NSApp.activate`); `leaveTip()` opens
  `config.donateURL` (`https://apps.lucesumbrarum.com/donate.html?app=<slug>`), NSAlert on failure.
- Naming (cookbook 104, decisions.md:565): "Send Feedback…" (ellipsis), "Leave a Tip" (no
  ellipsis), separator before the group. `33_app-minimums.md` wording is stale.
- Server (user-operated): one entry in
  `3-Websites/App-Websites/APPS/apps.lucesumbrarum.com/public/apps.json` —
  `{"slug":"llm-usagestatus","name":"LLM Usage Status","category":"DeveloperApplication","portalPage":false,"titleExample":"e.g. 'Claude section shows stale usage'"}`;
  `DRY_RUN=1 ./deploy.sh` then `./deploy.sh`; commit to `Xpycode/App-Websites`. Until then the
  server rejects submissions ("Please choose an app from the list").
- Privacy: no `logProvider` (no usage data or credentials attached); FeedbackKit has a public-listing
  consent. External tip link in a Developer ID app is unrestricted (App Store rules don't apply).

## R3 — In-app Help (HelpMenu)

- Vendor **`CountClockWise/Vendor/HelpMenu`** (2026-09-22; upstream `1-macOS/appHELP/01_Project`
  plus the `DefaultImageProvider.default` fix; MarkdownUI pinned `exact: "2.4.1"`). Older forks
  (Conjoyn, CameraTranscoder, TimeCodeEditor, Transcoder) lack search highlighting and
  `showHelp(content:selectingTopic:)`.
- One NSWindow + SwiftUI: grouped sidebar, search, MarkdownUI, `help-manifest.json` + `.md` topics,
  fallback page for missing topics. Menu helpers assume a main menu → call
  `HelpWindowController.showHelp(content:)` directly (as CountClockWise does).
- Place at `01_Project/HelpMenu/`; `project.yml` `packages: HelpMenu: {path: HelpMenu}`.
  MarkdownUI is fetched from public GitHub (CI OK). Content in `01_Project/Resources/Help/`
  (flat in bundle → unique names). Load via `HelpContent(manifest:in: .main)` in do/catch with a
  "Help unavailable" fallback — no `try?` (project rule; Directions snippet uses `try?`).
- Required adaptations (also open in `appHELP/docs/TASKS.md`): `NSApp.activate()` instead of
  deprecated `activate(ignoringOtherApps:)`; dark appearance; Esc / Command-W close (reuse the
  `SettingsWindow` subclass pattern, `SettingsWindowController.swift:9-27`). Optional frame autosave.
- Topic outline: Getting Started · Reading the Panel · Authoritative vs Estimated · Codex ·
  Claude Code (sign-in states; the app never refreshes the token) · Mistral Vibe · Settings and
  Shortcuts · Troubleshooting · Privacy and Data Sources (incl. that feedback is the only network
  send).
- Third-party notices needed for MarkdownUI, NetworkImage, cmark (CountClockWise ships them in
  `Resources/Licenses`). Apple Help Books not worth it.

## R4 — 0.2.0 release

- Pipeline: `scripts/notarize-release.sh VERSION` → `release.sh` (xcodegen, universal Release
  `xcodebuild build` into `dist/<v>/DerivedData`, version check, refuses existing `dist/<v>`) →
  `codesign --options runtime --timestamp` with Developer ID (team FDMSRXXN73) → zip (ditto) →
  `notarytool --wait` with API key in `99-AUTH` → require Accepted → staple + validate .app →
  re-zip → `codesign --verify --strict`, `spctl -a -vvv -t exec` → `SHA256SUMS.txt`. Zip, no DMG.
- No git tag or GitHub Release exists; repo `Xpycode/LLM-UsageStatus` is **private**.
- Changes: `MARKETING_VERSION` 0.2.0, `CURRENT_PROJECT_VERSION` **200** (monotonic for a later
  Sparkle `sparkle:version`; 100 is already used by two different binaries); CHANGELOG `[0.2.0]`;
  README "Download from Releases" wording vs private repo. No new entitlements/Info.plist keys for
  `SMAppService.mainApp`.
- Script hardening: refuse a dirty tree, record the commit SHA, optional tag `v0.2.0`.
- Risks: the `/Applications` copy is the ad-hoc Debug build with a registered login item → re-toggle
  (or check `sfltool dumpbtm`) after replacing with the Developer ID build; Sequoia removed the
  Control-click Gatekeeper bypass; staple the .app, not the zip; extract with Finder/ditto.
