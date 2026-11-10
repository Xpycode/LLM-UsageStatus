#!/bin/zsh
# Offscreen website renders of the panel with SAMPLE data (no window, no app launch, no
# provider/credential access). The view copy drops `.progressViewStyle(.linear)` because
# ImageRenderer cannot draw the AppKit bar; main.swift supplies a SwiftUI BarStyle instead.
# Also draws the draft icon (icon-1024.png). Output: PNGs in $1 (default: current folder).
set -euo pipefail
here="${0:A:h}"; src="$here/../../01_Project/Sources"; out="${1:-$PWD}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
grep -v 'progressViewStyle(.linear)' "$src/Features/UsageStatus/Views/UsageStatusView.swift" > "$tmp/UsageStatusView.render.swift"
swiftc -O -o "$tmp/render" "$src/Shared/Models/ProviderModels.swift" "$src/Features/UsageStatus/UsageStore.swift" \
  "$src/Features/UsageStatus/UsagePreferences.swift" "$src/Features/UsageStatus/SectionStateCache.swift" \
  "$tmp/UsageStatusView.render.swift" "$here/keys.swift" "$here/main.swift"
"$tmp/render" "$out"
