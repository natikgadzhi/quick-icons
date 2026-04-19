# QuickIcons Release

This repo includes a release script for building a signed `.app` and a notarized `.dmg` for QuickIcons.

## One-Shot Release Command

```bash
NOTARY_KEYCHAIN_PROFILE="quickicons-notary" \
make release-quickicons-dmg
```

## Local Requirements

- `Developer ID Application` certificate installed in the login keychain
- Notarization credentials stored with `xcrun notarytool store-credentials`
- Xcode command line tools available

Store notarization credentials once:

```bash
xcrun notarytool store-credentials "quickicons-notary" \
  --apple-id you@example.com \
  --team-id YOURTEAMID \
  --password "@keychain:AC_PASSWORD"
```

## Required Environment Variables

At least one signing credential source and one notarization credential source are required.

### Signing

Either set `APP_SIGN_IDENTITY` explicitly or let the script auto-detect a `Developer ID Application`
identity from the keychain. For CI, supply a base64-encoded `.p12`:

| Variable | Description |
|---|---|
| `APP_SIGN_IDENTITY` | Full identity string, e.g. `Developer ID Application: Your Name (TEAMID)`. Auto-detected if unset. |
| `APPLE_DEVELOPER_ID_P12_BASE64` | Base64-encoded `.p12` containing the Developer ID certificate and private key. |
| `APPLE_DEVELOPER_ID_P12_PASSWORD` | Password for the `.p12`. Required when `APPLE_DEVELOPER_ID_P12_BASE64` is set. |

### Notarization

Supply either a keychain profile (local) or API key (CI):

| Variable | Description |
|---|---|
| `NOTARY_KEYCHAIN_PROFILE` | Keychain profile name stored via `notarytool store-credentials`. |
| `APPLE_NOTARY_API_KEY_BASE64` | Base64-encoded App Store Connect API key `.p8`. |
| `APPLE_NOTARY_API_KEY_ID` | API key ID. Required with `APPLE_NOTARY_API_KEY_BASE64`. |
| `APPLE_NOTARY_ISSUER_ID` | Issuer UUID. Required with `APPLE_NOTARY_API_KEY_BASE64`. |

### Optional Overrides

| Variable | Default |
|---|---|
| `PROJECT_PATH` | `QuickIcons.xcodeproj` |
| `SCHEME` | `QuickIcons` |
| `CONFIGURATION` | `Release` |
| `ARCHIVE_PATH` | `build/QuickIcons.xcarchive` |
| `APP_NAME` | `QuickIcons.app` |
| `DMG_BASENAME` | `QuickIcons` |
| `DMG_VERSION` | Read from `CFBundleShortVersionString` |
| `DMG_NAME` | `QuickIcons <version>.dmg` |

## What The Script Does

1. Archives `QuickIcons` for macOS with `CODE_SIGNING_ALLOWED=NO`
2. Copies the archived app to `build/export/`
3. Signs the app with `Developer ID Application` (`--options runtime --timestamp`)
4. Verifies the app signature with `codesign --verify --deep --strict`
5. Creates a drag-to-Applications DMG via `hdiutil`
6. Notarizes the DMG via `xcrun notarytool submit --wait`
7. Staples the ticket and validates with `xcrun stapler validate`

Artifacts end up in:

- `build/export/QuickIcons.app`
- `build/release/QuickIcons <version>.dmg`

The archive step uses `CODE_SIGNING_ALLOWED=NO` so Xcode automatic signing is bypassed. The
Developer ID signature is applied separately in step 3, keeping the output deterministic.

The script creates a temporary keychain when a `.p12` is supplied and deletes it on exit via
`trap cleanup EXIT`, so rerunning is safe.

## CI Usage

For GitHub Actions, supply the signing and notarization material as secrets:

```yaml
- name: Build signed app and notarized DMG
  env:
    APPLE_DEVELOPER_ID_P12_BASE64: ${{ secrets.APPLE_DEVELOPER_ID_P12_BASE64 }}
    APPLE_DEVELOPER_ID_P12_PASSWORD: ${{ secrets.APPLE_DEVELOPER_ID_P12_PASSWORD }}
    APPLE_NOTARY_API_KEY_BASE64: ${{ secrets.APPLE_NOTARY_API_KEY_BASE64 }}
    APPLE_NOTARY_API_KEY_ID: ${{ secrets.APPLE_NOTARY_API_KEY_ID }}
    APPLE_NOTARY_ISSUER_ID: ${{ secrets.APPLE_NOTARY_ISSUER_ID }}
  run: make release-quickicons-dmg
```

## Manual Verification

```bash
codesign --verify --deep --strict --verbose=2 "build/export/QuickIcons.app"
spctl -a -vvv "build/export/QuickIcons.app"
xcrun stapler validate "build/release/QuickIcons 1.0.dmg"
spctl -a -vvv --type open "build/release/QuickIcons 1.0.dmg"
```
