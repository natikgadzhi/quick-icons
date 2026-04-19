#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-QuickIcons.xcodeproj}"
SCHEME="${SCHEME:-QuickIcons}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-build/QuickIcons.xcarchive}"
EXPORT_DIR="${EXPORT_DIR:-build/export}"
RELEASE_DIR="${RELEASE_DIR:-build/release}"
DMG_STAGING_DIR="${DMG_STAGING_DIR:-build/dmg}"
APP_NAME="${APP_NAME:-QuickIcons.app}"
DMG_BASENAME="${DMG_BASENAME:-${APP_NAME%.app}}"
DMG_VERSION="${DMG_VERSION:-}"
DMG_NAME="${DMG_NAME:-}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-}"

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/quickicons-release.XXXXXX")"
TEMP_KEYCHAIN_PATH="${TEMP_DIR}/release-signing.keychain-db"
TEMP_KEYCHAIN_PASSWORD="${TEMP_KEYCHAIN_PASSWORD:-$(uuidgen)}"
TEMP_NOTARY_KEY_PATH="${TEMP_DIR}/AuthKey.p8"
KEYCHAIN_CREATED=0

cleanup() {
  if [[ "${KEYCHAIN_CREATED}" == "1" && -f "${TEMP_KEYCHAIN_PATH}" ]]; then
    security delete-keychain "${TEMP_KEYCHAIN_PATH}" >/dev/null 2>&1 || true
  fi
  rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command xcodebuild
require_command codesign
require_command xcrun
require_command hdiutil
require_command ditto
require_command mktemp
require_command security
require_command base64

mkdir -p "${EXPORT_DIR}" "${RELEASE_DIR}" "${DMG_STAGING_DIR}"

decode_base64_to_file() {
  local input="$1"
  local output="$2"

  if base64 --help 2>&1 | grep -q -- '--decode'; then
    printf '%s' "${input}" | base64 --decode > "${output}"
  else
    printf '%s' "${input}" | base64 -D > "${output}"
  fi
}

import_signing_certificate_if_needed() {
  if [[ -z "${APPLE_DEVELOPER_ID_P12_BASE64:-}" ]]; then
    return
  fi

  if [[ -z "${APPLE_DEVELOPER_ID_P12_PASSWORD:-}" ]]; then
    echo "APPLE_DEVELOPER_ID_P12_PASSWORD is required when APPLE_DEVELOPER_ID_P12_BASE64 is set." >&2
    exit 1
  fi

  local cert_path="${TEMP_DIR}/developer-id.p12"
  decode_base64_to_file "${APPLE_DEVELOPER_ID_P12_BASE64}" "${cert_path}"

  security create-keychain -p "${TEMP_KEYCHAIN_PASSWORD}" "${TEMP_KEYCHAIN_PATH}"
  security set-keychain-settings -lut 21600 "${TEMP_KEYCHAIN_PATH}"
  security unlock-keychain -p "${TEMP_KEYCHAIN_PASSWORD}" "${TEMP_KEYCHAIN_PATH}"
  KEYCHAIN_CREATED=1

  local existing_keychains
  existing_keychains="$(security list-keychains -d user | tr -d '"')"
  # shellcheck disable=SC2086
  security list-keychains -d user -s "${TEMP_KEYCHAIN_PATH}" ${existing_keychains}
  security default-keychain -d user -s "${TEMP_KEYCHAIN_PATH}"

  security import "${cert_path}" \
    -k "${TEMP_KEYCHAIN_PATH}" \
    -P "${APPLE_DEVELOPER_ID_P12_PASSWORD}" \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    -T /usr/bin/xcodebuild

  security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s -k "${TEMP_KEYCHAIN_PASSWORD}" \
    "${TEMP_KEYCHAIN_PATH}" >/dev/null
}

resolve_app_sign_identity() {
  if [[ -n "${APP_SIGN_IDENTITY}" ]]; then
    return
  fi

  APP_SIGN_IDENTITY="$(
    security find-identity -v -p codesigning 2>/dev/null |
      sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' |
      head -n 1
  )"

  if [[ -z "${APP_SIGN_IDENTITY}" ]]; then
    echo "Could not find a Developer ID Application signing identity." >&2
    echo "Set APP_SIGN_IDENTITY or import a .p12 via APPLE_DEVELOPER_ID_P12_BASE64." >&2
    exit 1
  fi
}

