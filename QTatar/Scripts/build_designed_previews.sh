#!/bin/bash
# Build all designed App Previews: captions + original soundtrack burned into the authentic screen recordings.
# Sequential on purpose (one AVFoundation encode at a time). Usage: build_designed_previews.sh [iphone_src.mp4 ipad_src.mp4]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
IPHONE_SRC="${1:-AppStoreMetadata/Media_PlanB/AppPreview_PureScreen_iPhone_6_9.mp4}"
IPAD_SRC="${2:-AppStoreMetadata/Media_PlanB/AppPreview_PureScreen_iPad_13.mp4}"
WAV=/tmp/qk_audio/soundtrack.wav
mkdir -p /tmp/qk_audio
[ -f "$WAV" ] || python3 QTatar/Scripts/generate_preview_soundtrack.py "$WAV" 24.1
for loc in ${LOCALES:-en uk crh tr de pl ro}; do
  mkdir -p "AppStoreMetadata/Media_Designed/$loc"
  TL="AppStoreMetadata/Media_Designed/_sources/timelines/$loc.json"
  swift QTatar/Scripts/compose_preview.swift "$IPHONE_SRC" "$WAV" "AppStoreMetadata/Media_Designed/$loc/AppPreview_Designed_iPhone_6_9.mp4" "$TL" top 2>&1 | grep -E "^(OK|FAILED)"
  swift QTatar/Scripts/compose_preview.swift "$IPAD_SRC" "$WAV" "AppStoreMetadata/Media_Designed/$loc/AppPreview_Designed_iPad_13.mp4" "$TL" middle 2>&1 | grep -E "^(OK|FAILED)"
done
echo DONE
