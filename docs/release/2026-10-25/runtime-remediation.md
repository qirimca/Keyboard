# Public runtime remediation — 2026-10-25

## Changes

- Removed programmatic system floating/split mode controls and their custom menu actions, cross-process requests, private notifications, private placement/preferences/capability probes, hardware allowlist and mode-transition timers.
- Removed all host/backdrop frame mutation and the process-wide pinch recognizer swizzle. UIKit owns the keyboard platter and its mode gestures.
- `KeyboardContext.syncIsFloating` retains its existing name for layout consumers, but now means only an iPad extension width below 420 points. It reads the extension view bounds or an explicit transition target width, never ancestors or system placement. Narrow host windows deliberately use the same compact layout.
- The extension still adapts its own keyboard height and layout during rotation/width transitions. A target width takes precedence over the previous bounds. Old saved split preferences no longer fabricate a split layout.
- Removed undocumented Settings URL schemes. The System Keyboard row shows the General → Keyboard instructions on every OS version; Settings buttons use the documented app-settings URL.
- Removed private input-mode KVC and private segment-class inspection from HomeView. Cyrillic language observations can supply positive evidence; absence is unknown, not proof of an uninstalled extension. Native segmented accessibility identifiers use the public accessibility container API when UIKit exposes matching children.
- Extension feature checks pass the current document proxy to the public settings predicates, so host traits can disable autocorrection, capitalization, prediction and math behavior.

## Evidence

- Before changes, `bash scripts/check_private_api_strings.sh QTatar` incorrectly returned OK while fragmented runtime class names were present.
- Read `git log -p -3` for affected controller, context, HomeView and action-provider files before changing behavior.
- Source inspection after remediation found no dynamic private class/selector lookup, private symbol resolution, host frame mutation or gesture swizzle in the five changed runtime/UI files.
- No Xcode build, install, simulator test or physical-device test was run by this implementation agent; parent owns the single build/test pipeline. Any build/device result must be recorded separately.

## Remaining release gates and limitations

- Test actual iPad docked, user-initiated floating and return, rotation, cold/repeated keyboard switching, host switching and narrow windows. Confirm system gestures still work without the former global swizzle. Do not claim that a system mode switch is available on any specific OS/device until measured.
- Native system split control and detection have no documented replacement in this implementation. Custom forced split/floating commands are removed. The app no longer synthesizes split state; physical split/merge behavior must be assessed on supported hardware.
- Test iPhone/iPad with Full Access OFF and ON; particularly script binding, proxy traits, globe, Shift, backspace, swipe, suggestions and host theme changes. No Full Access PASS is implied here.
- Native segmented accessibility child exposure varies by UIKit version. Validate VoiceOver and UI-test selectors; native labels/selection remain available even when per-child identifiers cannot be assigned.
- Validate localization text, Settings navigation and Cyrillic onboarding after the status becomes unknown; do not replace unknown state with a private probe.
- Source scan alone is insufficient. Inspect the actual Release app and both extension executables with strings/nm/otool using the parent-owned guard pipeline before release.
