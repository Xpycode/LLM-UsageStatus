#!/bin/zsh
# Wrap the notarized dist/<version>/LLM-UsageStatus.app in a drag-to-Applications DMG,
# then sign, notarize and staple the DMG itself (a new container Apple has never seen).
# Run after scripts/notarize-release.sh <version>.
set -euo pipefail
version="${1:?Usage: scripts/package-dmg.sh VERSION}"
[[ "$version" =~ '^[0-9]+[.][0-9]+[.][0-9]+$' ]] || { print -u2 'Expected a numeric major.minor.patch version.'; exit 1; }
root="${0:A:h:h}"
out="$root/dist/$version"
app="$out/LLM-UsageStatus.app"
dmg="$out/LLM-UsageStatus-${version}.dmg"
auth_dir="${AUTH_DIR:-/Users/sim/ProgrammingProjects/99-AUTH}"
identity="${SIGN_ID:-D3002F5085B4512CAE0CC1A6DF30FAF717D83B62}"
key="${NOTARY_KEY:-${auth_dir}/AuthKey_6HTCUZ9L7L.p8}"
issuer="${NOTARY_ISSUER:-$(grep -oiE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "${auth_dir}/IssuerID.rtf" | head -1)}"
key_id="$(basename "$key" .p8 | sed 's/^AuthKey_//')"
[[ -f "$key" && -n "$issuer" ]] || { print -u2 'Missing notarization API-key credentials.'; exit 1; }
# Only package an app that is already stapled and accepted by Gatekeeper.
xcrun stapler validate "$app"
spctl -a -t exec "$app"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/LLM-UsageStatus.app"
ln -s /Applications "$staging/Applications"
rm -f "$dmg"
hdiutil create -volname "LLM Usage Status ${version}" -srcfolder "$staging" -ov -format UDZO "$dmg"
codesign --force --timestamp --sign "$identity" "$dmg"
xcrun notarytool submit "$dmg" --key "$key" --key-id "$key_id" --issuer "$issuer" --wait --output-format json > "$out/notarization-dmg.json"
/usr/bin/plutil -extract status raw -o - "$out/notarization-dmg.json" | /usr/bin/grep -qx Accepted
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl -a -vvv -t open --context context:primary-signature "$dmg"
(cd "$out" && shasum -a 256 "LLM-UsageStatus-${version}.zip" "LLM-UsageStatus-${version}.dmg" > SHA256SUMS.txt)
print "Notarized DMG: $dmg"
