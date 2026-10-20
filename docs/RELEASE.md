# Release Notes & Distribution Guide

## Versioning

The version is configured in `project.yml`. Run `xcodegen generate` after changing it and commit the generated `Sources/App/Info.plist` and Xcode project:

- `CFBundleShortVersionString`: User-facing version string, e.g. `1.3.3`
- `CFBundleVersion`: Internal build number, e.g. `7`

The packaging script reads this version automatically. The GitHub workflow reads it from the built app and rejects a release tag that does not match.

## Local Packaging

```bash
./scripts/build_and_notarize.sh
```

Output:

```text
~/Desktop/ToolCheckMacBook-1.3.3.dmg
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

After committing and validating the release changes, tag the intended commit:

```bash
git tag -a v1.3.3 -m "Release ToolCheckMacBook v1.3.3"
git push origin v1.3.3
```

The `Build & Release` workflow runs tests, builds both `x86_64` and `arm64`, and publishes a public release only for `v*` tags. It uploads versioned DMG/ZIP files, stable `ToolCheckMacBook.dmg` / `ToolCheckMacBook.zip` aliases, and `checksums.txt`.

Pushes to `main` upload Actions artifacts but do not publish a release. Wait for the tag workflow and release assets to succeed before updating the version shown on GitHub Pages.

The CI workflow does **not** configure Developer ID signing or Apple notarization. Disclose this on the release and download page; the local signing instructions above are a separate distribution path.

Pages download buttons use `/releases/latest/download/ToolCheckMacBook.dmg` and the corresponding ZIP alias. Update its displayed version and JSON-LD metadata for each release. Do not hardcode a file size unless checked against the published asset.

## Post-Release Verification

- The release is public, latest, and points at the intended commit
- Both versioned files and stable download aliases work without authentication
- Downloaded files match `checksums.txt`
- `hdiutil verify ToolCheckMacBook-v1.3.3.dmg` passes
- The packaged app's version matches the tag and its binary contains both architectures
- The app launches and completes initial system inspection
- Instructions in README remain accurate

## Gatekeeper

Do not disable Gatekeeper or remove quarantine attributes as a release installation step. Unnotarized builds may be blocked, and launch behavior varies by macOS version. See [Apple's guidance on opening Mac apps safely](https://support.apple.com/102445). Never bypass malware or damaged-app warnings; use a verified signed distribution or build from reviewed source instead.
