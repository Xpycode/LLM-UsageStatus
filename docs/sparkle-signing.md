# Sparkle update signing

LLM-UsageStatus checks `appcast.xml` (served from raw GitHub on `main`) and verifies each update
DMG with an EdDSA signature. This file records where the key lives and how a release item is made.
It contains no private material.

## Public key

`SUPublicEDKey` in the app's Info.plist:

```
8giDlCjMm8dDBkP3qu2C4hv80xmLg//AACmoHRnn624=
```

## Private key

- Login Keychain item: service `https://sparkle-project.org`, account `LLM-UsageStatus`, label
  "Private key for signing Sparkle updates".
- One-time export (outside the repo, never committed): `~/ProgrammingProjects/99-AUTH/LLM-UsageStatus-sparkle-eddsa.key`.

### Import on another Mac

Run from the resolved Sparkle package's bin folder (after a release build it is
`dist/VERSION/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/`; any build's
DerivedData `SourcePackages/artifacts/sparkle/Sparkle/bin/` works too):

```bash
./generate_keys --account LLM-UsageStatus -f ~/ProgrammingProjects/99-AUTH/LLM-UsageStatus-sparkle-eddsa.key
./generate_keys --account LLM-UsageStatus -p    # prints the public key; must equal the one above
```

Never run `generate_keys` without `-f` for this account on a Mac that lacks the key: it would mint
a new, different key.

## Signing and publishing a release

1. Build, sign, notarize and package the DMG (`scripts/notarize-release.sh VERSION`, then
   `scripts/package-dmg.sh VERSION`). `scripts/sign-app.sh` signs Sparkle's nested code
   inside-out; it is called by `notarize-release.sh` (`SIGN_ONLY=1` stops after signing and verification).
2. Publish the DMG on GitHub Releases as tag `vVERSION`, asset `LLM-UsageStatus-VERSION.dmg`.
   The appcast must never point at a DMG that is not live.
3. Run `scripts/make-appcast-item.sh VERSION`. It signs the DMG with `sign_update --account
   LLM-UsageStatus`, HEAD-checks the asset URL, and inserts the item newest first, or replaces the
   existing item for that version. Optional release notes come from `dist/VERSION/release-notes.html`.
4. Review the printed diff of `appcast.xml`, then commit and push to `main`.
5. Raw GitHub caches for about five minutes; a new item may take that long to reach clients.

Dry-run switches (never for a real release): `SKIP_SIGN=1` writes a placeholder signature (and
refuses to edit the repository's own `appcast.xml`, so it needs `APPCAST` or `ROOT`),
`--allow-missing` skips the asset-live refusal, `APPCAST=file` edits another file, `ROOT=dir`
relocates `dist/` and the default appcast, `BUILD=n` supplies the build number when the built app
is absent.

## If the key is lost

Installed apps trust only this public key, so an update signed by any other key is rejected.
Do not silently rotate. If the Keychain item and the export are both gone, existing users need one
manual download of a build carrying a new `SUPublicEDKey`, after which updates resume (the same
hop the sibling app syncthingStatus went through). Record the decision in `docs/decisions.md`
before generating a replacement.
