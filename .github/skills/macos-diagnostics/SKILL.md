---
name: macos-diagnostics
description: Use when adding, fixing, or testing hardware diagnostics in ToolCheckMacBook, including battery, storage, security and lock detection, connectivity, interactive hardware checks, diagnostic scoring, and reports.
---

# ToolCheckMacBook hardware diagnostics

## Locate the relevant implementation

- Read `project.yml` for the current deployment target and Swift settings. The app targets macOS 14+ with Swift 6 strict concurrency and supports Apple Silicon and Intel.
- Inspect the relevant service in `Sources/Core/` for automatic checks, or the corresponding directory in `Sources/Checks/` for interactive tests.
- Trace results through `Sources/UI/AppModel.swift`, including scan registration, `SidebarItem.resultIDs`, and interactive result recording.
- Use `Sources/Core/ReportEngine/ReportModel.swift` for `CheckResult`, `CheckStatus`, device profiles, and scoring. Inspect report export and history code when changing persisted or exported data.
- Read the closest tests in `Tests/` before changing behavior. Reuse existing helpers and patterns instead of introducing a parallel diagnostic framework.

## Implement reliable checks

- Keep hardware inspection local and offline. Do not add telemetry, uploads, remote lookups, or network dependencies to diagnostics.
- Prefer public macOS APIs. Reuse `ShellRunner` for necessary local commands, with explicit executable paths and separate arguments; never interpolate device data into shell code.
- Treat command output and hardware properties as untrusted input. Handle missing keys, malformed values, command failures, unavailable APIs, and permission denial explicitly.
- Never report a passing result merely because a probe failed or returned no data. Explain the limitation in the result; use `unsupported` for unavailable hardware or platform capabilities, and `skipped` for a user-skipped test.
- Distinguish evidence of MDM enrollment, Activation Lock, or serial mismatch from an inconclusive probe. Do not turn uncertain observations into definitive security claims.
- Preserve stable result IDs, existing scoring rules, and history compatibility unless the requested change explicitly requires otherwise.
- Keep blocking probes and benchmark work off the main actor. Follow the existing `@MainActor` and `Sendable` boundaries without disabling concurrency checks.
- Release camera, microphone, audio, event-monitor, timer, and temporary benchmark resources when a test ends or is cancelled.
- Keep benchmarks bounded and cancellable. Never overwrite user files, alter security settings, or remove management profiles as part of a diagnostic.
- Do not add device serials or other personal data to logs, committed fixtures, or external services. Preserve intentional local profile/report fields and user-requested exports.

## Wire affected surfaces

- For a new check, connect its service or interactive view, scan/test result registration, navigation, and result IDs as appropriate. Verify that the result reaches the overview and reports.
- Follow `Sources/Core/Localization/LocalizationManager.swift` for Vietnamese and English strings, including localized result titles, summaries, and report text.
- Reuse `Sources/UI/DesignSystem.swift` for any related UI changes.
- Review `Sources/App/Info.plist`, `Sources/App/ToolCheckMacBook.entitlements`, and `project.yml` if an API requires permission declarations. Keep generated configuration consistent and avoid adding unnecessary privileges.
- Update the relevant README sections when user-visible diagnostic behavior changes.

## Validate the requested behavior

- Add focused XCTest coverage for changed parsing, thresholds, statuses, scoring, localization, or history compatibility. Use synthetic data, not the developer machine's real identifiers.
- Cover supported and unsupported hardware, missing or malformed input, and threshold boundaries when relevant. Test Intel and Apple Silicon branches with fixtures where possible.
- Run commands from the repository root. If `project.yml` changed, regenerate the project with `xcodegen generate` before building or testing.
- Run the smallest relevant test selection, replacing the example class below with the actual affected XCTest class:

  ```bash
  xcodebuild test \
    -project ToolCheckMacBook.xcodeproj \
    -scheme ToolCheckMacBook \
    -destination "platform=macOS,arch=$(uname -m)" \
    -only-testing:ToolCheckMacBookTests/ReportModelTests \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    -quiet
  ```

- Use `bash scripts/run_tests.sh` when the full suite is warranted. It regenerates the project when XcodeGen is available and runs the macOS tests.
- For changes requiring a separate app build:

  ```bash
  xcodebuild build \
    -project ToolCheckMacBook.xcodeproj \
    -scheme ToolCheckMacBook \
    -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet
  ```

- Do not run release, signing, notarization, or publishing scripts for routine validation.
- Automated tests do not prove that physical hardware works. Clearly distinguish covered behavior from manual checks still needed for cameras, microphones, Touch ID, ports, displays, or thermal behavior.
- If Xcode, tools, permissions, or hardware are unavailable, report the specific validation limitation rather than claiming success.
