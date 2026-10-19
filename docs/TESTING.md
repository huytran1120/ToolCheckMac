# ToolCheckMacBook Verification & Testing Checklist

This document is for pre-release verification and store inspection procedures. Automated system checks can be validated via build and launch; interactive tests require physical Mac hardware.

## Automated Regression Coverage

Run `bash scripts/run_tests.sh` from the repository root. The suite uses synthetic hardware data and temporary files for the following cases:

| Area | Regression scenarios |
| --- | --- |
| Diagnostic results | Missing or unknown SMART is a warning, not a pass; serial verification requires two matching sources; battery mismatch warnings reach category status, scoring, and serialized reports |
| Management evidence | Hosts parsing strips inline comments, matches exact hostnames and IPv4/IPv6 aliases, and distinguishes read errors from a successful empty read; hosts overrides do not invent MDM enrollment or double-deduct the score; partial enrollment responses remain inconclusive |
| Local commands | Large stdout and stderr do not deadlock; non-zero exits and launch failures are explicit; timeouts stop commands, including commands that ignore termination or continuously produce output |
| SSD benchmark | Complete reads/writes succeed; short writes are handled; early EOF, write errors, and flush failures cannot produce a successful result; interrupted flushes retry; cancellation prevents publishing partial results or overlapping restarts |
| Performance test | Duration and progress use monotonic elapsed time, not a loop counter; a cancelled test cannot report a full-duration pass |
| Keyboard | Both Command keys are recorded while Command shortcuts pass through; keys outside the layout do not inflate coverage |
| Localization | Intel without T2 is not translated as having T2; inconclusive MDM/SIP probes remain inconclusive in both languages; legacy Vietnamese hosts/SIP headlines render correctly in English without claiming proven bypass |
| History | Missing files differ from unreadable/corrupt files; migration preserves the original; failed writes/deletes do not mutate the displayed history; unreadable history is protected until reloaded successfully |
| Report export | PNG/PDF rendering includes the complete bilingual MDM advisory; PNG height expands for the advisory; empty data and destination write errors are rejected; failed writes preserve existing files |

These tests do not certify physical hardware health. Verify Intel and Apple Silicon MacBooks on supported macOS versions, including models with and without Touch ID or fans.

## Pre-Release Verification

```bash
xcodebuild -project ToolCheckMacBook.xcodeproj -scheme ToolCheckMacBook -configuration Release -derivedDataPath build_release CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO
./scripts/build_and_notarize.sh
hdiutil verify ~/Desktop/ToolCheckMacBook-1.2.dmg
```

Verification items:

- App launches successfully and finishes initial background scan
- All sidebar pages navigate without clipping, layout overlap, or blank views
- "Save to History" produces a valid snapshot entry
- "Export Report" produces valid PNG and PDF files
- Save/export failures display an error rather than appearing successful
- Corrupt or unreadable history shows an error and a reload action without overwriting the existing file
- Cancelling SSD or CPU tests keeps saving disabled until a new test finishes successfully
- Vietnamese and English show the same diagnostic conclusion, including missing-data warnings
- MDM advisories appear in both the Security detail view and exported PNG/PDF without clipping
- Erase/setup guidance requires owner consent and backups, and distinguishes Apple Silicon/Intel with T2 from Intel without T2; do not erase any device merely to run this checklist
- DMG mounts cleanly with `ToolCheckMacBook.app` and Applications symlink

## Automated Detection Modules

| Module | Expected Behavior |
| --- | --- |
| Hardware Specifications | Displays marketing name, serial number, chip, memory, architecture, macOS version |
| Battery | Shows cycle count and health percentage on laptops; shows N/A or no data on desktops |
| Security & Lock | Shows Security Chip tier, independent MDM/DEP enrollment and hosts evidence, three-state SIP status, and Apple ID / Activation Lock warnings; never treats a local clean scan as proof of organizational release |
| Storage | Displays capacity, free space, NVMe SMART status, and TBW |
| Network | Displays Wi-Fi and Bluetooth controller status and PHY modes |
| Ports | Displays detected physical USB / Thunderbolt controllers and connected devices |
| AI Models | Recommends local LLM capability based on Unified Memory |

## Interactive Hardware Tests

| Module | Operation | Acceptance Criteria |
| --- | --- | --- |
| Keyboard | Fullscreen test, press keys individually | Keys light up upon press; no unresponsive, stuck, or ghosting keys |
| Display | Cycle through pure black, white, RGB, gradients | No dead pixels, stuck subpixels, severe backlight bleed, or banding |
| Speaker / Headphones | Play test audio sweeps | Left and right channels output distinctly |
| Microphone | Speak into microphone after granting permission | RMS VU meter reacts with stable input and no abnormal floor noise |
| Camera | View live preview after granting permission | Image is crisp, unobstructed, with no sensor artifacts |
| Touch ID | Confirm biometric prompt | Sensor authenticates successfully or reports unsupported on models without Touch ID |
| Trackpad | Click, drag, swipe, gestures | Cursor follows smoothly; multi-finger gestures and Force Touch pressure register |
| Performance Stress | Run multi-core load | No crashes; thermal state transitions cleanly (`Nominal` / `Fair` / etc.) |
| Disk Speed Test | Run read/write benchmark | Direct I/O throughput (MB/s) reports without errors |
| Port Live Check | Plug in / unplug USB devices | Each physical port detects device insertion and removal events |

## Privacy & Screenshots

Actual screenshots and reports contain serial numbers, device names, and system details. Before posting publicly, ensure all sensitive data is redacted.
