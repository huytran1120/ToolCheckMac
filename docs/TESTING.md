# ToolCheckMacBook Verification & Testing Checklist

This document is for pre-release verification and store inspection procedures. Automated system checks can be validated via build and launch; interactive tests require physical Mac hardware.

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
- DMG mounts cleanly with `ToolCheckMacBook.app` and Applications symlink

## Automated Detection Modules

| Module | Expected Behavior |
| --- | --- |
| Hardware Specifications | Displays marketing name, serial number, chip, memory, architecture, macOS version |
| Battery | Shows cycle count and health percentage on laptops; shows N/A or no data on desktops |
| Security & Lock | Shows Security Chip tier, MDM enrollment, Apple ID / Activation Lock warnings |
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
