---
dependencies: []
status: backlog
---

# Distribution Pipeline (Sign, Notarize, DMG)

## Objective

Add a release pipeline that produces a signed, notarized `.dmg` for QuickIcons, modeled on the pipeline already in use in `~/src/natikgadzhi/scrapes` for KindleExporter. Output should be a single `make release-quickicons-dmg` (or equivalent) invocation that an operator can run locally or from CI.

## Reference Implementation

The Scrapes repo has a working version of this pipeline. Steal and adapt:

- `~/src/natikgadzhi/scrapes/Makefile` — `release-kindleexporter-dmg` target
- `~/src/natikgadzhi/scrapes/scripts/build-kindleexporter-dmg.sh` — full pipeline script (archive → sign → DMG → notarize → staple)
- `~/src/natikgadzhi/scrapes/docs/kindle-exporter-release.md` — operator-facing docs for the release flow

The Scrapes script already handles: optional p12 certificate import into a temp keychain, Developer ID auto-detection, `xcodebuild archive` with `CODE_SIGNING_ALLOWED=NO`, `codesign --options runtime --timestamp`, DMG creation via `hdiutil`, notarization via `notarytool` (API key or keychain profile), and stapling. Reuse the structure; rename project/scheme/app values for QuickIcons.

## Acceptance Criteria

- [ ] `Makefile` target (e.g. `release-quickicons-dmg`) orchestrates the full pipeline
- [ ] `scripts/build-quickicons-dmg.sh` handles archive, sign, DMG, notarize, staple — adapted from the Scrapes version
- [ ] Works with either `NOTARY_KEYCHAIN_PROFILE` or `APPLE_NOTARY_API_KEY_*` env vars
- [ ] Works with either a pre-imported Developer ID identity (`APP_SIGN_IDENTITY` or `security find-identity` auto-detect) or a base64 p12 blob in `APPLE_DEVELOPER_ID_P12_BASE64`
- [ ] Produces `build/release/QuickIcons <version>.dmg` with the app signed, notarized, and stapled
- [ ] `spctl -a -vvv --type open <dmg>` passes Gatekeeper
- [ ] `docs/release.md` (or similar) documents the required env vars and operator steps
- [ ] Build artifacts (`build/`) are gitignored

## Notes

- Default project/scheme values: `PROJECT_PATH=QuickIcons.xcodeproj`, `SCHEME=QuickIcons`, `APP_NAME=QuickIcons.app`.
- Keep the script idempotent — rerunning should not leave stale keychains or archives behind (the Scrapes version already does this via `trap cleanup EXIT`).
- Out of scope for this task: GitHub Actions release workflow, Sparkle auto-update, App Store submission. File follow-up tasks if desired.
