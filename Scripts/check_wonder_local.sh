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
    echo "BLOCKED: Docker is unavailable; local Supabase reset cannot run." >&2
    exit 78
fi

if [[ -e supabase/.temp/project-ref ]]; then
    echo "BLOCKED: local checkout contains a Supabase link marker; remove it only through an owner-authorized isolated workflow." >&2
    exit 78
fi

SUPABASE_TELEMETRY_DISABLED=1 supabase --version
"$DOCKER_BIN" info >/dev/null
echo "Local Supabase prerequisites are available and no link marker is present."
