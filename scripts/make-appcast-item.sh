#!/bin/zsh
# Insert or replace the appcast <item> for one release.
# Usage: scripts/make-appcast-item.sh VERSION [--allow-missing]
# Env: BUILD=n        build number when the built app is not present
#      SKIP_SIGN=1    placeholder signature (dry runs only; the item is NOT installable)
#      APPCAST=path   appcast file to edit (default: <root>/appcast.xml)
#      ROOT=path      directory holding dist/ and the default appcast (default: the repo)
#      SIGN_UPDATE=path  Sparkle's sign_update, for a release whose own build did not embed
#                        Sparkle (default: the release's DerivedData package artifacts)
set -euo pipefail
version="${1:?Usage: scripts/make-appcast-item.sh VERSION [--allow-missing]}"
allow_missing=0
[[ "${2:-}" == "--allow-missing" ]] && allow_missing=1
[[ $# -le 2 && ( $# -lt 2 || $allow_missing == 1 ) ]] || { print -u2 'Usage: scripts/make-appcast-item.sh VERSION [--allow-missing]'; exit 1; }
[[ "$version" =~ '^[0-9]+[.][0-9]+[.][0-9]+$' ]] || { print -u2 'Expected a numeric major.minor.patch version.'; exit 1; }
root="${ROOT:-${0:A:h:h}}"
out="$root/dist/$version"
dmg="$out/LLM-UsageStatus-$version.dmg"
appcast="${APPCAST:-$root/appcast.xml}"
repo="Xpycode/LLM-UsageStatus"
url="https://github.com/$repo/releases/download/v$version/LLM-UsageStatus-$version.dmg"
[[ -f "$dmg" ]] || { print -u2 "Missing DMG: $dmg"; exit 1; }
[[ -f "$appcast" ]] || { print -u2 "Missing appcast: $appcast"; exit 1; }

plist="$out/LLM-UsageStatus.app/Contents/Info.plist"
if [[ -n "${BUILD:-}" ]]; then
  build="$BUILD"
elif [[ -f "$plist" ]]; then
  build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")"
else
  print -u2 "No build number: $plist is missing and BUILD is not set."; exit 1
fi
[[ "$build" =~ '^[0-9]+$' ]] || { print -u2 "Build number must be an integer, got: $build"; exit 1; }

if [[ "${SKIP_SIGN:-0}" == 1 ]]; then
  # The repository's appcast.xml is the production feed; a placeholder item must go elsewhere.
  published="${0:A:h:h}/appcast.xml"
  [[ "${appcast:A}" != "${published:A}" ]] || {
    print -u2 'SKIP_SIGN=1 refuses to edit the published appcast.xml; set APPCAST (or ROOT) to a scratch copy.'; exit 1; }
  print -u2 '*** SKIP_SIGN=1: using a PLACEHOLDER edSignature. This item is for dry runs only and must never be published. ***'
  signature='SKIP_SIGN_PLACEHOLDER_NOT_A_REAL_SIGNATURE'
else
  sign_update="${SIGN_UPDATE:-$out/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update}"
  [[ -x "$sign_update" ]] || { print -u2 "Missing $sign_update (run scripts/release.sh first, or set SIGN_UPDATE)."; exit 1; }
  # Output looks like: sparkle:edSignature="..." length="..."; only the signature is kept.
  signed="$("$sign_update" --account LLM-UsageStatus "$dmg")"
  signature="$(print -r -- "$signed" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
  [[ -n "$signature" ]] || { print -u2 'sign_update did not return an edSignature.'; exit 1; }
fi
length="$(stat -f%z "$dmg")"

code="$(curl -sIL -o /dev/null -w '%{http_code}' --max-time 30 "$url" || true)"
if [[ "$code" != 200 ]]; then
  if (( allow_missing )); then
    print -u2 "Warning: $url answered HTTP ${code:-none} (continuing: --allow-missing)."
  else
    print -u2 "Release asset not live (HTTP ${code:-none}): $url"
    print -u2 'Publish the DMG on GitHub Releases first, or pass --allow-missing.'
    exit 1
  fi
fi

pubdate="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"
notes_file="$out/release-notes.html"
if [[ -f "$notes_file" ]]; then
  notes="$(<"$notes_file")"
else
  notes="<p>LLM Usage Status $version. See the <a href=\"https://github.com/$repo/blob/main/CHANGELOG.md\">changelog</a> for details.</p>"
fi
# A literal ]]> would end the CDATA section early.
notes="${notes//\]\]>/]]]]><![CDATA[>}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/item.xml" <<ITEM
    <item>
      <title>Version $version</title>
      <pubDate>$pubdate</pubDate>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <description><![CDATA[$notes]]></description>
      <sparkle:fullReleaseNotesLink>https://github.com/$repo/releases/tag/v$version</sparkle:fullReleaseNotesLink>
      <enclosure url="$url" length="$length" type="application/octet-stream" sparkle:edSignature="$signature"/>
    </item>
ITEM

cp "$appcast" "$tmp/before.xml"
# Text-level edit so every other item stays byte-for-byte. Drops any item for this version, then
# inserts before the first item with a lower sparkle:version, else before </channel>.
perl -0777 -e '
  my ($in, $itemfile, $ver, $build) = @ARGV;
  open my $f, "<", $in or die; local $/; my $x = <$f>; close $f;
  open my $g, "<", $itemfile or die; my $item = <$g>; close $g;
  my $re = qr{^[ \t]*<item>.*?</item>[ \t]*\n?}ms;
  $x =~ s{($re)}{ my $it = $1; $it =~ m{<sparkle:shortVersionString>\Q$ver\E</sparkle:shortVersionString>} ? "" : $it }gse;
  my $done = 0;
  $x =~ s{($re)}{
    my $it = $1;
    if (!$done && $it =~ m{<sparkle:version>\s*(\d+)\s*</sparkle:version>} && $1 < $build) { $done = 1; $item . $it } else { $it }
  }gse;
  unless ($done) {
    $x =~ s{^([ \t]*</channel>)}{$item$1}m or die "no </channel> found\n";
  }
  print $x;
' "$tmp/before.xml" "$tmp/item.xml" "$version" "$build" > "$tmp/after.xml"
xmllint --noout "$tmp/after.xml"
cp "$tmp/after.xml" "$appcast"
print "Updated $appcast (version $version, build $build, $length bytes):"
diff -u "$tmp/before.xml" "$appcast" || true
