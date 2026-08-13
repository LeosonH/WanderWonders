#!/usr/bin/env bash
set -euo pipefail

DB_URL="postgresql://postgres:postgres@127.0.0.1:55322/postgres"
USER_ID="00000000-0000-0000-0000-000000000401"
SESSION_ID="00000000-0000-0000-0000-000000000402"
REQUEST_ID="00000000-0000-0000-0000-000000000403"
TEMP_DIR="$(mktemp -d /private/tmp/wonder-role-timeouts.XXXXXX)"

status_env="$(SUPABASE_TELEMETRY_DISABLED=1 supabase status -o env 2>/dev/null)"
value_for() {
    printf '%s\n' "$status_env" | sed -n "s/^$1=//p" | sed 's/^"//; s/"$//' | head -n 1
}

API_URL="$(value_for API_URL)"
ANON_KEY="$(value_for ANON_KEY)"
SERVICE_ROLE_KEY="$(value_for SERVICE_ROLE_KEY)"
JWT_SECRET="$(value_for JWT_SECRET)"

if [[ -z "$API_URL" || -z "$ANON_KEY" || -z "$SERVICE_ROLE_KEY" || -z "$JWT_SECRET" ]]; then
    printf 'local Supabase status did not provide the required probe values\n' >&2
    exit 1
fi

drop_probe() {
    PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -qAtc \
        "drop function if exists public.wonder_timeout_probe();" >/dev/null
}

