# QırımKey Live Handoff & Calibration Ledger (2026-10-26)

- **Active Branch**: `codex/release-public-api-2026-10-25`
- **Base Commit**: `5af3721` (`fix(ipad-ui): calibrate Docked/Floating geometry, 13-key Cyrillic, callout and swipe comet`)
- **Active Worker**: `DeepCoder` (`a253e81d-3099-4acf-bacc-2b8bce00915c`)
- **Pacing Window (`09:00–09:50`)**: Active (`nice -n 10`, `-jobs 2`, single `xcodebuild` at a time).

---

## 1. Forensic Audit of Today's 29 Desktop Screenshots (`26.10.2026` on `iPad Air 3rd generation`)

| Screenshot(s) | Mode & Theme | Keyboard Shown | Key Pixel / Point Measurements (`2x` Retina) | Required Action |
|---|---|---|---|---|
| `07.32.45`, `07.34.45`, `07.35.27`, `07.48.02`, `07.50.10`, `07.50.22` vs `07.48.46`, `07.49.25`, `07.49.45` | Floating (Light & Dark, Portrait & Landscape) | Native (`УК`) vs QırımKey (`QT` / `Кʼ`) | Native Row 3 is `[123 (0.235), space, 🔍 (0.235)]` with **NO `😊` Emoji key**. Commit `5af3721` added `\|\| context.isKeyboardFloating` to `canShowPhoneEmoji`, injecting `😊` and shrinking `123` to `0.13`. | Remove `\|\| context.isKeyboardFloating` from `canShowPhoneEmoji` in `DemoLayoutProvider.swift`; keep `😊` strictly on iPhone (`deviceType == .phone && !isKeyboardFloating && SystemKeyboardSettings.isEmojiKeyboardEnabled`) and restore `0.235` width for `123` in Floating mode. |
| `07.40.29` (Native) vs `07.40.04` (QırımKey) | Docked Landscape Light (over green Telegram wallpaper) | Native (`УК`) vs QırımKey (`QT`) | Platter: `RGB(180,207,195)`. Native unpressed: `RGB(235,254,245)` (`Color.white.opacity(0.84)`). **Native pressed key**: `RGB(188,214,202)` (`G-R = +26`, highly translucent over wallpaper). **QırımKey pressed key**: `RGB(206,209,208)` (opaque gray `Color(white:0.82).opacity(0.92)` that killed wallpaper tint). | Change Light Mode pressed letter key fill in `DemoStyleProvider.swift` to translucent `Color(white: 0.56).opacity(0.20)` (or `Color.black.opacity(0.08)` / `Color.white.opacity(0.16)`) so the underlying wallpaper tint shines through like Native `RGB(188,214,202)`. |
| `07.42.56`, `07.47.01` (Native) vs `07.43.45` (QırımKey) | Docked Portrait Dark | Native (`УК`) vs QırımKey (`QT`) | Platter: `RGB(22,22,24)`. Unpressed key: `RGB(60,60,62)` (`Color(white:0.71).opacity(0.24)`). **Native pressed key**: `RGB(38,38,42)` (**darker/more translucent** than unpressed!). **QırımKey pressed key**: `RGB(96,96,98)` (brighter `Color(white:0.85).opacity(0.38)`). | Change Dark Mode Docked pressed letter key fill in `DemoStyleProvider.swift` from `Color(white: 0.85).opacity(0.38)` to `Color(white: 0.71).opacity(0.09)` (`RGB(38,38,40)` over `RGB(22,22,24)`), matching Native `07.42.56` & `07.47.01`. |
| `07.51.24`, `07.39.05` (Native) vs `07.40.04`, `07.56.42` (QırımKey) | Docked Landscape (`2224x1668`) | Native vs QırımKey | Overall height `347.0 pt` is confirmed ideal by user. User requested narrowing the 3-suggestion bar slightly in Docked mode and giving the height to Docked keys + enlarging Docked key letters. Native uppercase `W`/`E` cap-height = `18.0 pt` (`36 px`), ours = `15.0 pt` (`30 px`). | Narrow Docked `toolbarHeight` from `38.0 pt` to `32.0 pt` (Docked only; Floating stays `38.0 pt`), add `+1.5 pt` per row in Landscape Docked (`totalKeyboardHeight` stays locked at `347.0 pt`), increase Portrait Docked key row heights (`61.5 pt` / `59.5 pt`), and increase Docked key letter font sizes by `+2.5..3.5 pt` + Docked suggestion font sizes (`17.5 pt` / `16.5 pt`). |
| `07.48.02` (Native) vs `07.49.25`, `07.49.45` (QırımKey) | Floating Callout & Key Fonts | Native (`УК`) vs QırımKey (`Кʼ`) | Native Dark Floating callout for `р`: color `RGB(78,78,79)`, glyph height `27.0 pt` (`x-height = 21.0 pt`, font `~37 pt`), stem bottom aligned with Row 1 key bottom. QırımKey (`07.49.25`): color `RGB(107,107,107)`, glyph height `21.5 pt` (`font = 30 pt`). Native Floating key lowercase x-height = `12.0 pt` (`24 px`, font `22.5 pt`); QırımKey (`07.49.25`) = `9.5 pt` (`19 px`, font `19.0 pt`). | Set Dark Floating `calloutBackgroundColor` to `Color(red: 0.306, green: 0.306, blue: 0.310)` (`RGB(78,78,79)`), increase `calloutFont` to `36.5 pt`, align callout vertical offset, increase Floating lowercase key font from `19.0 pt` to `21.5 pt` (`22.5 pt` on 10/11-col), and increase Floating suggestion font from `14.5 pt` to `16.0 pt`. |
| `07.34.45`, `07.35.27`, `07.50.10`, `07.50.22` vs `07.48.46` | Floating Swipe Comet | Native (`УК`) vs QırımKey (`QT`) | Native comet (`07.50.22`, `07.35.27`) has a fuller rounded head (`radius ~8.5 pt`) and soft translucent neutral-gray fill (`RGB ~155..185` over white keys). | Calibrate `SwipeTrailOverlay` in `SystemKeyboard.swift` (`maxHeadRadius = 8.5`, `maxCometArcLength = 175.0`, refined Light/Dark tone & opacity). |
| Docked bottom-right `.dismissKeyboard` (`⌄⌨`) | Docked iPad | QırımKey | Long-pressing `.dismissKeyboard` stopped showing `Плаваюча` / `Розділити` / `Об’єднати` after commit `51e5cca`. | Restore `.dismissKeyboard` callout actions in `DemoCalloutActionProvider.swift`, action handling in `DemoActionHandler.swift`, `deviceSupportsSplitKeyboard` (via public POSIX `uname`), and `setSplitKeyboardMode` / `requestFloatingKeyboardMode` in `KeyboardViewController.swift` with 0 private APIs. |
| `07.51.24`, `07.43.31` | First-open / Globe switch | System fallback to `Q` | Cold-start main-thread churn in `viewDidLoad` + `viewWillAppear` (3x `renderVersion &+= 1`, sync `requestSupplementaryLexicon`, sync `UserDefaults` writes before first frame commit). | Configure `state.keyboardContext` and `applyPreferences(syncDisk: false)` BEFORE `super.viewDidLoad()`, deduplicate `viewWillAppear` render pass, and move `refreshSupplementaryLexicon()` + disk sync to `viewDidAppear`. |

---

## 2. Verification & Device Matrix Status
- [ ] Source edits completed & verified against `scripts/check_private_api_strings.sh` (`0` findings)
- [ ] `python3 -m unittest discover -s scripts/tests -p "test_*.py"`
- [ ] `nice -n 10 swift test` in `QTatar/Demo/Tests/Transliteration`
- [ ] Physical **iPad Air (3rd generation)** (`00008020-00025DC63AA3002E`) build, install & verification
- [ ] Physical **iPhone 15 Pro** (`00008130-000954812231001C`) check/install
- [ ] Simulator **iPad (A16)** (`iOS 27.0`, `56480961-4318-47E1-AFAA-A38E5F1D857E`) build, install & visual verification
- [ ] Simulator **iPhone 16 Pro** (`iOS 27.0`) verification
- [ ] Simulator **`iOS 18.6`** verification
