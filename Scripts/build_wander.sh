#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

xcodegen generate --spec project.yml

DESTINATION="${WW_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=latest}"
COMMON_ARGS=(
    -project WanderWonders.xcodeproj
    -scheme WanderWonders
    -destination "$DESTINATION"
    -derivedDataPath .build/DerivedData
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
)

xcodebuild "${COMMON_ARGS[@]}" -configuration Debug build
xcodebuild "${COMMON_ARGS[@]}" -configuration Release build
xcodebuild "${COMMON_ARGS[@]}" -configuration Debug test
