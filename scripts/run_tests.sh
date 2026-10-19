#!/bin/bash
# ToolCheckMacBook Unit Test Runner
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▸ Regenerating Xcode project with XcodeGen..."
command -v xcodegen >/dev/null && xcodegen generate

echo "▸ Running automated test suite..."
xcodebuild test \
  -project ToolCheckMacBook.xcodeproj \
  -scheme ToolCheckMacBook \
  -destination "platform=macOS,arch=$(uname -m)" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  -quiet

echo "✅ All unit tests PASSED successfully!"
