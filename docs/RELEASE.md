# Release Notes & Distribution Guide

## Versioning

The version is configured in `project.yml`. Run `xcodegen generate` after changing it and commit the generated `Sources/App/Info.plist` and Xcode project:

- `CFBundleShortVersionString`: User-facing version string, e.g. `1.3.4`
- `CFBundleVersion`: Internal build number, e.g. `8`

The packaging script reads this version automatically. The GitHub workflow reads it from the built app and rejects a release tag that does not match.

## Local Packaging

```bash
./scripts/build_and_notarize.sh
```

Output:

```text
~/Desktop/ToolCheckMacBook-1.3.4.dmg
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
git tag -a v1.3.4 -m "Release ToolCheckMacBook v1.3.4"
git push origin v1.3.4
```

The `Build & Release` workflow runs tests, builds both `x86_64` and `arm64`, and publishes a public release only for `v*` tags. It uploads versioned DMG/ZIP files, stable `ToolCheckMacBook.dmg` / `ToolCheckMacBook.zip` aliases, and `checksums.txt`.

Pushes to `main` upload Actions artifacts but do not publish a release. Wait for the tag workflow and release assets to succeed before updating the version shown on GitHub Pages.

The CI workflow ad-hoc signs the **complete app bundle** with hardened runtime and microphone/camera entitlements before packaging. It verifies every Universal 2 architecture, the bundle identifier, resources, and entitlements. A linker-only ARM signature is insufficient: the Intel slice and bundle resources must also be signed. The signing regression script rejects unsigned apps, modified metadata, and missing capture entitlements.

CI still does **not** configure Developer ID signing or Apple notarization. Ad-hoc signing prevents an invalid bundle from breaking permission identity checks within the same build; it does not establish publisher trust or guarantee that permissions survive app updates. Disclose this on the release and download page. Developer ID signing plus notarization is the supported distribution path for stable publisher identity.

The local packaging script uses the same signing/verification helpers. If an explicit `TOOLCHECKMACBOOK_SIGN_ID` cannot be used, signing fails rather than silently publishing an ad-hoc replacement.

Pages download buttons use `/releases/latest/download/ToolCheckMacBook.dmg` and the corresponding ZIP alias. Update its displayed version and JSON-LD metadata for each release. Do not hardcode a file size unless checked against the published asset.

## Post-Release Verification

- The release is public, latest, and points at the intended commit
- Both versioned files and stable download aliases work without authentication
- Downloaded files match `checksums.txt`
- `hdiutil verify ToolCheckMacBook-v1.3.4.dmg` passes
- The packaged app's version matches the tag and its binary contains both architectures
- Extract the downloaded ZIP or DMG and run `bash scripts/verify_app_signature.sh /path/to/ToolCheckMacBook.app`; verification must succeed for both architectures and both capture entitlements
- On a clean test account, allow and deny microphone/camera access separately; a completed choice must not trigger repeated prompts for the same build
- Leave the capture page while permission or startup is pending; no capture should start later, and the UI must remain responsive
- The app launches and completes initial system inspection
- Instructions in README remain accurate

## Gatekeeper

Do not disable Gatekeeper or remove quarantine attributes as a release installation step. Unnotarized builds may be blocked, and launch behavior varies by macOS version. See [Apple's guidance on opening Mac apps safely](https://support.apple.com/102445). Never bypass malware or damaged-app warnings; use a verified signed distribution or build from reviewed source instead.
