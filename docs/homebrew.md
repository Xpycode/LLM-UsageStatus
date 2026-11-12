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

`brew uninstall` keeps settings; `brew uninstall --zap` also removes the app's preferences and its
last-seen usage cache. The app stores no credentials, so nothing sensitive is left behind either way.

## Release maintenance

For each public release, keep GitHub, Homebrew and the website on the same version:

1. **Build and notarize:** `scripts/notarize-release.sh X.Y.Z`, then `scripts/package-dmg.sh X.Y.Z`
   (clean tree; both need Apple's Accepted verdict).
2. **GitHub Release:** tag `vX.Y.Z` on the release commit and attach
   `dist/X.Y.Z/LLM-UsageStatus-X.Y.Z.dmg` with the CHANGELOG entry as notes. Check that the
   asset URL downloads.
3. **Cask:** set `version` and `sha256` (of the published DMG, `shasum -a 256`) in
   `Casks/llm-usagestatus.rb`. Run `brew style Casks/llm-usagestatus.rb` and
   `brew audit --cask --online xpycode/llm-usagestatus/llm-usagestatus`, then commit and push.
4. **Website:** in App-Websites, upload the DMG to `downloads/llm-usagestatus.dmg` and bump the
   page and roster version and release date (see the 0.2.2 E3 record in
   `docs/plans/2026-11-10-v0.2.2/IMPLEMENTATION_PLAN.md`).
5. **Verify live:** GitHub asset, `brew fetch --cask xpycode/llm-usagestatus/llm-usagestatus`,
   and the website's `dl.php` all serve the same checksum.

Once Sparkle ships, `appcast.xml` joins step 3 and the cask gains `auto_updates true`.
