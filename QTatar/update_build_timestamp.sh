#!/bin/bash

# Update build timestamp in BuildInfo.swift
BUILD_DATE=$(date '+%Y-%m-%d %H:%M:%S')
BUILD_FILE="Demo/Demo/BuildInfo.swift"

if [ -f "$BUILD_FILE" ]; then
    # Replace placeholder with actual timestamp
    sed -i '' "s/BUILD_TIMESTAMP_PLACEHOLDER/$BUILD_DATE/g" "$BUILD_FILE"
    echo "Build timestamp updated: $BUILD_DATE"
else
    echo "BuildInfo.swift not found!"
fi