#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
FIXTURE=$(mktemp -d -t toolcheckmacbook-signing)
APP="$FIXTURE/ToolCheckMacBook.app"
cleanup() {
  rm -f "$APP/Contents/MacOS/ToolCheckMacBook" "$APP/Contents/Info.plist" \
    "$APP/Contents/_CodeSignature/CodeResources" "$FIXTURE/check.log" "$FIXTURE/main.c"
  if [[ -d "$APP/Contents/_CodeSignature" ]]; then rmdir "$APP/Contents/_CodeSignature"; fi
  rmdir "$APP/Contents/MacOS" "$APP/Contents" "$APP" "$FIXTURE"
}
trap cleanup EXIT
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.toolcheckmacbook.signing-fixture</string>
<key>CFBundleExecutable</key><string>ToolCheckMacBook</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
echo 'int main(void) { return 0; }' > "$FIXTURE/main.c"
xcrun clang -arch x86_64 -arch arm64 -mmacosx-version-min=14.0 \
  -o "$APP/Contents/MacOS/ToolCheckMacBook" "$FIXTURE/main.c"

expect_rejected() {
  if bash "$ROOT/scripts/verify_app_signature.sh" "$APP" > "$FIXTURE/check.log" 2>&1; then
    echo "error: Invalid signing fixture was accepted: $1" >&2
    exit 1
  fi
  echo "Correctly rejected: $1"
}

expect_rejected "unsigned Universal 2 app"
bash "$ROOT/scripts/sign_app.sh" "$APP"

/usr/libexec/PlistBuddy -c "Add :ModifiedAfterSigning bool true" "$APP/Contents/Info.plist"
expect_rejected "modified bundle metadata"

codesign --force --sign - "$APP"
expect_rejected "missing capture entitlements"

bash "$ROOT/scripts/sign_app.sh" "$APP"
echo "Bundle signing regression checks passed; no fixture was launched."
