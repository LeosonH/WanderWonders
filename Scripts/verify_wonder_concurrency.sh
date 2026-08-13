#!/usr/bin/env bash
set -euo pipefail

DB_URL="postgresql://postgres:postgres@127.0.0.1:55322/postgres"
USER_ID="00000000-0000-0000-0000-000000000301"
REQUEST_A="00000000-0000-0000-0000-000000000302"
REQUEST_B="00000000-0000-0000-0000-000000000303"
REQUEST_LOCK="00000000-0000-0000-0000-000000000304"
TEMP_DIR="$(mktemp -d /private/tmp/wonder-concurrency.XXXXXX)"

cleanup() {
    PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -qAtc \
        "delete from auth.users where id = '$USER_ID'::uuid;" >/dev/null 2>&1 || true
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -qAtc \
    "delete from auth.users where id = '$USER_ID'::uuid;
     insert into auth.users (id) values ('$USER_ID'::uuid);
     insert into public.wonder_profiles (user_id) values ('$USER_ID'::uuid);" >/dev/null

(
    PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -qAtc \
        "begin;
         select pg_advisory_xact_lock(hashtextextended('$USER_ID', 0));
         select pg_sleep(2);
         commit;" >"$TEMP_DIR/holder.out"
) &
HOLDER_PID=$!
/bin/sleep 0.2

run_step_sync() {
    local request_id="$1"
    local output_path="$2"
    PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -qAtc \
        "select set_config('request.jwt.claim.sub', '$USER_ID', false);
         select public.wonder_sync_steps(current_date, 'UTC', 100, 0, 'health', 0, '$request_id'::uuid);" \
        >"$output_path"
}

run_step_sync "$REQUEST_A" "$TEMP_DIR/a.out" &
CALL_A_PID=$!
run_step_sync "$REQUEST_B" "$TEMP_DIR/b.out" &
CALL_B_PID=$!
wait "$CALL_A_PID"
wait "$CALL_B_PID"
wait "$HOLDER_PID"

SUCCESS_COUNT=$(PGPASSWORD=postgres psql "$DB_URL" -qAtc \
    "select count(*) from public.wonder_idempotency_keys
     where user_id = '$USER_ID'::uuid and response_json->>'ok' = 'true';")
STALE_COUNT=$(PGPASSWORD=postgres psql "$DB_URL" -qAtc \
    "select count(*) from public.wonder_idempotency_keys
     where user_id = '$USER_ID'::uuid and response_json->'error'->>'code' = 'WW_STALE_REVISION';")
REVISION=$(PGPASSWORD=postgres psql "$DB_URL" -qAtc \
    "select state_revision from public.wonder_profiles where user_id = '$USER_ID'::uuid;")
LEDGER_COUNT=$(PGPASSWORD=postgres psql "$DB_URL" -qAtc \
    "select count(*) from public.wonder_glow_ledger where user_id = '$USER_ID'::uuid;")

if [[ "$SUCCESS_COUNT" != "1" || "$STALE_COUNT" != "1" || "$REVISION" != "1" || "$LEDGER_COUNT" != "1" ]]; then
    printf 'unexpected serialized result: success=%s stale=%s revision=%s ledger=%s\n' \
        "$SUCCESS_COUNT" "$STALE_COUNT" "$REVISION" "$LEDGER_COUNT" >&2
    exit 1
fi

(
    PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -qAtc \
        "begin;
         select pg_advisory_xact_lock(hashtextextended('$USER_ID', 0));
         select pg_sleep(3);
         commit;" >"$TEMP_DIR/lock-holder.out"
) &
HOLDER_PID=$!
/bin/sleep 0.2

if PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -qAtc \
    "select set_config('request.jwt.claim.sub', '$USER_ID', false);
     select public.wonder_sync_steps(current_date, 'UTC', 200, 0, 'health', 1, '$REQUEST_LOCK'::uuid);" \
    >"$TEMP_DIR/lock-call.out" 2>&1; then
    wait "$HOLDER_PID"
    printf 'lock timeout probe unexpectedly succeeded\n' >&2
    exit 1
fi
wait "$HOLDER_PID"

if ! rg -q 'lock timeout|55P03' "$TEMP_DIR/lock-call.out"; then
    printf 'lock timeout probe did not report SQLSTATE 55P03\n' >&2
    exit 1
fi

printf 'serialized concurrency and lock timeout verified: success=%s stale=%s revision=%s ledger=%s\n' \
    "$SUCCESS_COUNT" "$STALE_COUNT" "$REVISION" "$LEDGER_COUNT"
