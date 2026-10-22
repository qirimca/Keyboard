#!/bin/bash

# Only update build timestamp in Release builds (or when explicitly requested) so Debug/test builds keep git clean
if [ "${CONFIGURATION:-Debug}" != "Release" ] && [ "${FORCE_BUILD_TIMESTAMP:-0}" != "1" ]; then
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DATE=$(date '+%Y-%m-%d %H:%M')
BUILD_FILE="$SCRIPT_DIR/Demo/Demo/BuildInfo.swift"

if [ -f "$BUILD_FILE" ]; then
    sed -i '' -E "s/static let buildDate = \".*\"/static let buildDate = \"$BUILD_DATE\"/" "$BUILD_FILE"
    echo "Build timestamp updated: $BUILD_DATE"
else
    echo "BuildInfo.swift not found at $BUILD_FILE!"
fi