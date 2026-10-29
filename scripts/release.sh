#!/bin/zsh
set -euo pipefail
root="${0:A:h:h}"
project="$root/01_Project"
version="${1:?Usage: scripts/release.sh VERSION}"
[[ "$version" =~ '^[0-9]+[.][0-9]+[.][0-9]+$' ]] || { print -u2 'Expected a numeric major.minor.patch version.'; exit 1; }
output="$root/dist/$version"
[[ ! -e "$output" ]] || { print -u2 "Output already exists; preserving it: $output"; exit 1; }
mkdir -p "$output"
cd "$project"
xcodegen generate
xcodebuild -project LLM-UsageStatus.xcodeproj -scheme LLM-UsageStatus -configuration Release -destination 'platform=macOS' -derivedDataPath "$output/DerivedData" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
app="$output/DerivedData/Build/Products/Release/LLM-UsageStatus.app"
actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
[[ "$actual_version" == "$version" ]] || { print -u2 "Version mismatch: requested $version, built $actual_version"; exit 1; }
# Retain the exact artifact for signing, verification and user-operated smoke testing.
ditto "$app" "$output/LLM-UsageStatus.app"
ditto -c -k --keepParent "$output/LLM-UsageStatus.app" "$output/LLM-UsageStatus-$version.zip"
print "Created $output/LLM-UsageStatus-$version.zip (not yet notarized)"
