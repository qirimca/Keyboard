# Physical iPad (`iPad11,3`, `00008020-00025DC63AA3002E`) Crash & Diagnostic Log Analysis (2026-10-26)

## 1. Summary of Collected Device Logs (`systemCrashLogs`)
Pulled via:
```bash
xcrun devicectl device copy from --device 00008020-00025DC63AA3002E --domain-type systemCrashLogs --source . --destination /tmp/ipad_crash_logs_1110
```

### Observed Reports on `2026-10-25` – `2026-10-26`
1. **`QTatar-2026-10-26-095643.ips`, `QTatar-2026-10-26-102056.ips`, `QTatar-2026-10-26-102100.ips` (`CFBundleShortVersionString: 3.1`, `CFBundleVersion: 5`, `iPadOS 26.7.1 (23H30)`)**:
   - **Exception**: `EXC_BAD_ACCESS (SIGSEGV)` — `KERN_PROTECTION_FAILURE at 0x000000016f5a7ff8` (`Could not determine thread index for stack guard region`).
   - **VM Region**: Main thread (`Thread 0`) hit the 16 KB `Stack Guard` (`0x16f5a4000-0x16f5a8000`) at the bottom of the 1008 KB main thread stack (`289` frames deep).
   - **Root Cause**:
     - `HomeView.body` had 40 chained `.onReceive(...)` and `.onChange(...)` view modifiers directly on the root `ScrollViewReader`, causing `AttributeGraph` (`AG::Graph::UpdateStack::update()`) to recurse `229` frames on initial view graph instantiation.
     - At the bottom of that recursion, Swift's runtime metadata resolver (`swift::Demangle::TypeDecoder::decodeMangledType`) recursed another `60` frames decoding the deeply nested generic return type of `HomeView.statisticsAndAchievementsSection.getter`, overflowing the 1 MB main-thread stack guard on arm64 iPadOS 26.7.1.
   - **Fix Applied**:
     - Extracted the `.onReceive` and `.onChange` modifiers into three flat leaf `Color.clear` views (`scrollPositionObserversView`, `homeLifecycleObserversView`, `homePreferencesObserversView`).
     - Type-erased `statusIndicatorsSection`, `testingAndWritingSection`, `statisticsAndAchievementsSection`, `keyboardSettingsSection`, `expandedStatisticsContentView`, and `expandedAchievementsGridView` with `AnyView(...)` so `TypeDecoder::decodeMangledType` resolves in O(1) stack depth.

2. **`Keyboard-*.ips` / `KeyboardCyrillic-*.ips` / `JetsamEvent-*.ips`**:
   - **Zero** `Keyboard` or `KeyboardCyrillic` crash reports or `JetsamEvent` reports occurred after `2026-10-20` on the iPad.
   - **Root Cause of `media_1793003922693_a1ec0576.jpg` (`10:37 Mon 26 Oct`, Floating Keyboard Clipping in Spotlight)**:
     - When `KeyboardViewController` was in iPadOS Floating mode (`usesCompactLayout == true`, `width < 420 pt`), `preferredContentSize` was left at `.zero`. On iPadOS 26.7.1, `_UIRemoteInputViewController` collapsed the system floating backdrop platter height to a ~10 pt white strip at the top while the `227 pt` SwiftUI keyboard rendered hanging below the collapsed platter and got cut off at the bottom edge of the screen.
   - **Root Cause of `media_1793004211857_d6a144e6.png` (`10:43 Mon 26 Oct`, App Library Search Fallback)**:
     - After the floating platter collapsed in Spotlight, iPadOS transitioned to App Library search while the host input view had a mismatched `0 pt` preferred content height, causing SpringBoard to display the system keyboard for that search session.
   - **Fix Applied**:
     - In `KeyboardViewController.updateKeyboardHeightConstraint(targetSize:)`: when `usesCompactLayout == true` (`isPad && width > 0 && width < 420`), set `constraint.priority = .init(999)` and `preferredContentSize = CGSize(width: 0, height: targetH)` (`227.0 pt`) so the iPadOS floating platter always sizes to the full floating keyboard height; when `!usesCompactLayout` (`width >= 420`), set `constraint.priority = .defaultHigh` and `preferredContentSize = .zero`.

## 2. Live Physical Device Verification & On-Device Lifecycle Logger
- **Installed & Launched on Physical Devices**:
  - `iPad (3)` (`iPad Air (3rd generation)`, `iPad11,3`, UDID `00008020-00025DC63AA3002E`): launched `PID 1620`, verified alive with `0` new crash reports (`QTatar-2026-10-26-102100.ips` remained the last pre-fix crash).
  - `My` (`iPhone 15 Pro`, UDID `00008130-000954812231001C`): launched `PID 5974`, verified alive with `0` crash reports.
- **Persistent Lifecycle JSONL Logger (`Diagnostics/keyboard_lifecycle.jsonl`)**:
  - `QirimKeyDiagnosticsSubscriber.recordLifecycleEvent(_:details:)` writes structured JSONL records (`timestamp`, `bundleId`, `event`, `boundsWidth`, `boundsHeight`, `isFloating`, `preferredContentHeight`, `constraintHeight`, `constraintPriority`, `locale`) to the shared App Group container (`group.crh.key.keyboardplus/Diagnostics/keyboard_lifecycle.jsonl`, capped at 256 KB) and can be pulled at any time via:
  ```bash
  xcrun devicectl device copy from --device 00008020-00025DC63AA3002E --domain-type appGroupDataContainer --domain-identifier group.crh.key.keyboardplus --source Diagnostics/keyboard_lifecycle.jsonl --destination /tmp/keyboard_lifecycle.jsonl
  ```
