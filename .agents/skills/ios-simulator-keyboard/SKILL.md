---
name: ios-simulator-keyboard
description: >-
  Workflow for activating a custom iOS keyboard extension in the simulator and
  capturing screenshots of all keyboard modes. Use when testing or auditing a
  keyboard extension app (e.g. QırımKey) on iOS simulator.
---

# iOS Simulator Keyboard Extension Activation

## Overview

Activating a custom keyboard extension in the iOS simulator is non-trivial.
This skill documents what works and what doesn't, based on real testing on
iOS 26.5 / 27.0 simulators.

---

## Step 1: Pre-flight Checks

```bash
# List available simulators (use only existing ones — never create new)
xcrun simctl list devices | grep -v "Shutdown\|^--\|^=="

# Check runtimes
xcrun simctl list runtimes

# Verify app build exists
ls ~/Library/Developer/Xcode/DerivedData/QTatar-*/Build/Products/Debug-iphonesimulator/QTatar.app
```

**Approved simulators for QırımKey:**
- iPhone 15 Pro iOS 27.0: boot via `xcrun simctl boot <UDID>`
- iPad Air (3rd generation) iOS 26.5: `1871ED00-1B16-4E6F-B996-0FD6773B9537`

---

## Step 2: Open Simulator Frontend (REQUIRED)

> ⚠️ Without opening the frontend, `xcrun simctl io screenshot` **hangs** on iOS 27.

Use XcodeBuildMCP instead of raw simctl:

```
xcodebuildmcp: open_sim(simulatorId: "<UDID>")
```

Then take screenshots **only** via XcodeBuildMCP:
```
xcodebuildmcp: screenshot(simulatorId: "<UDID>")
```

**Never use** `xcrun simctl io <UDID> screenshot` on iOS 27 — it hangs indefinitely.

---

## Step 3: Install App

> ⚠️ `xcrun simctl install` hangs on iOS 27 if simctl I/O is broken.
> Use XcodeBuildMCP `install_app_sim` or `build_run_sim` instead.

```
xcodebuildmcp: install_app_sim(
  simulatorId: "<UDID>",
  appPath: "~/Library/Developer/Xcode/DerivedData/.../QTatar.app"
)
```

---

## Step 4: Navigate to Keyboard Settings

> ✅ `xcrun simctl openurl` works even when other simctl commands hang.
> Run in background (`&`) and use XcodeBuildMCP screenshot to verify.

```bash
# Open Settings → General → Keyboard → Keyboards
xcrun simctl openurl <UDID> "App-Prefs:root=General&path=Keyboard/KEYBOARDS" &
sleep 2
# Then take screenshot via XcodeBuildMCP to verify navigation
```

---

## Step 5: Enable Keyboard via UI Automation

If `snapshot_ui` works (test first):
```
xcodebuildmcp: snapshot_ui(simulatorId: "<UDID>")
# Find "Add New Keyboard" button, then tap it
xcodebuildmcp: tap(simulatorId: "<UDID>", x: <x>, y: <y>)
```

If `snapshot_ui` times out (broken `testmanagerd`):
- Use openurl deep links for navigation
- Combine with screenshots to verify state
- Try `xcrun simctl spawn <UDID> launchctl kickstart -k system/com.apple.testmanagerd` to restart testmanagerd

---

## Step 6: What Does NOT Work (iOS 17+)

| Method | Result |
|---|---|
| `PlistBuddy` inject `AppleKeyboards` | Ignored by iOS 17+ security |
| `xcrun simctl spawn ... defaults write` | Writes OK but iOS ignores it |
| `xcrun simctl io screenshot` (iOS 27) | **Hangs indefinitely** |
| `xcrun simctl install` (iOS 27, broken) | **Hangs indefinitely** |
| `xcrun simctl spawn` (iOS 27, broken) | **Hangs indefinitely** |
| headless Simulator (no frontend) | Screenshot tools fail |

---

## Step 7: Capture All Keyboard Modes

Once keyboard is active in the app's text field:

```
1. Alpha lowercase  → screenshot
2. Shift once       → Alpha UPPERCASE → screenshot
3. Shift double-tap → Caps Lock → screenshot
4. Tap "123"        → Numeric mode → screenshot
5. Tap "#+="        → Symbol mode → screenshot
6. Rotate landscape → xcrun simctl io <UDID> rotate right → screenshot
```

For special keyboard types (email, search, numberPad) — the app must expose
text fields with those `keyboardType` values. Navigate via UI automation.

---

## Useful Simulator Commands Reference

```bash
# Boot a simulator
xcrun simctl boot <UDID>

# Open Settings deep link (runs immediately, non-blocking)
xcrun simctl openurl <UDID> "App-Prefs:root=General&path=Keyboard/KEYBOARDS" &

# Launch app
xcrun simctl launch <UDID> <bundleId>

# Check disk usage
du -sh ~/Library/Developer/CoreSimulator/Devices/*/

# Erase simulator (reset, keep device — safer than delete+recreate)
xcrun simctl erase <UDID>
```
