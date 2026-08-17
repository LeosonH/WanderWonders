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

if [[ -f Config/Secrets.xcconfig ]]; then
    APP_INFO_PLIST=.build/DerivedData/Build/Products/Debug-iphonesimulator/WanderWonders.app/Info.plist
    WW_BUILT_SUPABASE_URL=$(/usr/libexec/PlistBuddy -c 'Print :WWSupabaseURL' "$APP_INFO_PLIST")
    WW_BUILT_PUBLISHABLE_KEY=$(/usr/libexec/PlistBuddy -c 'Print :WWSupabasePublishableKey' "$APP_INFO_PLIST")
    [[ "$WW_BUILT_SUPABASE_URL" == https://*.supabase.co ]]
    [[ "$WW_BUILT_PUBLISHABLE_KEY" == sb_publishable_* ]]
    printf 'runtime configuration embedded in app bundle\n'
fi

xcodebuild "${COMMON_ARGS[@]}" -configuration Release build
xcodebuild "${COMMON_ARGS[@]}" -configuration Debug test
