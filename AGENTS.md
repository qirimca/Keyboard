# AGENTS.md

- If using XcodeBuildMCP, use the installed XcodeBuildMCP skill before calling XcodeBuildMCP tools.

## Simulator & Device Testing Rules
- Every UI/keyboard change MUST be tested on **both iPad and iPhone** (iPadOS 26/27 + iOS 27).
- Check connected physical devices first (`xcrun devicectl list devices`): **iPad Air 3rd generation** (`<IPAD_DEVICE_UDID>`) and **iPhone 15 Pro** (`<IPHONE_DEVICE_UDID>`).
- **Mandatory Parallel Execution Across Physical Devices & Simulator**: Connected physical devices and the already-booted simulator consume zero extra simulator disk space. Automated installations (`xcrun devicectl device install/process launch`) and test runs (`xcodebuild test-without-building` with separate `-resultBundlePath` paths) MUST ALWAYS be launched **in parallel simultaneously** across all connected physical devices and the active simulator — never sequentially one after another — so results from all devices are collected at the same time.
- If a physical device (e.g. **iPhone 15 Pro**) is offline/unavailable, you MUST test that form factor on an iOS 27 simulator (`xcrun simctl`):
  - Check free disk space (`df -h /`) first.
  - If sufficient disk space is available, create/boot the missing approved simulator (**iPhone 15 Pro** / **iPhone 16 Pro** on iOS 27 or **iPad (A16)** on iPadOS 27) and test in parallel.
  - If disk space is tight (< 10 GB free), complete all tests, screenshots, and video capture on the active simulator first, delete that simulator (`xcrun simctl delete <udid>`) to reclaim space, and then create and test on the other form-factor simulator so both iPad and iPhone are thoroughly verified.
- Never pass `CODE_SIGNING_ALLOWED=NO` when building for Simulator (`xcodebuild`); Xcode's default ad-hoc signing with `.xcent` entitlements is required so `QTatar.app` and `Keyboard.appex` can share `UserDefaults(suiteName: "group.crh.key.keyboardplus")`.

## Keyboard UI & Task Tracking Rules
- Interactive toolbar slots (such as the 3 autocomplete suggestion buttons in `Autocomplete+NativeToolbarStyle.swift`) MUST always apply `.frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())` inside the `Button` label so the entire slot area responds to taps, not just the text glyph.
- Daily/motivational phrases in the keyboard top bar MUST be displayed as complete, self-contained sentences without ellipsis truncation (`...`); tapping them inserts extended info (author/translation) and MUST NEVER count toward user typing statistics (words, characters, or WPM/CPM speed).
- Typing statistics MUST distinguish words typed manually letter-by-letter from words completed via the 3 autocomplete suggestions (suggestions do not inflate manual typing speed), include speed/volume progression levels based on realistic typing norms, and provide a confirmation dialog before resetting statistics.
- Peer UI elements of the same hierarchy level (such as settings row titles or subtitles in `HomeView.swift`) MUST render at an identical effective font size without per-row `.minimumScaleFactor` shrinkage differences.
- Default interface language MUST be Crimean Tatar (`crh`), managed in-app without exposing a redundant language picker in iOS System Settings.
- Standard iOS/iPadOS keyboard features MUST strictly match official system behavior without inventing redundant settings in `HomeView.swift`: iPad Split Keyboard MUST only be active on iPad models supported by UIKit (`UIKeyboardDeviceSupportsSplit()`), controlled via the bottom-right `⌄⌨` vertical callout menu and pinch gesture; `Docked ↔ Floating` transitions MUST keep the floating platter clamped within `UIScreen.main.bounds`; and all `Settings → General → Keyboards` traits (`UITextDocumentProxy`, `UILexicon`, `playInputClick()`, Smart Punctuation, Show Maths Results) MUST be respected.
- In `task_tracker.md` (and any progress artifacts), mark `[x]` for completed items, `[/]` **only** for the exact item(s) actively being executed at that moment, and `[ ]` for queued items — never mark all items `[/]` simultaneously unless they are genuinely running at the exact same instant.

## Browser Rules
- NEVER use headless mode. Always use a real browser with GUI.
- Chrome DevTools MCP connects to `http://127.0.0.1:9222`. Ensure Chrome is running with `--remote-debugging-port=9222` before using browser tools.
- To launch Chrome with remote debugging: `/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222`

## Copilot Rules
- When consulting Microsoft Copilot at `copilot.cloud.microsoft`, always select model **"5.6 Thinking"** if available.
