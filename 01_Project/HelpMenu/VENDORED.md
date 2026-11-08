# Vendored: HelpMenu

- Origin: /Users/sim/ProgrammingProjects/1-macOS/CountClockWise/Vendor/HelpMenu (copy dated 2026-09-22, CountClockWise commit 523d89f)
- Upstream: /Users/sim/ProgrammingProjects/1-macOS/appHELP/01_Project (appHELP has no git repo on this Mac, so no commit available)
- Vendored inside the repo because GitHub CI cannot resolve path packages outside it.

## Local modifications (all in `Sources/HelpMenu/Window/HelpWindowController.swift`)

1. `NSApp.activate(ignoringOtherApps: true)` replaced by `NSApp.activate()` (package platform already `.macOS(.v14)`).
2. Help window forced dark: `window.appearance = NSAppearance(named: .darkAqua)`.
3. Private `HelpWindow` NSWindow subclass: Escape (`cancelOperation`) and Command-W close the window, since the dockless host has no Close menu item.
4. Frame autosave name `LLMUsageStatusHelpWindow`.

The same fixes (1-3, plus a host-specific autosave name) should be applied upstream to appHELP. Do not edit appHELP from this project.

## Refresh procedure

1. `rsync -a --exclude .build --exclude .swiftpm --exclude Package.resolved --exclude xcuserdata --exclude .DS_Store <newest copy>/ 01_Project/HelpMenu/`
2. Re-apply modifications 1-4 above (or confirm upstream already has them).
3. Keep `swift-markdown-ui` pinned `exact: "2.4.1"`.
4. `swift build` in this directory, then delete `.build`, `.swiftpm`, `Package.resolved`.
