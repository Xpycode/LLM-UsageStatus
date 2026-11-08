#!/bin/zsh
set -euo pipefail
root="${0:A:h:h}"
project="$root/01_Project"
version="${1:?Usage: scripts/release.sh VERSION}"
[[ "$version" =~ '^[0-9]+[.][0-9]+[.][0-9]+$' ]] || { print -u2 'Expected a numeric major.minor.patch version.'; exit 1; }
# A release must be reproducible from a commit: refuse uncommitted or untracked changes.
dirty="$(git -C "$root" status --porcelain --untracked-files=normal)"
[[ -z "$dirty" ]] || { print -u2 "Working tree is not clean; commit or stash first:"; print -u2 -- "$dirty"; exit 1; }
commit="$(git -C "$root" rev-parse HEAD)"
output="$root/dist/$version"
[[ ! -e "$output" ]] || { print -u2 "Output already exists; preserving it: $output"; exit 1; }
cd "$project"
xcodegen generate
# The tracked project file must already match project.yml, or the build would not be the commit.
dirty="$(git -C "$root" status --porcelain --untracked-files=normal)"
[[ -z "$dirty" ]] || { print -u2 "xcodegen changed tracked files; regenerate and commit first:"; print -u2 -- "$dirty"; exit 1; }
mkdir -p "$output"
xcodebuild -project LLM-UsageStatus.xcodeproj -scheme LLM-UsageStatus -configuration Release -destination 'platform=macOS' -derivedDataPath "$output/DerivedData" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
app="$output/DerivedData/Build/Products/Release/LLM-UsageStatus.app"
actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
[[ "$actual_version" == "$version" ]] || { print -u2 "Version mismatch: requested $version, built $actual_version"; exit 1; }
print -- "$commit" > "$output/SOURCE_COMMIT.txt"
# Retain the exact artifact for signing, verification and user-operated smoke testing.
ditto "$app" "$output/LLM-UsageStatus.app"
ditto -c -k --keepParent "$output/LLM-UsageStatus.app" "$output/LLM-UsageStatus-$version.zip"
print "Created $output/LLM-UsageStatus-$version.zip (not yet notarized)"
