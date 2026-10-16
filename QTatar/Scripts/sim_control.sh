#!/usr/bin/env bash
# Helper script to control iOS Simulator, run QTatar, and capture screenshots

set -euo pipefail

CMD="${1:-help}"

case "$CMD" in
  screenshot)
    DEST="${2:-/tmp/sim_screenshot.png}"
    xcrun simctl io booted screenshot "$DEST"
    echo "Screenshot saved to: $DEST"
    ;;
  boot)
    DEVICE="${2:-iPhone 17}"
    xcrun simctl boot "$DEVICE" 2>/dev/null || true
    open -a Simulator
    echo "Booted $DEVICE and opened Simulator"
    ;;
  open)
    open -a Simulator
    ;;
  list)
    xcrun simctl list devices available
    ;;
  *)
    echo "Usage: $0 {boot [device]|open|screenshot [dest_path]|list}"
    ;;
esac
