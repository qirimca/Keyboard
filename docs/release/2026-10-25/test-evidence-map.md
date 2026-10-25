# QırımKey release test evidence map — 2026-10-25

This document distinguishes executable behavior checks from source-shape checks and device evidence. It is an inventory of available evidence, not a claim that tests passed in this session. No tests, builds, or simulators were run for this inventory.

## Available checks

| Layer | Location / command | What it checks | Evidence limits |
|---|---|---|---|
| SQLite contract | `python3 QTatar/Scripts/verify_keyboard_db.py` | Opens the bundled database read-only; checks SQLite integrity, required tables/columns/indexes, nonempty tables, duplicate words, and a representative swipe candidate query/plan. | Verifies the bundled DB structure and sample query only; it does not validate the full keyboard experience or linguistic correctness. |
| Private API source-string guard | `bash scripts/check_private_api_strings.sh QTatar` | Greps source text for a fixed set of contiguous private API identifiers. | Source text only; it does not inspect built binaries and can miss identifiers assembled dynamically. A pass is not evidence of App Review compliance. |
| Swift transliteration tests | `swift test --package-path QTatar/Demo/Tests/Transliteration --scratch-path /tmp/qtatar-spm-build` | Executable Swift Testing suite with reference parity over thousands of cases, character-by-character composition/backspace, and document-context ownership checks. | Focused on transliteration behavior, not full iOS keyboard integration. Command builds test artifacts. |
| `qa_runner_v24.swift` | `QTatar/Scripts/qa_runner_v24.swift` | Mixed harness with runtime checks of autocomplete/database behavior, latency/cold-start and content-safety rules, plus many source-text `contains(...)` architectural checks. | Do not equate its total check count with end-to-end tests. No direct standalone invocation is documented and this file is not a CI step in the checked-in workflow. |
| XCUI interaction tests | `QTatar/Demo/QirimKeyUITests/QirimKeyUITests.swift` | 19 `test*` methods interact with the sandbox/app UI for typing, scripts, themes, layout, suggestions, latency, cold start, keyboard modes, traits, swipe behavior, and screenshot capture. | Simulator automation; these tests do not by themselves prove physical-device behavior, system-policy compliance, or all external settings states. |
| CI | `.github/workflows/ci.yml` | Linux DB/string checks; macOS repository hygiene, DB check, Swift package tests, and generic iOS Simulator app build. | No XCUI execution is configured in this workflow. A runner failure before steps start is infrastructure evidence, not a code test result. |

## Source assertions versus runtime checks

`qa_runner_v24.swift` includes genuine calls into `SuggestionsDataBaseManager` and checks returned values, timing, cold-start behavior, and candidate selection. It also reads project files into strings and asserts that particular implementation snippets exist. Those source assertions can catch accidental removals or shape changes, but they do not prove the asserted behavior works at runtime. Report those categories separately in any test summary.

The shell private-API guard has the same boundary: it is a literal-text scan. It cannot establish whether dynamically assembled selectors/classes or compiled symbols are absent.

## Missing release gates / evidence

- No dedicated verified **Full Access OFF** test result is attached to the current source tree or this evidence map.
- No current iPhone/iPad physical-device regression result is attached here, including iPad floating/split behavior on supported OS/device combinations.
- XCUI coverage exists for simulator interaction, but no execution result from the release candidate is recorded here.
- No release-candidate build identity is linked to the three existing App Store screenshot drafts. Their device, OS, app version/build, commit, capture time, and capture method remain unknown in `marketing/provenance.json`.
- The screenshot UI tests write captures under `/tmp/qk_shots`; no tracked capture manifest currently records the source build/device metadata.
- No completed App Store media visual review, 13-inch iPad screenshot set, or App Preview recording is evidenced here.

## Safe interpretation

Treat each command’s output as evidence only for the scope in the table. A static/source check is not a functional test; a simulator result is not a physical-device result; a passing unit suite does not close Full Access or App Review gates. Record the exact commit, command, environment, and result when the release candidate is tested.