resolve_release_metadata() {
  local info_plist="${EXPORT_DIR}/${APP_NAME}/Contents/Info.plist"

  if [[ -z "${DMG_VERSION}" ]]; then
    DMG_VERSION="$(
      /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${info_plist}" 2>/dev/null || true
    )"
  fi

  if [[ -z "${DMG_VERSION}" ]]; then
    echo "Could not determine CFBundleShortVersionString for ${APP_NAME}." >&2
    echo "Set DMG_VERSION explicitly if the bundle does not expose a marketing version." >&2
    exit 1
  fi

  if [[ -z "${DMG_NAME}" ]]; then
    DMG_NAME="${DMG_BASENAME} ${DMG_VERSION}.dmg"
  fi
}

archive_app() {
  rm -rf "${ARCHIVE_PATH}" "${EXPORT_DIR}/${APP_NAME}" "${DMG_STAGING_DIR}" "${RELEASE_DIR}"
  mkdir -p "${EXPORT_DIR}" "${RELEASE_DIR}" "${DMG_STAGING_DIR}"

  xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination 'generic/platform=macOS' \
    CODE_SIGNING_ALLOWED=NO \
    archive \
    -archivePath "${ARCHIVE_PATH}"

  ditto \
    "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}" \
    "${EXPORT_DIR}/${APP_NAME}"

  resolve_release_metadata
}

sign_and_verify_app() {
  codesign --force --deep --options runtime --timestamp \
    --sign "${APP_SIGN_IDENTITY}" \
    "${EXPORT_DIR}/${APP_NAME}"

  codesign --verify --deep --strict --verbose=2 "${EXPORT_DIR}/${APP_NAME}"
  spctl -a -vvv "${EXPORT_DIR}/${APP_NAME}" || true
}

build_dmg() {
  rm -rf "${DMG_STAGING_DIR}"
  mkdir -p "${DMG_STAGING_DIR}"

  ditto "${EXPORT_DIR}/${APP_NAME}" "${DMG_STAGING_DIR}/${APP_NAME}"
  ln -s /Applications "${DMG_STAGING_DIR}/Applications"

  hdiutil create \
    -volname "${APP_NAME%.app}" \
    -srcfolder "${DMG_STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${RELEASE_DIR}/${DMG_NAME}"
}

notarize_and_staple_dmg() {
  if [[ -n "${APPLE_NOTARY_API_KEY_BASE64:-}" ]]; then
    if [[ -z "${APPLE_NOTARY_API_KEY_ID:-}" || -z "${APPLE_NOTARY_ISSUER_ID:-}" ]]; then
      echo "APPLE_NOTARY_API_KEY_ID and APPLE_NOTARY_ISSUER_ID are required with APPLE_NOTARY_API_KEY_BASE64." >&2
      exit 1
    fi

    decode_base64_to_file "${APPLE_NOTARY_API_KEY_BASE64}" "${TEMP_NOTARY_KEY_PATH}"

    xcrun notarytool submit "${RELEASE_DIR}/${DMG_NAME}" \
      --key "${TEMP_NOTARY_KEY_PATH}" \
      --key-id "${APPLE_NOTARY_API_KEY_ID}" \
      --issuer "${APPLE_NOTARY_ISSUER_ID}" \
      --wait
  elif [[ -n "${NOTARY_KEYCHAIN_PROFILE}" ]]; then
    xcrun notarytool submit "${RELEASE_DIR}/${DMG_NAME}" \
      --keychain-profile "${NOTARY_KEYCHAIN_PROFILE}" \
      --wait
  else
    echo "Provide notarization credentials via NOTARY_KEYCHAIN_PROFILE or APPLE_NOTARY_API_KEY_* env vars." >&2
    exit 1
  fi

  xcrun stapler staple "${RELEASE_DIR}/${DMG_NAME}"
  xcrun stapler validate "${RELEASE_DIR}/${DMG_NAME}"
  spctl -a -vvv --type open "${RELEASE_DIR}/${DMG_NAME}" || true
}

print_summary() {
  cat <<EOF
Release artifacts:
  App: ${EXPORT_DIR}/${APP_NAME}
  DMG: ${RELEASE_DIR}/${DMG_NAME}

Signing identity:
  ${APP_SIGN_IDENTITY}

Notarization:
  completed
EOF
}

import_signing_certificate_if_needed
resolve_app_sign_identity
archive_app
sign_and_verify_app
build_dmg
notarize_and_staple_dmg
print_summary
