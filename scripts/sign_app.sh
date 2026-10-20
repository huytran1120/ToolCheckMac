#!/bin/bash
set -euo pipefail

APP="${1:?Usage: sign_app.sh path/to/ToolCheckMacBook.app [signing-identity]}"
IDENTITY="${2:--}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OPTIONS=(--force --options runtime --entitlements "$ROOT/Sources/App/ToolCheckMacBook.entitlements")

if [[ "$IDENTITY" == "-" ]]; then
  echo "Ad-hoc signing for local testing; this does not provide Developer ID trust or notarization."
else
  OPTIONS+=(--timestamp)
fi

codesign "${OPTIONS[@]}" --sign "$IDENTITY" "$APP"
bash "$ROOT/scripts/verify_app_signature.sh" "$APP"
