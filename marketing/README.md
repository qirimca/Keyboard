# QırımKey marketing assets

This folder is the intended home for reproducible marketing templates and generated previews. It currently contains an inventory only: there is no renderer, layered template, source manifest generator, contact sheet, or final export pipeline yet.

## Current status

- The three iPhone images under `AppStoreMetadata/Screenshots/iphone-6.3-1206x2622/draft/` are drafts, not approved App Store screenshots.
- The light Latin draft is marked for a status-bar retake. Keep that retake requirement until a fresh capture is reviewed.
- Capture device, OS version, app version/build, source commit, capture time, and method are unknown for all three drafts. These fields are `null` in [`provenance.json`](provenance.json); do not fill them from assumptions.
- The light and dark logo PNGs are existing in-app brand assets. Their editable design source and author/source history were not present in the inspected tree.
- Nothing in this folder is ready for App Store Connect upload.

## Intended reproducible template system

When implemented, keep the components independently editable:

1. A template document (SVG or HTML/CSS) with editable headline and subtitle text, a separate screenshot image, independent device frame/mask, and independent background/decorative layers.
2. A renderer that consumes `screenshot_path`, `title`, `subtitle`, `locale`, `theme`, and `device_class`, plus a versioned configuration for typography, layout, colors, and export dimensions.
3. Outputs stored separately from source templates, with a generated manifest linking every export to its source screenshot, source hash, template/config version, and capture provenance.
4. Technical and visual review records before any export can be marked final. Never synthesize app UI or imply an unverified feature.

The requested target classes include iPhone 1206 × 2622, iPad 13-inch 2064 × 2752, and social formats 1080 × 1350, 1080 × 1920, and 1920 × 1080. Confirm current store requirements before export. iPad layouts and social variants have not been created here.

## Verify the current inventory

Run from the repository root to recompute the recorded file hashes and dimensions:

```sh
shasum -a 256 \
  AppStoreMetadata/Screenshots/iphone-6.3-1206x2622/draft/*.png \
  QTatar/Demo/Demo/Assets.xcassets/Projects/logo.imageset/qirim_logo.png \
  QTatar/Demo/Demo/Assets.xcassets/Projects/logo.imageset/qirim_logo_dark.png

sips -g pixelWidth -g pixelHeight -g format \
  AppStoreMetadata/Screenshots/iphone-6.3-1206x2622/draft/*.png \
  QTatar/Demo/Demo/Assets.xcassets/Projects/logo.imageset/qirim_logo.png \
  QTatar/Demo/Demo/Assets.xcassets/Projects/logo.imageset/qirim_logo_dark.png
```

Update `provenance.json` only from source evidence. Preserve unknown fields as `null`; do not replace the original draft files during retakes.

## Approval boundary

Keep outputs in draft/review state until the source build and device are identified, the screenshot is checked against the real app, dimensions and alpha/profile requirements are validated, and an independent visual review is complete. Do not upload to App Store Connect automatically.
