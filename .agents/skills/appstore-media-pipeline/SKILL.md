---
name: appstore-media-pipeline
description: >-
  Build, verify and upload QırımKey App Store screenshots and App Previews (panoramic designed screenshots, captioned
  previews with an original soundtrack, per-locale text) through the App Store Connect REST API. Use when creating or
  refreshing store media, fixing ASSET_FAILED previews, adding a locale, or auditing App Store Connect media state.
---

# QırımKey App Store media pipeline

Read `AppStoreMetadata/README_MEDIA.md` first (folder map, locale policy, Apple limits). Language rule: always "Crimean Tatar" / "кримськотатарська"; never "Tatar" alone; the ASC `ru` page is pure Crimean Tatar Latin.

## Steps (sequential, one heavy process at a time)

1. **Capture** (simulator, exact store sizes): `QTatar/Scripts/record_store_preview.sh <udid> <w> <h> <out.mp4>` (iPad Pro 13" `1200 1600`, iPhone `886 1920`; `SKIP_WARMUP=1`, `TEST_TIMEOUT`, `WARMUP_TIMEOUT` env). It has a watchdog because `xcodebuild` can hang after the test finishes. If the keyboard is not QırımKey in the recording, reboot the simulator once (keyboard service reload) before retrying. Screenshots: `testAppStoreScreenshots*` tests, then `QTatar/Scripts/export_plan_b_appstore_media.py`.
2. **Designed screenshots**: `python3 QTatar/Scripts/generate_designed_store_media.py [locales] [--preview]` (locales `en uk crh tr de pl ro`). Inputs: `AppStoreMetadata/Media_PlanB/<crh|uk|en>/<device>/0N_*.png`. Output `Media_Designed/<locale>/<device>/`. `--preview` strips are only ~18% scale thumbnails; check a 1:1 crop for quality.
3. **Previews**: edit `Media_Designed/_sources/timelines/<locale>.json` to match the source recording, then `[LOCALES="tr de"] QTatar/Scripts/build_designed_previews.sh [iphone_src.mp4 ipad_src.mp4]` (captions + `generate_preview_soundtrack.py` audio, 30 fps H.264 + AAC; re-encoding this way fixed iPad `ASSET_FAILED`).
4. **Verify video** without a player: `swift QTatar/Scripts/video_frames.swift in.mp4 outdir <step_s> <maxw>` and a PIL contact sheet.
5. **Upload** (credentials from `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`; never commit them): `QTatar/Scripts/asc/upload_designed_screenshots.py [asc_locales]`, `upload_designed_previews.py [asc_locales]`, `push_locale_metadata.py <asc_locale> <folder> [--apply]` (dry-run by default; never touches the live `READY_FOR_SALE` app info). ASC locale map: `en-US→en`, `uk→uk`, `ru→crh`, `tr`, `de-DE→de`, `pl`, `ro`.
6. **Audit**: read-only inventory (`asc_inventory_readonly.py`); wait until every asset is `COMPLETE` (processing can take minutes; a `FAILED` item means re-encode, not re-upload).

## Apple limits (checked 2026-10-28 on developer.apple.com)

Previews: 15–30 s, `.mp4/.mov/.m4v` H.264, ≤30 fps, ≤500 MB, poster frame default 5 s, up to 3 per size and locale, iPhone 886×1920, iPad 13" 1200×1600. Screenshots: up to 10 per size, PNG/JPEG, no alpha, iPhone 6.9" 1320×2868, iPad 13" 2064×2752 (largest accepted; Apple scales down).

## Pitfalls

- A booted simulator + Chrome on 16 GB causes swap thrash; shut idle simulators down. A hung `xcodebuild -quiet` after the test is normal here: kill only your own PID.
- Decimating a long raw recording to 24 s makes 0.25 s key presses invisible; the real-time scenario must be short (<= ~30 s) or the machine must be unloaded.
- Do not publish the personal-dictionary screenshot with third-party brand words; use neutral demo words.
