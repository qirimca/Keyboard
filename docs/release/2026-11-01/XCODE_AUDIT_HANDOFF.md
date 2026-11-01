# Xcode audit continuation — 2026-11-01
Status: build verified; device UI regression and release NOT complete.

## Confirmed changes
- Callout deprecated initializer no longer defaults its style argument; frame-only calls select the modern environment-style initializer. Original diagnostics cleared.
- KeyboardStateInspector no longer fabricates extension bundle IDs from languages or reads AppleKeyboards preferences. Public bundle state remains unknown. Existing first-element active-helper contract preserved; not blindly changed to contains.
- Personal dictionary demo: restored 18 prior names, all absent from bundled lexicon by casefold lookup; 15/18 replacement toponyms were already present. Explicit demo launch guard, only empty lexicon, no DELETE, INSERT OR IGNORE.
- attach_build.py requires --build, checks version/app, build VALID/nonexpired, verifies relationship GET after PATCH, fails nonzero. No ASC mutation performed.
- upload_designed_previews.py removes destructive replacement; all-file preflight, remote conflict checking, completed checksum+size matching and preservation. Offline only.

## Executed validation
- Xcode BuildProject on active QTatar / physical iPad (3), iPadOS 26.7.1: SUCCESS, 57.58 seconds, zero errors. Existing unrelated deprecation warnings remain.
- Build log: /var/folders/8d/cvl2sk8j5bn9ydjr1bjn2p7r0000gn/T/ActionArtifacts/4EE940FA-9BE3-45AA-A897-17A8269CA27E/BuildProject/BuildProject-Log-20261101-015307.txt
- Python unittest discover scripts/tests: 24 PASS (7 attach, 9 media, 8 private API).
- SQLite verification earlier this session: PASS; 215586 words, 63014 bigrams, 12114 trigrams, 106 typo corrections.
- Source private-API scan earlier: 337 files PASS. Built app executable/debug binary scan: 12 files PASS. Bounded string scans are NOT compliance proof.
- Built app contains Keyboard, KeyboardCyrillic, KeyboardUkrainian; AppLocalizations.bundle crh/uk/en and Settings.bundle crh/uk/en (also ru).
- Both previously installed binaries launched successfully. New binary installed on iPhone; iPad install in progress at this checkpoint.
- Physical UI screenshot tool unavailable: DeviceInteraction supports simulator OS27+ only. No visual proof collected. Do not mark UI scenarios PASS from launch success.
- New Swift Testing cases added for unknown bundle state; not yet executed. Main app scheme exposes 24 UI tests, not package unit tests.

## Resource constraints
- User cleared DerivedData and Gemini backup caches; start 10GiB free, 58% free memory, loadavg 7.99.
- After build and automatic DeviceSupport regeneration: 4.5GiB free, loadavg 22.23. No second build started.
- Never run two xcodebuild processes; require loadavg <12, memory >15%, Data >=3GiB before new builds/tests.
- Automatic symbol regeneration caused earlier repeated ENOSPC. Do not repeatedly delete active .tmp symbol extraction.

## Next actions
1. Finish/check iPad installation, then launch new binaries on both physical devices in parallel.
2. Once resource thresholds pass, build test targets once and run focused UI regression on both devices with screenshots. Check test setup before allowing destructive reset (current launch args reset sandbox text only).
3. Execute added KeyboardKit package tests and portable/transliteration checks; do not claim static checks as hang/performance evidence.
4. Review remaining warnings and runtime behavior; do not change layouts solely from pasted audit claims.
5. Archive/upload/review are not done. Current code version is 3.1 (8), but current ASC state has not been queried in this session.
6. Preserve all pre-existing dirty changes and media deletions; no commit or push made here.

## Completed device deployment
- New built QTatar.app installed and launched successfully on BOTH physical devices: iPad Air 3 (iPadOS 26.7.1) and iPhone 15 Pro (iOS 27.2). Parallel installations and parallel launches completed. This proves deployment/startup only, not keyboard UI or hang-free behavior.
- Latest resource check: Data 2.8GiB free, loadavg 12.03/12.56/8.59, memory free 64%. Further builds/tests paused below required 3GiB floor. DeviceSupport regenerated ~9GiB after user cleanup.
- User reports refreshed quota: 55%. Quota is not the current blocker.

- Build log copied into this report directory as device-build.log for durable evidence.
- Runtime inventory verified: iOS 27.0 = 8,067,000,161 bytes, ID 48DD0DB3-D192-4C5A-8DC7-6183EA7EEC2B; 27.1 and 18.6 also installed. User question pending before removing 27.0. No runtime removed.
