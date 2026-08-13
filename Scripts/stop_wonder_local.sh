#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v supabase >/dev/null 2>&1; then
    echo "BLOCKED: Supabase CLI is unavailable." >&2
    exit 78
fi

if command -v docker >/dev/null 2>&1; then
    DOCKER_BIN="$(command -v docker)"
elif [[ -x /Applications/Docker.app/Contents/Resources/bin/docker ]]; then
    DOCKER_BIN="/Applications/Docker.app/Contents/Resources/bin/docker"
else
    echo "BLOCKED: Docker is unavailable; local Supabase cannot stop." >&2
    exit 78
fi

export PATH="$(dirname "$DOCKER_BIN"):$PATH"
SUPABASE_TELEMETRY_DISABLED=1 supabase stop \
    --project-id wander_wonders_v1_local \
    --workdir "$ROOT_DIR"
