#!/bin/bash
# MacCheck 发布打包脚本：Release 构建 → Developer ID 签名 → 打 DMG → 公证 → 装订。
#
# 前置条件（一次性配置）：
#   1. 一个付费 Apple Developer 账号（$99/年）。
#   2. 在钥匙串里安装「Developer ID Application」证书
#      （Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application）。
#   3. 用 App 专用密码创建 notarytool 凭证配置（只需做一次）：
#        xcrun notarytool store-credentials "maccheck-notary" \
#          --apple-id "你的AppleID邮箱" \
#          --team-id "你的TeamID(10位)" \
#          --password "App专用密码(appleid.apple.com生成)"
#
# 用法：  ./scripts/build_and_notarize.sh
# 未配置签名时，脚本会跳过签名/公证，只产出可本地运行的 ad-hoc DMG。
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT="MacCheck.xcodeproj"
SCHEME="MacCheck"
APP_NAME="MacCheck"
VERSION="1.2"
BUILD_DIR="build_release"
DMG_OUT="$HOME/Desktop/${APP_NAME}-${VERSION}.dmg"

# —— 按需修改：你的 Developer ID 与 notarytool 凭证名 ——
SIGN_ID="${MACCHECK_SIGN_ID:-Developer ID Application}"   # 留空或未装证书则跳过签名
NOTARY_PROFILE="${MACCHECK_NOTARY_PROFILE:-maccheck-notary}"

echo "▸ 生成工程"
command -v xcodegen >/dev/null && xcodegen generate

echo "▸ Release 构建"
rm -rf "$BUILD_DIR"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO | tail -1

APP="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"

HAS_CERT=$(security find-identity -v -p codesigning 2>/dev/null | grep -c "Developer ID Application" || true)
if [ "$HAS_CERT" -gt 0 ]; then
  echo "▸ Developer ID 签名（含 hardened runtime）"
  codesign --force --deep --options runtime --timestamp \
    --sign "$SIGN_ID" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
  SIGNED=1
else
  echo "⚠ 未找到 Developer ID 证书，跳过签名与公证，仅产出 ad-hoc DMG（可本地运行，分发给他人需右键打开）。"
  SIGNED=0
fi

echo "▸ 打 DMG"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG_OUT"
hdiutil create -volname "${APP_NAME} 验机宝" -srcfolder "$STAGE" -ov -format UDZO "$DMG_OUT" | tail -1
rm -rf "$STAGE"

if [ "$SIGNED" -eq 1 ]; then
  echo "▸ 公证 DMG（提交给 Apple，通常几分钟）"
  xcrun notarytool submit "$DMG_OUT" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "▸ 装订公证票据"
  xcrun stapler staple "$DMG_OUT"
  xcrun stapler validate "$DMG_OUT"
  echo "✅ 已签名 + 公证 + 装订：$DMG_OUT （可直接分发，用户双击即开）"
else
  echo "✅ ad-hoc DMG 已生成：$DMG_OUT"
fi
