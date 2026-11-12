#!/bin/zsh
set -euo pipefail
version="${1:?Usage: scripts/notarize-release.sh VERSION}"
[[ "$version" =~ '^[0-9]+[.][0-9]+[.][0-9]+$' ]] || { print -u2 'Expected a numeric major.minor.patch version.'; exit 1; }
root="${0:A:h:h}"
# Fail before touching credentials; release.sh repeats this check and records the source commit.
[[ -z "$(git -C "$root" status --porcelain --untracked-files=normal)" ]] || { print -u2 'Working tree is not clean; commit or stash first.'; exit 1; }
auth_dir="${AUTH_DIR:-/Users/sim/ProgrammingProjects/99-AUTH}"
identity="${SIGN_ID:-D3002F5085B4512CAE0CC1A6DF30FAF717D83B62}"
key="${NOTARY_KEY:-${auth_dir}/AuthKey_6HTCUZ9L7L.p8}"
issuer="${NOTARY_ISSUER:-$(grep -oiE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "${auth_dir}/IssuerID.rtf" | head -1)}"
key_id="$(basename "$key" .p8 | sed 's/^AuthKey_//')"
[[ -f "$key" && -n "$issuer" ]] || { print -u2 'Missing notarization API-key credentials.'; exit 1; }
"$root/scripts/release.sh" "$version"
out="$root/dist/$version"
app="$out/LLM-UsageStatus.app"
archive="$out/LLM-UsageStatus-${version}.zip"
SIGN_ID="$identity" "$root/scripts/sign-app.sh" "$app"
if [[ "${SIGN_ONLY:-0}" == 1 ]]; then
  print "SIGN_ONLY=1: signed and verified $app; skipped notarization, stapling and zip upload."
  exit 0
fi
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
xcrun notarytool submit "$archive" --key "$key" --key-id "$key_id" --issuer "$issuer" --wait --output-format json > "$out/notarization.json"
# A completed submission is not necessarily accepted. Check Apple's actual verdict.
/usr/bin/plutil -extract status raw -o - "$out/notarization.json" | /usr/bin/grep -qx Accepted
xcrun stapler staple "$app"
xcrun stapler validate "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
codesign --verify --strict --verbose=2 "$app"
spctl -a -vvv -t exec "$app"
(cd "$out" && shasum -a 256 "LLM-UsageStatus-${version}.zip" > SHA256SUMS.txt)
print "Notarized release: $archive"
