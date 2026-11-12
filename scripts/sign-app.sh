#!/bin/zsh
# Inside-out Developer ID signing for an app that embeds frameworks (Sparkle).
# Usage: scripts/sign-app.sh <App.app>      (SIGN_ID selects the identity; "-" means ad-hoc, local tests only)
set -euo pipefail
app="${1:?Usage: scripts/sign-app.sh <App.app>}"
[[ "$app" == *.app && -d "$app" ]] || { print -u2 "Not an existing .app directory: $app"; exit 1; }
app="${app:A}"
root="${0:A:h:h}"
identity="${SIGN_ID:-D3002F5085B4512CAE0CC1A6DF30FAF717D83B62}"
# Outer-app entitlements come from the tracked file rather than --preserve-metadata=entitlements:
# the result is identical on every machine and Xcode version, and cannot inherit get-task-allow
# from a build configuration.
entitlements="$root/01_Project/Resources/LLM-UsageStatus.entitlements"
[[ -f "$entitlements" ]] || { print -u2 "Missing entitlements file: $entitlements"; exit 1; }

# Ad-hoc signatures cannot carry a secure timestamp.
common=(--force --options runtime)
[[ "$identity" == "-" ]] || common+=(--timestamp)
common+=(--sign "$identity")

signed=()
sign() {
  print -- "Signing ${1#$app/}"
  codesign "${common[@]}" "${@:2}" "$1"
  signed+=("$1")
}

# Never --deep when signing: it applies one set of options to every nested item. Components are
# signed explicitly, children before parents, so each seal covers already-final contents.
setopt null_glob
for fw in "$app"/Contents/Frameworks/*.framework; do
  for ver in "$fw"/Versions/*(/); do
    [[ "${ver:t}" == Current ]] && continue
    # Downloader.xpc keeps its own entitlements (Sparkle's documented re-signing recipe).
    for xpc in "$ver"/XPCServices/*.xpc(/); do
      if [[ "${xpc:t}" == Downloader.xpc ]]; then
        sign "$xpc" --preserve-metadata=entitlements
      else
        sign "$xpc"
      fi
    done
    [[ -e "$ver/Autoupdate" ]] && sign "$ver/Autoupdate"
    [[ -d "$ver/Updater.app" ]] && sign "$ver/Updater.app"
  done
  sign "$fw"
done
sign "$app" --entitlements "$entitlements"
unsetopt null_glob

# --deep is for verification only.
codesign --verify --deep --strict --verbose=2 "$app"

# Every component must carry the outer app's team: an ad-hoc or foreign-team Autoupdate or
# Updater.app can pass the deep verify yet fail library validation when an update installs.
expected=""
if [[ "$identity" != "-" ]]; then
  expected="$(codesign -dv "$app" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
  [[ -n "$expected" && "$expected" != "not set" ]] || { print -u2 "The signed app has no TeamIdentifier."; exit 1; }
fi
mismatches=0
for item in "${signed[@]}"; do
  team="$(codesign -dv "$item" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
  print -- "TeamIdentifier ${team:-none}  ${item:t}"
  if [[ -n "$expected" && "$team" != "$expected" ]]; then
    print -u2 "Team mismatch: ${item:t} has ${team:-none}, expected $expected"
    mismatches=$(( mismatches + 1 ))
  fi
done
(( mismatches == 0 )) || { print -u2 "$mismatches component(s) not signed by team $expected."; exit 1; }
print "Signed and verified: $app"
