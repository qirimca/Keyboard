#!/bin/bash
# Record a fresh authentic App Store preview on ONE simulator (sequential, never parallel with other xcodebuild).
# Usage: record_store_preview.sh <sim_udid> <width> <height> <out.mp4>
#   iPad Pro 13": 1200 1600   |   iPhone 6.9": 886 1920
# Steps: boot + clean status bar -> warm-up run (registers the keyboard through the real Settings UI) -> recordVideo + UI test
#        -> transcode to the Apple size (constant duration ~24 s) with transcode_live_preview.swift
set -u
UDID="$1"; W="$2"; H="$3"; OUT="$4"
cd "$(cd "$(dirname "$0")/../.." && pwd)"
RAW="/tmp/qk_raw_${UDID:0:8}.mp4"
# Watchdog: a stuck xcodebuild (test runner lost, memory pressure) must not hang the pipeline. Own process only.
run_with_timeout() { local t=$1; shift; "$@" & local p=$!; ( sleep "$t"; kill -9 "$p" 2>/dev/null ) & local w=$!; wait "$p"; local rc=$?; kill "$w" 2>/dev/null; return $rc; }
rm -rf /tmp/qk_warm.xcresult /tmp/qk_rec.xcresult "$RAW" "$OUT"
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 >/dev/null 2>&1
ARGS=(-project QTatar/Demo/QTatar.xcodeproj -scheme QTatar -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath /tmp/qk_dd_verify
      -only-testing:QirimKeyUITests/QirimKeyUITests/testAppStorePreviewVideoScenario -parallel-testing-enabled NO -jobs 4)
if [ "${SKIP_WARMUP:-0}" != "1" ]; then echo "== warm-up"; run_with_timeout "${WARMUP_TIMEOUT:-900}" xcodebuild test "${ARGS[@]}" -resultBundlePath /tmp/qk_warm.xcresult -quiet >/tmp/qk_warm.log 2>&1; echo "WARMUP_RC=$?"; fi
xcrun simctl terminate "$UDID" com.apple.Preferences >/dev/null 2>&1
sleep 1
echo "== record"
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$RAW" >/dev/null 2>&1 &
REC=$!
sleep 1.5
run_with_timeout "${TEST_TIMEOUT:-420}" xcodebuild test-without-building "${ARGS[@]}" -resultBundlePath /tmp/qk_rec.xcresult -quiet >/tmp/qk_rec.log 2>&1; echo "TEST_RC=$?"
kill -INT "$REC" 2>/dev/null; wait "$REC" 2>/dev/null; sleep 1
ls -lh "$RAW"
echo "== transcode"
swift QTatar/Scripts/transcode_live_preview.swift "$RAW" "$OUT" "$W" "$H" "/tmp/qk_kf_${UDID:0:8}" 2>&1 | grep -E "^Transcoded|error:"
ls -lh "$OUT"
echo "RECORD_DONE"
