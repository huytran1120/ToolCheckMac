# Release Notes & Distribution Guide

## Versioning

The version number is maintained in `Sources/App/Info.plist`:

- `CFBundleShortVersionString`: User-facing version string, e.g. `1.2`
- `CFBundleVersion`: Internal build number, e.g. `3`

Prior to tagging a release, make sure `VERSION` in `scripts/build_and_notarize.sh` matches.

## Local Packaging

```bash
./scripts/build_and_notarize.sh
```

Output:

```text
~/Desktop/ToolCheckMacBook-1.2.dmg
```

## Signing & Notarization

For public distribution, you need:

1. A paid Apple Developer account
2. `Developer ID Application` certificate installed in Keychain
3. Saved `notarytool` credentials profile:

```bash
xcrun notarytool store-credentials "toolcheckmacbook-notary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

Optional environment variables:

```bash
export TOOLCHECKMACBOOK_SIGN_ID="Developer ID Application: Your Name (TEAMID)"
export TOOLCHECKMACBOOK_NOTARY_PROFILE="toolcheckmacbook-notary"
```

## GitHub Release

```bash
gh release create v1.2 ~/Desktop/ToolCheckMacBook-1.2.dmg \
  --title "ToolCheckMacBook 1.2" \
  --notes "First release: Local Mac hardware check, interactive tests, report export."
```

## Post-Release Verification

- The DMG artifact is visible on the GitHub Release page
- `hdiutil verify ~/Desktop/ToolCheckMacBook-1.2.dmg` passes
- The app launches and completes initial system inspection
- Instructions in README remain accurate

## Gatekeeper Troubleshooting

If macOS Gatekeeper blocks opening an ad-hoc or unnotarized build:
1. Right-click `ToolCheckMacBook.app` in Finder and select **Open**.
2. To allow apps from Anywhere in System Settings:
   ```bash
   sudo spctl --master-disable
   ```
3. If macOS says the app is "damaged and can't be opened":
   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/ToolCheckMacBook.app
   ```
