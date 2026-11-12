# Homebrew distribution

This repository doubles as a custom Homebrew tap through `Casks/llm-usagestatus.rb`. The cask
installs the notarized DMG attached to the GitHub Release; there is no separate tap repository
and no separate Homebrew build. This is not a listing in Homebrew's official cask catalogue.

## Installation

```sh
brew tap xpycode/llm-usagestatus https://github.com/Xpycode/LLM-UsageStatus.git
brew install --cask xpycode/llm-usagestatus/llm-usagestatus
```

If Homebrew refuses to load the cask from an untrusted tap, trust it once and repeat the install:
`brew trust --cask xpycode/llm-usagestatus/llm-usagestatus`.

An existing manual installation in `/Applications` may need `--adopt` (quit the app first). Do not
use `--force` to overwrite an unknown installation.

## Updates and `brew upgrade`

From 0.3.0 the app updates itself through Sparkle, and the cask says so with `auto_updates true`.
`brew upgrade` compares the version of the installed app bundle with the cask's `version`: an app
that Sparkle has already moved to the cask's version or beyond is skipped, and an older one is
upgraded. `brew upgrade --greedy` (or `--greedy-auto-updates`) reinstalls Homebrew's copy anyway.
`brew outdated` lists the app only when its bundle is behind the cask. The cask's `livecheck` reads
the same `appcast.xml` (`strategy :sparkle`), so `brew livecheck` reports the newest feed item.

`brew uninstall` keeps settings; `brew uninstall --zap` also removes the app's preferences and its
last-seen usage cache. The app stores no credentials, so nothing sensitive is left behind either way.

## Release maintenance

For each public release, keep GitHub, Homebrew and the website on the same version:

1. **Build and notarize:** `scripts/notarize-release.sh X.Y.Z`, then `scripts/package-dmg.sh X.Y.Z`
   (clean tree; both need Apple's Accepted verdict).
2. **GitHub Release:** tag `vX.Y.Z` on the release commit and attach
   `dist/X.Y.Z/LLM-UsageStatus-X.Y.Z.dmg` with the CHANGELOG entry as notes. Check that the
   asset URL downloads.
3. **Appcast:** with the Release asset live, run `scripts/make-appcast-item.sh X.Y.Z` (it signs the
   DMG with the app's EdDSA key, refuses while the asset URL is not live, and inserts or replaces
   that version's `<item>`, newest first). Put the CHANGELOG entry as HTML in
   `dist/X.Y.Z/release-notes.html` first, or the item gets a generic note. Review the printed diff
   (build number, version, `length`, signature), commit and push; check that
   `curl -fsSL https://raw.githubusercontent.com/Xpycode/LLM-UsageStatus/main/appcast.xml` shows the
   item (raw GitHub caches for about five minutes). Details: `docs/sparkle-signing.md`.
4. **Cask:** set `version` and `sha256` (of the published DMG, `shasum -a 256`) in
   `Casks/llm-usagestatus.rb`; keep `auto_updates true` and the `livecheck` block. Run
   `brew style Casks/llm-usagestatus.rb` and
   `brew audit --cask --online xpycode/llm-usagestatus/llm-usagestatus`, then commit and push.
5. **Website:** in App-Websites, upload the DMG to `downloads/llm-usagestatus.dmg` and bump the
   page and roster version and release date (see the 0.2.2 E3 record in
   `docs/plans/2026-11-10-v0.2.2/IMPLEMENTATION_PLAN.md`).
6. **Verify live:** GitHub asset, `brew fetch --cask xpycode/llm-usagestatus/llm-usagestatus`,
   the website's `dl.php` and the appcast item's `length` all describe the same DMG.

Never publish an appcast item before its DMG is live: the feed on `main` is production, and every
installed copy reads it.