cleanup() {
    drop_probe >/dev/null 2>&1 || true
    PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -qAtc \
        "delete from auth.users where id = '$USER_ID'::uuid;
         delete from public.wonder_species
         where species_id in (
           '00000000-0000-0000-0000-000000000411'::uuid,
           '00000000-0000-0000-0000-000000000412'::uuid,
           '00000000-0000-0000-0000-000000000413'::uuid
         );" >/dev/null 2>&1 || true
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -qAtc \
    "delete from auth.users where id = '$USER_ID'::uuid;
     insert into auth.users (id) values ('$USER_ID'::uuid);
     insert into public.wonder_profiles (user_id) values ('$USER_ID'::uuid);
     insert into public.wonder_app_config (config_key, config_value, version)
     values ('catalog_version', '{\"season\":\"autumn\"}'::jsonb, 1)
     on conflict (config_key) do update set config_value = excluded.config_value, version = excluded.version;
     insert into public.wonder_species (species_id, slug, common_name, source, season, bloom_duration_seconds, offer_weight, living_asset_key, fading_asset_key, pressed_asset_key, introduced_catalog_version)
     values
       ('00000000-0000-0000-0000-000000000411'::uuid, 'timeout_a', 'Timeout A', 'wander', 'autumn', 259200, 100, 'timeout_a_living', 'timeout_a_fading', 'timeout_a_pressed', 1),
       ('00000000-0000-0000-0000-000000000412'::uuid, 'timeout_b', 'Timeout B', 'wander', 'autumn', 259200, 100, 'timeout_b_living', 'timeout_b_fading', 'timeout_b_pressed', 1),
       ('00000000-0000-0000-0000-000000000413'::uuid, 'timeout_c', 'Timeout C', 'wander', 'autumn', 259200, 100, 'timeout_c_living', 'timeout_c_fading', 'timeout_c_pressed', 1)
     on conflict (species_id) do nothing;
     create or replace function public.wonder_timeout_probe()
     returns text language plpgsql security invoker set search_path = ''
     as \$timeout\$
     begin
         perform pg_catalog.pg_sleep(6);
         return 'ok';
     end;
     \$timeout\$;
     grant execute on function public.wonder_timeout_probe() to authenticated, service_role;
     notify pgrst, 'reload schema';" >/dev/null
/bin/sleep 1

b64url() {
    printf '%s' "$1" | openssl base64 -A | tr '+/' '-_' | tr -d '='
}

NOW_SECONDS="$(date +%s)"
JWT_HEADER="$(b64url '{"alg":"HS256","typ":"JWT"}')"
JWT_PAYLOAD="$(b64url "{\"role\":\"authenticated\",\"sub\":\"$USER_ID\",\"aud\":\"authenticated\",\"iat\":$NOW_SECONDS,\"exp\":$((NOW_SECONDS + 600))}")"
JWT_INPUT="$JWT_HEADER.$JWT_PAYLOAD"
JWT_SIGNATURE="$(printf '%s' "$JWT_INPUT" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')"
AUTH_TOKEN="$JWT_INPUT.$JWT_SIGNATURE"

call_rpc() {
    local rpc_name="$1"
    local api_key="$2"
    local bearer="$3"
    local request_body="$4"
    local response_path="$5"
    curl -sS --max-time 12 \
        -o "$response_path" \
        -w '%{http_code} %{time_total}' \
        -X POST "$API_URL/rest/v1/rpc/$rpc_name" \
        -H "apikey: $api_key" \
        -H "Authorization: Bearer $bearer" \
        -H 'Content-Type: application/json' \
        --data "$request_body"
}

AUTH_TIMEOUT_META="$(call_rpc wonder_timeout_probe "$ANON_KEY" "$AUTH_TOKEN" '{}' "$TEMP_DIR/auth-timeout.json")"
SERVICE_TIMEOUT_META="$(call_rpc wonder_timeout_probe "$SERVICE_ROLE_KEY" "$SERVICE_ROLE_KEY" '{}' "$TEMP_DIR/service-timeout.json")"

check_timeout() {
    local metadata="$1"
    local body_path="$2"
    read -r status duration <<< "$metadata"
    if [[ "$status" != "500" ]]; then
        printf 'timeout probe returned HTTP %s in %s seconds: ' "$status" "$duration" >&2
        sed 's/[[:space:]]\+/ /g' "$body_path" >&2
        return 1
    fi
    if ! awk -v seconds="$duration" 'BEGIN { exit !(seconds >= 4.0 && seconds <= 8.5) }'; then
        printf 'timeout probe completed outside the five-second window: %s seconds\n' "$duration" >&2
        return 1
    fi
    if ! rg -qi 'statement timeout|canceling statement' "$body_path"; then
        printf 'timeout probe response did not identify statement timeout\n' >&2
        return 1
    fi
}

check_timeout "$AUTH_TIMEOUT_META" "$TEMP_DIR/auth-timeout.json"
check_timeout "$SERVICE_TIMEOUT_META" "$TEMP_DIR/service-timeout.json"

NORMAL_META="$(call_rpc wonder_refresh_state "$ANON_KEY" "$AUTH_TOKEN" '{}' "$TEMP_DIR/normal.json")"
read -r NORMAL_STATUS NORMAL_DURATION <<< "$NORMAL_META"
if [[ "$NORMAL_STATUS" != "200" ]]; then printf 'normal RPC returned HTTP %s in %s seconds\n' "$NORMAL_STATUS" "$NORMAL_DURATION" >&2; exit 1; fi
if ! awk -v seconds="$NORMAL_DURATION" 'BEGIN { exit !(seconds < 4.0) }'; then printf 'normal RPC exceeded the budget: %s seconds\n' "$NORMAL_DURATION" >&2; exit 1; fi
if ! rg -q '"ok": true' "$TEMP_DIR/normal.json"; then printf 'normal RPC did not return ok=true\n' >&2; exit 1; fi

CURRENT_REVISION="$(PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -qAtc \
    "select state_revision from public.wonder_profiles where user_id = '$USER_ID'::uuid;")"
VERIFIED_BODY="$(printf '%s' "{\"p_user_id\":\"$USER_ID\",\"p_session_id\":\"$SESSION_ID\",\"p_time_zone\":\"UTC\",\"p_expected_revision\":$CURRENT_REVISION,\"p_idempotency_key\":\"$REQUEST_ID\",\"p_allow_zero_reward\":false}")"
VERIFIED_META="$(call_rpc wonder_start_verified_wander_internal "$SERVICE_ROLE_KEY" "$SERVICE_ROLE_KEY" "$VERIFIED_BODY" "$TEMP_DIR/verified.json")"
read -r VERIFIED_STATUS VERIFIED_DURATION <<< "$VERIFIED_META"
if [[ "$VERIFIED_STATUS" != "200" ]]; then printf 'verified RPC returned HTTP %s in %s seconds\n' "$VERIFIED_STATUS" "$VERIFIED_DURATION" >&2; exit 1; fi
if ! awk -v seconds="$VERIFIED_DURATION" 'BEGIN { exit !(seconds < 4.0) }'; then printf 'verified RPC exceeded the budget: %s seconds\n' "$VERIFIED_DURATION" >&2; exit 1; fi
if ! rg -q '"ok": true' "$TEMP_DIR/verified.json"; then
    printf 'verified RPC did not return ok=true: ' >&2
    sed 's/[[:space:]]\+/ /g' "$TEMP_DIR/verified.json" >&2
    exit 1
fi

drop_probe

printf 'role timeout probes verified: authenticated=%s service_role=%s normal=%s verified=%s\n' \
    "$AUTH_TIMEOUT_META" "$SERVICE_TIMEOUT_META" "$NORMAL_META" "$VERIFIED_META"
