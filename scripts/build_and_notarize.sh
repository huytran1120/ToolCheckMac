#!/bin/bash
# ToolCheckMacBook release packaging script: Release Build -> Developer ID Sign -> Package DMG -> Notarize -> Staple.
#
# Prerequisites (one-time setup):
#   1. Paid Apple Developer account ($99/year).
#   2. Install "Developer ID Application" certificate in Keychain
#      (Xcode -> Settings -> Accounts -> Manage Certificates -> + -> Developer ID Application).
#   3. Create notarytool credentials with an App-specific password (one-time):
#        xcrun notarytool store-credentials "toolcheckmacbook-notary" \
#          --apple-id "YOUR_APPLE_ID" \
#          --team-id "YOUR_TEAM_ID" \
#          --password "APP_SPECIFIC_PASSWORD"
#
# Usage: ./scripts/build_and_notarize.sh
# If no certificate is found, the script generates an ad-hoc DMG for local testing.
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT="ToolCheckMacBook.xcodeproj"
SCHEME="ToolCheckMacBook"
APP_NAME="ToolCheckMacBook"
VERSION="1.2"
BUILD_DIR="build_release"
DMG_OUT="$HOME/Desktop/${APP_NAME}-${VERSION}.dmg"

# -- Customize as needed: your Developer ID and notarytool profile --
SIGN_ID="${TOOLCHECKMACBOOK_SIGN_ID:-Developer ID Application}"   # Leave empty to skip signing
NOTARY_PROFILE="${TOOLCHECKMACBOOK_NOTARY_PROFILE:-toolcheckmacbook-notary}"

echo "▸ Generating Xcode project"
command -v xcodegen >/dev/null && xcodegen generate

echo "▸ Release Build (Universal 2: Apple Silicon + Intel)"
rm -rf "$BUILD_DIR"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO | tail -1

APP="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"
lipo -info "$APP/Contents/MacOS/${APP_NAME}"

HAS_CERT=$(security find-identity -v -p codesigning 2>/dev/null | grep -c "Developer ID Application" || true)
if [ "$HAS_CERT" -gt 0 ]; then
  echo "▸ Developer ID Signing (Hardened Runtime)"
  codesign --force --deep --options runtime --timestamp \
    --sign "$SIGN_ID" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
  SIGNED=1
else
  echo "⚠ No Developer ID certificate found. Generating ad-hoc DMG (run locally; right-click Open if distributing)."
  SIGNED=0
fi

echo "▸ Packaging DMG"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG_OUT"
hdiutil create -volname "${APP_NAME}" -srcfolder "$STAGE" -ov -format UDZO "$DMG_OUT" | tail -1
rm -rf "$STAGE"

if [ "$SIGNED" -eq 1 ]; then
  echo "▸ Notarizing DMG (submitting to Apple, takes a few minutes)..."
  xcrun notarytool submit "$DMG_OUT" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "▸ Stapling notarization ticket"
  xcrun stapler staple "$DMG_OUT"
  xcrun stapler validate "$DMG_OUT"
  echo "✅ Signed + Notarized + Stapled: $DMG_OUT"
else
  echo "✅ Ad-hoc DMG generated: $DMG_OUT"
fi
