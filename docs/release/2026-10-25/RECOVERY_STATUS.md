# QırımKey — Recovery & Checkpoint 0 Status (2026-10-25)

## 1. Live Repository & Branch State
- **Working Directory**: `/Users/love/Documents/Documents - MacBook Air - Віта/GitHub/Keyboard`
- **Active Branch**: `codex/release-public-api-2026-10-25` (branched from `302c05aa5d43411b09d0f57a21ecefddf5b3a18f` on `ipad-floating-and-shift-audit`)
- **Remote**: `origin -> git@github.com:qirimca/Keyboard.git`
- **Uncommitted Codex Working Tree Backup**:
  - Patch: `/tmp/codex_live_backup_2026-10-25/uncommitted_working_tree.patch` (`118,768` bytes)
  - SHA256: `13b99544863ff2541fbae5e70299f7b6daf59a8ed331c3da32836f011c4ab85c`
  - Duplicate iCloud conflict files (`DemoActionHandler 2.swift`, `KeyboardViewController 2.swift` from `12:01:18` before `runtime-followup.patch`) removed from `QTatar/Demo/Keyboard/`.

## 2. Modified & Untracked Files Inspected at Checkpoint 0
- **Modified (13 files, `+161 / -1623` lines)**:
  - `.github/workflows/ci.yml`
  - `QTatar/Demo/Demo/Views/HomeView.swift`
  - `QTatar/Demo/Keyboard/CrimeanTatarAutocompleteProvider.swift`
  - `QTatar/Demo/Keyboard/DemoActionHandler.swift`
  - `QTatar/Demo/Keyboard/DemoCalloutActionProvider.swift`
  - `QTatar/Demo/Keyboard/DemoStyleProvider.swift`
  - `QTatar/Demo/Keyboard/KeyboardViewController.swift`
  - `QTatar/Demo/QirimKeyUITests/QirimKeyUITests.swift`
  - `QTatar/Demo/Shared/AppConfiguration.swift`
  - `QTatar/Sources/KeyboardKit/State/KeyboardStateInspector.swift`
  - `QTatar/Sources/KeyboardKit/_Essentials/KeyboardContext.swift`
  - `QTatar/Sources/KeyboardKit/_Essentials/KeyboardInputViewController+Host.swift`
  - `scripts/check_private_api_strings.sh`
- **Untracked additions**:
  - `scripts/check_private_apis.py` & `scripts/tests/test_private_api_guard.py`
  - `docs/release/2026-10-25/public-preferences.md`, `runtime-remediation.md`, `test-evidence-map.md`
  - `marketing/README.md`, `marketing/provenance.json`

## 3. System Capacity, Disk Space, Devices & Quota
- **Disk Space (`/System/Volumes/Data`)**:
  - Initial: `2.2 GiB` free (dropped to `1.5 GiB` while `iPhone16,1 27.0.1 (24A446)` `6.4 GB` DeviceSupport symbols were extracted by Xcode).
  - Reclaimed safely: removed shutdown simulator `EF5A73AA-B22A-450C-B416-AF0DC9EBD14C`, `XcodeBuildMCP/workspaces`, `codex-file-preview-*` temp dirs, and `ModuleCache.noindex`.
  - Current free space on `/System/Volumes/Data`: **`5.9 GiB`** (`iOS DeviceSupport` for both `iPhone16,1` and `iPad11,3` preserved).
- **System Load**: `vm.loadavg = { 4.07 4.91 13.97 }` (normal).
- **Connected Physical Devices**:
  - **iPhone 15 Pro (`iPhone16,1`)**: UDID `00008130-000954812231001C` — `connected`
  - **iPad Air 3rd generation (`iPad11,3`)**: UDID `00008020-00025DC63AA3002E` — `available (paired)`
- **Antigravity Quota (`Gemini 4 Argon`)**:
  - **5-Hour Limit Remaining**: **100%** (`0%` used)
  - **Weekly Limit Remaining**: **100%** (`0%` used)

## 4. Prioritized Execution Queue (Completed 2026-10-25)
1. **[x] P0-A & P0-B**: Fixed `KeyboardStateInspector` / `KeyboardStateContext` → `HomeView` tri-state regression (`verifiedInstalled | verifiedMissing | unknown` + App Group extension activation heartbeat).
2. **[x] P0-C**: Verified `scripts/tests/test_private_api_guard.py` (`8/8`), `scripts/check_private_api_strings.sh QTatar` (`0` violations across `333` files), and `QTatar/Scripts/verify_keyboard_db.py` (`PASS`).
3. **[x] P0-D**: Fixed `swift test` and `xcodebuild` package resolution (`KeyboardKit`) and verified Debug/Release builds.
4. **[x] P1-E**: Parallel physical device installation (`iPhone 15 Pro` + `iPad Air 3rd generation`) + simulator UI test suite (`testPhase13AdaptiveHeightTrackpadSlideAndSettingsBundle`, `testAppStoreScreenshotsLight`, `testAppStoreScreenshotsDark`, `testAppStoreScreenshotCyrillicOnly`) + true native-matched single-tone comet swipe trail (`comet_overlay_comparison.png`).
5. **[x] P2-G & Sub-task `17.5.7`**: Coupled `Kirill klaviaturası` and `Українська розкладка` `Toggle` switches with Add/Remove `OnboardingView` guides, recaptured clean App Store & verification screenshots (`selâm` orthography, realistic `180 | 38 söz/daq | 7 daq | 18` stats, English/Ukrainian iOS Settings paths, synchronized Light/Dark theme), rendered 30 SVG templates + 22s 6-scene App Preview MP4 videos, and updated [`marketing/provenance.json`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/marketing/provenance.json).

