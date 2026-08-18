#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
MODE="${1:---full}"

CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift Scripts/generate_wonder_seed.swift \
    Content/flower_catalog.v1.json --check
CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift Scripts/validate_wonder_assets.swift \
    Content/wonder_asset_manifest.v1.json Content/flower_catalog.v1.json

deno fmt --check --config supabase/functions/deno.json supabase/functions
deno lint --config supabase/functions/deno.json supabase/functions
deno check --config supabase/functions/deno.json \
    supabase/functions/wonder-park-check/index.ts \
    supabase/functions/wonder-delete-account/index.ts
deno test --config supabase/functions/deno.json --allow-env supabase/functions

if rg -n '(SUPABASE_SECRET_KEY|GOOGLE_PLACES_API_KEY|APPLE_MAPS_PRIVATE_KEY_P8|APPLE_PRIVATE_KEY_P8)[[:space:]]*=[[:space:]]*[^[:space:]]+' \
    . --glob '!supabase/.temp/**' --glob '!*.md'; then
    printf 'secret-like configured value found\n' >&2
    exit 1
fi
if rg -n 'StoreKit|subscription|in-app purchase|Spring|Summer|Winter|TODO|FIXME|placeholder' \
    WanderWonders; then
    printf 'out-of-scope or placeholder source found\n' >&2
    exit 1
fi
plutil -lint WanderWonders/Resources/PrivacyInfo.xcprivacy WanderWonders/WanderWonders.entitlements

Scripts/build_wander.sh

if [[ "$MODE" == "--code-only" ]]; then
    printf 'code-only checks passed; database evidence is unchanged and full art/release gates remain separate\n'
    exit 0
fi

Scripts/start_wonder_local.sh
trap 'Scripts/stop_wonder_local.sh >/dev/null 2>&1 || true' EXIT
Scripts/reset_wonder_local.sh
supabase test db --local --workdir "$ROOT_DIR"
supabase db lint --local --level error --workdir "$ROOT_DIR"
PGPASSWORD=postgres psql postgresql://postgres:postgres@127.0.0.1:55322/postgres \
    -f Scripts/audit_wonder_schema.sql
Scripts/verify_wonder_concurrency.sh
Scripts/verify_wonder_adversarial.sh
Scripts/verify_wonder_role_timeouts.sh

CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift Scripts/validate_wonder_assets.swift \
    Content/wonder_asset_manifest.v1.json Content/flower_catalog.v1.json --check-files
xcodebuild -project WanderWonders.xcodeproj -scheme WanderWonders \
    -configuration Release -destination 'generic/platform=iOS' \
    -archivePath .build/WanderWonders.xcarchive \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO archive

printf 'full local release checks passed\n'
