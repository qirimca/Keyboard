# Public keyboard preferences and host state — 2026-10-25

Scope: `AppConfiguration.swift` (`SystemKeyboardSettings`), `KeyboardInputViewController+Host.swift`, `DemoStyleProvider.swift`, `KeyboardStateInspector.swift`, plus three proxy-aware predicate calls in `CrimeanTatarAutocompleteProvider.swift`.

- Removed dynamic private preferences-controller lookups, fragmented class names, selector calls, reads of Apple preferences domains, and private input-mode KVC. No private result or Apple-keyboard-list cache remains in these implementations.
- `SystemKeyboardSettings` preserves existing call signatures but now resolves QırımKey-owned `crh.key.feature.<feature>` preferences, defaulting to enabled. The existing suggestions switch still gates prediction/correction. Proxy-aware overloads honor explicit field restrictions on capitalization, correction, quotes/dashes, secure text and (iOS 18+) math expression completion. Global Apple keyboard switches are unavailable through public extension APIs and are not inferred.
- The built-in emoji picker follows QırımKey's `emojiPicker` preference. It does not claim that Apple's Emoji keyboard is installed. Previous Apple-list/cache/test-override values are not read.
- Host bundle ID always returns `nil`, documented as unavailable. Private host KVC, PID, PlugInKit, XPC and dynamic loading paths were deleted. The reset method remains a harmless source-compatibility no-op.
- Sandbox styling cannot activate from a nil host, cached focus/timestamp, or a persisted UI-test flag. It requires an explicitly registered weak `KeyboardContext` in the containing app process. Extension fields use public proxy traits. Existing key geometry, keycap palettes and classic/Liquid Glass rules remain unchanged.
- `KeyboardStateInspector` exposes public language observations separately. It returns no verified active/enabled extension bundle IDs and declares `canInspectKeyboardBundleIds == false`. Compatibility booleans are unverified, not proof of absence; a `crh` language never fabricates a bundle ID.

Tradeoffs and integration:

- App settings cannot mirror global Apple switches that UIKit does not expose. Feature keys represent QırımKey choices and must not be labeled as observations of Apple Settings. No additional settings UI was added in this scope.
- Callers with a current proxy should use the `for:` overloads, particularly resource reclamation, autocorrection, capitalization and math completion. Quote/dash transformations must independently honor their corresponding field trait.
- Register/unregister an in-process preview context if a preview needs the sandbox-only style overrides. The installed extension receives sandbox appearance/field type through normal `UITextView` traits rather than shared cached values.
- UI must represent exact extension installation as unknown or use honestly labeled extension-seen history. Language observations alone do not verify that the Cyrillic extension is installed.

Integration review: the actual HomeView sandbox uses the installed extension with public text-view traits, so it must not register a preview context. Coordinated proxy-aware runtime/action callers with the other implementation agent. The autocomplete provider now supplies its current proxy for math, correction and capitalization checks.

Validation: reviewed `AGENTS.md` and relevant `git log -p` before editing; source audit of the four files. Build, device validation and final private-API guard are owned by the main agent. No commit, push or upload performed by this subtask.
