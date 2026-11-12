#!/bin/bash
set -euo pipefail

developer_dir=$(xcode-select -p 2>/dev/null || true)
if [[ "$developer_dir" != *Xcode.app/Contents/Developer* ]]; then
  echo "error: full Xcode is not active; run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 2
fi
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "error: xcodebuild is unavailable; finish Xcode installation and accept its license" >&2
  exit 2
fi
if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
  echo "error: DEVELOPMENT_TEAM is required for a signed App Group build" >&2
  echo "example: make build DEVELOPMENT_TEAM=ABCDE12345 BUNDLE_ID=com.yourname.FuckingAdvice APP_GROUP_ID=ABCDE12345.fucking-advice-macos" >&2
  exit 2
fi
if [[ "${BUNDLE_ID:-}" == "com.example."* ]]; then
  echo "error: replace the placeholder bundle identifier" >&2
  exit 2
fi
if [[ "${APP_GROUP_ID:-}" != "${DEVELOPMENT_TEAM}.fucking-advice-macos" ]]; then
  echo "error: macOS unprovisioned App Group must be ${DEVELOPMENT_TEAM}.fucking-advice-macos" >&2
  exit 2
fi
if ! security find-identity -v -p codesigning | grep -q 'Apple Development'; then
  echo "warning: Keychain does not yet report a valid Apple Development identity; xcodebuild will ask Xcode account services to resolve it" >&2
fi
