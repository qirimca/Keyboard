#!/bin/bash

# Update build timestamp in BuildInfo.swift
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DATE=$(date '+%Y-%m-%d %H:%M')
BUILD_FILE="$SCRIPT_DIR/Demo/Demo/BuildInfo.swift"

if [ -f "$BUILD_FILE" ]; then
    sed -i '' -E "s/static let buildDate = \".*\"/static let buildDate = \"$BUILD_DATE\"/" "$BUILD_FILE"
    echo "Build timestamp updated: $BUILD_DATE"
else
    echo "BuildInfo.swift not found at $BUILD_FILE!"
fi