#!/bin/bash
set -euo pipefail

APP="${1:?Usage: verify_app_signature.sh path/to/ToolCheckMacBook.app}"
INFO="$APP/Contents/Info.plist"
EXECUTABLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$INFO")
IDENTIFIER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO")
ARCHITECTURES=$(lipo -archs "$APP/Contents/MacOS/$EXECUTABLE")

for ARCH in x86_64 arm64; do
  if [[ " $ARCHITECTURES " != *" $ARCH "* ]]; then
    echo "error: Missing required architecture: $ARCH" >&2
    exit 1
  fi
done

# Verify the whole bundle and every slice, not just the native linker signature.
codesign --verify --deep --strict --all-architectures --verbose=2 "$APP"

ENTITLEMENTS=$(mktemp -t toolcheckmacbook-entitlements)
trap 'rm -f "$ENTITLEMENTS"' EXIT
for ARCH in x86_64 arm64; do
  SIGNATURE=$(codesign --display --verbose=2 --arch "$ARCH" "$APP" 2>&1)
  if ! grep -Fxq "Identifier=$IDENTIFIER" <<< "$SIGNATURE"; then
    echo "error: Signature identifier does not match Info.plist for $ARCH" >&2
    exit 1
  fi
  codesign --display --arch "$ARCH" --entitlements - --xml "$APP" > "$ENTITLEMENTS"
  for ENTITLEMENT in com.apple.security.device.audio-input com.apple.security.device.camera; do
    if [[ "$(/usr/libexec/PlistBuddy -c "Print :$ENTITLEMENT" "$ENTITLEMENTS")" != "true" ]]; then
      echo "error: Missing $ENTITLEMENT entitlement for $ARCH" >&2
      exit 1
    fi
  done
done

echo "Verified complete Universal 2 app signature and capture entitlements."
