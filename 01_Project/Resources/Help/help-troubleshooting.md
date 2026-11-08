# Troubleshooting

## The shortcut does nothing

Another app may already use it, or macOS could not enable it. A warning icon appears in the menu bar. Click it to see:

- A message such as "… is already in use." or "macOS could not enable …".
- **Show HUD** — open the panel without the shortcut.
- **Retry Shortcut** — try to register the shortcut again.
- **Settings…** — choose a different shortcut.
- **Quit LLM Usage Status**

Free the shortcut in the other app and choose **Retry Shortcut**, or pick a new one in Settings. The icon disappears once the shortcut works.

## A section says "Not detected on this Mac."

The provider's command-line tool or its data files are missing. Install the tool and use it once, then reopen the panel.

## "Update failed · showing previous values"

The last refresh failed, and the section is showing the values from the last successful one, with the time they were fetched. Close and reopen the panel to retry. The Codex and Claude usage services are undocumented and may change or be briefly unavailable.

## Claude Code shows "Sign-in expired"

Run Claude Code once, then reopen the panel. See Claude Code.

## Something looks stuck

Right-click the panel and choose **Restart LLM Usage Status**. It starts a fresh copy and quits the old one.

## Launch at login is disabled

Move the app to your Applications folder. See Settings and Shortcuts.
