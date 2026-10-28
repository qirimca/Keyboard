# App Store media: where everything lives (QırımKey 3.1)

Last updated: 2026-10-28. App Store ID 6739430313, iOS version 3.1 (`PREPARE_FOR_SUBMISSION`).

> Language naming rule: always **Crimean Tatar** (qırımtatarca; Ukrainian: *кримськотатарська*, one word). Crimean Tatars are an indigenous people of Crimea, Ukraine. Never write "Tatar" alone and never confuse the language with Kazan Tatar (Russia).
>
> Locale policy (decided by the project owner): App Store Connect has no `crh` locale, so the **`ru` page is written purely in Crimean Tatar (Latin script), never in Russian**. It mentions Ukraine only indirectly and apolitically (Ukrainian cities of Crimea, Ukrainian documents confirming the Latin script), never as a political statement. `uk` is Ukrainian, `en-US/en-GB/en-CA` English, `tr` Turkish, `de-DE` German, `pl` Polish, `ro` Romanian: interface-style text always matches the locale language. The app UI itself exists only in Crimean Tatar (QT), Ukrainian (УК) and English (EN). Note: `AppStoreMetadata/tr/*.txt` currently contains Crimean Tatar text, not Turkish - needs a decision.

## Folders

| Folder | Content | Use |
|---|---|---|
| `Media_Designed/` | **Current store set.** Panoramic designed screenshots (5 frames, 3 locales x iPhone 6.9" / iPad 13") and captioned App Previews with original soundtrack. Built from authentic captures. | Uploaded to ASC |
| `Media_Designed/_sources/` | Corrected source capture for iPad frame 3 (real Cyrillic keyboard, clock normalised to 09:41) and the caption timelines (`timelines/<locale>.json`). | Inputs for the generators |
| `Media_PlanB/` | Authentic unframed full-screen screenshots (1320x2868, 2064x2752) and plain screen-recording previews. | Fallback set, re-uploadable any time |
| `Media/` | Older working copy of Plan B plus keyframes. | Legacy, see `_Trash_Archive/` |
| `Media_Experimental_Posters/` | Early framed-poster experiments. | Legacy, see `_Trash_Archive/` |
| `Screenshots/` | Raw captures per device size. | Reference |
| `<locale>/` (`en-US`, `uk`, `ru`, `tr`, `crh`) | Store text (description, keywords, notes). | Metadata |

## Generators (all deterministic, no generative imagery)

| Script | Purpose |
|---|---|
| `QTatar/Scripts/generate_designed_store_media.py` | Composes panoramic screenshots from Plan B captures. `--preview` writes downscaled strips. |
| `QTatar/Scripts/generate_preview_soundtrack.py` | Synthesizes the original soundtrack (no third-party music). |
| `QTatar/Scripts/compose_preview.swift` | Burns timed captions into a recording and muxes audio (30 fps H.264 + AAC). |
| `QTatar/Scripts/build_designed_previews.sh` | Runs the composer for 3 locales x 2 devices, sequentially. |
| `QTatar/Scripts/video_frames.swift` | Extracts frames from an mp4 (verification when a viewer cannot play video). |
| `QTatar/Scripts/asc/*.py` | App Store Connect REST uploaders. Credentials come from `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` (never committed). |

## Apple requirements used

- iPhone 6.9" screenshots 1320x2868, iPad 13" screenshots 2064x2752 (portrait, PNG/JPEG, no alpha).
- App Preview: 15-30 s, H.264 + AAC, up to 30 fps; iPhone 886x1920, iPad 1200x1600; 3 previews max per set.
- Captions and marketing frames are allowed as long as the footage is the real app in use (App Review 2.3).

## Known state / open items

- iPad previews were `FAILED` (`ASSET_FAILED`) before the re-encode; check `asc_inventory` after the new upload.
- Crimean Tatar caption strings reuse words from the app UI and are **pending native-speaker review**.
- The personal-dictionary screenshot lists third-party brand words (Spotify, Netflix...). Consider a neutral demo word list.
- Build 3.1 (5) is not uploaded to ASC; version 3.1 cannot be submitted until it is.
