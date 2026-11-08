# Vendored shared packages

Copied on 2026-11-08 from the user's shared packages. Sources are unchanged; package manifests are trimmed.

- AppCitizenshipKit: origin `Xpycode/AppCitizenshipKit` (private), local `zPackages/AppCitizenshipKit`, revision `a6c06af92e2d813429e5aa878e858018b8af27eb`.
- FeedbackKit: origin `Xpycode/FeedbackKit` (private), local `zPackages/FeedbackKit`, revision `8a240f1da8ce2281bb8522fa78d5273955387553`.

## Why vendored

Both repositories are private, and GitHub CI has no token to resolve them. Path packages outside this repository are also unreachable from CI, so the sources live inside it. The same approach is used by CountClockWise.

## Local modifications

Only the manifests differ from upstream (identical to CountClockWise's vendored manifests):

- Test targets removed (the Tests folders are not copied).
- Descriptive header comments removed.
- AppCitizenshipKit depends on FeedbackKit via `.package(path: "../FeedbackKit")` instead of the GitHub URL.

Sources are byte-identical to the revisions above. Both packages require macOS 14 (swift-tools-version 5.9); the app targets macOS 15.

## Refresh procedure

1. Update the canonical packages in `zPackages` and note the new HEAD SHAs.
2. Replace each `Sources/` folder here with the canonical one (`rm -rf` then `cp -R`); keep the trimmed `Package.swift` files, re-trimming if upstream changed targets or dependencies.
3. Verify with `diff -r <zPackages>/<Pkg>/Sources Vendor/<Pkg>/Sources`.
4. Run `swift build` in `AppCitizenshipKit`, then delete `.build`, `.swiftpm` and `Package.resolved`.
5. Update the SHAs and date above. Do not edit vendored sources here; change them in the owning package.
