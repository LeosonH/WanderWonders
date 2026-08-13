#!/usr/bin/env bash
set -euo pipefail

DB_URL="postgresql://postgres:postgres@127.0.0.1:55322/postgres"
CAP_USER="00000000-0000-0000-0000-000000000601"
CAP_SESSION_A="00000000-0000-0000-0000-000000000610"
CAP_SESSION_B="00000000-0000-0000-0000-000000000611"
CAP_REQUEST_A="00000000-0000-0000-0000-000000000612"
CAP_REQUEST_B="00000000-0000-0000-0000-000000000613"
CAP_RETRY="00000000-0000-0000-0000-000000000614"
TELEMETRY_USER="00000000-0000-0000-0000-000000000602"
TEMP_DIR="$(mktemp -d /private/tmp/wonder-adversarial.XXXXXX)"

cleanup() {
    PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -qAtc \
        "delete from auth.users where id in ('$CAP_USER'::uuid, '$TELEMETRY_USER'::uuid);" \
        >/dev/null 2>&1 || true
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -qAt <<'SQL'
insert into auth.users (id)
values
    ('00000000-0000-0000-0000-000000000601'::uuid),
    ('00000000-0000-0000-0000-000000000602'::uuid);

insert into public.wonder_profiles (user_id)
values
    ('00000000-0000-0000-0000-000000000601'::uuid),
    ('00000000-0000-0000-0000-000000000602'::uuid);

insert into public.wonder_player_settings (user_id, time_zone)
values
    ('00000000-0000-0000-0000-000000000601'::uuid, 'UTC'),
    ('00000000-0000-0000-0000-000000000602'::uuid, 'UTC');

do $setup$
declare
    v_index integer;
    v_session uuid;
    v_flower uuid;
    v_species uuid := (
        select species_id from public.wonder_species where slug = 'aster'
    );
    v_start timestamptz := clock_timestamp() - interval '10 minutes';
    v_date date := (v_start at time zone 'UTC')::date;
begin
    for v_index in 1..5 loop
        v_session := gen_random_uuid();
        v_flower := gen_random_uuid();
        insert into public.wonder_wander_sessions (
            session_id, user_id, start_utc, end_utc, auto_close_utc,
            local_date, time_zone, mode, state, offline,
            catalog_version, catalog_checksum, offer_season, earned_count
        ) values (
            v_session,
            '00000000-0000-0000-0000-000000000601'::uuid,
            v_start,
            v_start + interval '10 minutes',
            v_start + interval '1 hour',
            v_date,
            'UTC',
            'offline',
            'closed',
            true,
            1,
            wonder_private.wonder_catalog_checksum(1),
            'autumn',
            1
        );
        insert into public.wonder_flower_instances (
            flower_id, user_id, species_id, source, session_id, tier,
            acquired_at, duration_seconds, deadline_utc
        ) values (
            v_flower,
            '00000000-0000-0000-0000-000000000601'::uuid,
            v_species,
            'wander',
            v_session,
            10,
            v_start + interval '10 minutes',
            259200,
            v_start + interval '3 days 10 minutes'
        );
        insert into public.wonder_wander_rewards (
            user_id, session_id, tier, status, resolution_mode,
            selected_species_id, flower_id, reached_at, resolved_at
        ) values (
            '00000000-0000-0000-0000-000000000601'::uuid,
            v_session,
            10,
            'awarded',
            'player_choice',
            v_species,
            v_flower,
            v_start + interval '10 minutes',
            v_start + interval '10 minutes'
        );
    end loop;
end;
$setup$;

insert into public.wonder_product_events (
    user_id, event_name, occurred_at_utc, local_date, time_zone
)
select
    '00000000-0000-0000-0000-000000000602'::uuid,
    'wander_started',
    timezone('utc', clock_timestamp()),
    (timezone('utc', clock_timestamp()))::date,
    'UTC'
from generate_series(1, 199);
SQL

run_offline() {
    local session_id="$1"
    local request_id="$2"
    local expected_revision="$3"
    local output_path="$4"
    PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -qAtc \
        "select set_config('request.jwt.claim.sub', '$CAP_USER', false);
         with input as (
             select clock_timestamp() - interval '10 minutes' as start_utc
         ), eligible as (
             select s.slug,
                    extensions.digest(
                        extensions.digest(convert_to('$session_id:1:autumn', 'UTF8'), 'sha256')
                        || convert_to(':' || s.slug, 'UTF8'),
                        'sha256'
                    ) as sort_key
             from public.wonder_species s
             where s.source = 'wander' and s.season = 'autumn' and s.active
         ), offers as (
             select array_agg(slug order by sort_key, slug) as slugs
             from (
                 select slug, sort_key
                 from eligible
                 order by sort_key, slug
                 limit 3
             ) selected
         )
         select public.wonder_sync_offline_wander(
             '$session_id'::uuid,
             input.start_utc,
             (input.start_utc at time zone 'UTC')::date,
             'UTC',
             1,
             wonder_private.wonder_catalog_checksum(1),
             offers.slugs,
             jsonb_build_array(jsonb_build_object(
                 'tier', 10,
                 'species_slug', offers.slugs[1],
                 'elapsed_seconds', 600
             )),
             $expected_revision,
             '$request_id'::uuid
         )
         from input cross join offers;" >"$output_path"
}

run_offline "$CAP_SESSION_A" "$CAP_REQUEST_A" 0 "$TEMP_DIR/cap-a.out" &
CAP_PID_A=$!
run_offline "$CAP_SESSION_B" "$CAP_REQUEST_B" 0 "$TEMP_DIR/cap-b.out" &
CAP_PID_B=$!
wait "$CAP_PID_A"
wait "$CAP_PID_B"

CAP_AWARDED="$(PGPASSWORD=postgres psql "$DB_URL" -qAtc \
    "select count(*) from public.wonder_wander_rewards
     where user_id = '$CAP_USER'::uuid and status = 'awarded';")"
CAP_SUCCESS="$(PGPASSWORD=postgres psql "$DB_URL" -qAtc \
    "select count(*) from public.wonder_idempotency_keys
     where user_id = '$CAP_USER'::uuid
       and request_id in ('$CAP_REQUEST_A'::uuid, '$CAP_REQUEST_B'::uuid)
       and response_json->>'ok' = 'true';")"
CAP_STALE="$(PGPASSWORD=postgres psql "$DB_URL" -qAtc \
    "select count(*) from public.wonder_idempotency_keys
     where user_id = '$CAP_USER'::uuid
       and request_id in ('$CAP_REQUEST_A'::uuid, '$CAP_REQUEST_B'::uuid)
       and response_json->'error'->>'code' = 'WW_STALE_REVISION';")"

if [[ "$CAP_AWARDED" != "6" || "$CAP_SUCCESS" != "1" || "$CAP_STALE" != "1" ]]; then
    printf 'unexpected contested cap result: awarded=%s success=%s stale=%s\n' \
        "$CAP_AWARDED" "$CAP_SUCCESS" "$CAP_STALE" >&2
    exit 1
fi

run_offline "$CAP_SESSION_B" "$CAP_RETRY" 1 "$TEMP_DIR/cap-retry.out"
CAP_AFTER_RETRY="$(PGPASSWORD=postgres psql "$DB_URL" -qAtc \
    "select count(*) from public.wonder_wander_rewards
     where user_id = '$CAP_USER'::uuid and status = 'awarded';")"
CAP_REJECTED="$(PGPASSWORD=postgres psql "$DB_URL" -qAtc \
    "select count(*) from public.wonder_wander_rewards
     where user_id = '$CAP_USER'::uuid
       and session_id = '$CAP_SESSION_B'::uuid
       and status = 'rejected'
       and rejection_code = 'WW_DAILY_FLOWER_CAP';")"
if [[ "$CAP_AFTER_RETRY" != "6" || "$CAP_REJECTED" != "1" ]]; then
    printf 'unexpected cap retry result: awarded=%s rejected=%s\n' \
        "$CAP_AFTER_RETRY" "$CAP_REJECTED" >&2
    exit 1
fi

run_telemetry() {
    local output_path="$1"
    PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -qAtc \
        "select set_config('request.jwt.claim.sub', '$TELEMETRY_USER', false);
         select public.wonder_record_ui_event('wander_started');" >"$output_path"
}

run_telemetry "$TEMP_DIR/telemetry-a.out" &
TELEMETRY_PID_A=$!
run_telemetry "$TEMP_DIR/telemetry-b.out" &
TELEMETRY_PID_B=$!
wait "$TELEMETRY_PID_A"
wait "$TELEMETRY_PID_B"

TELEMETRY_ACCEPTED="$(rg -l '"accepted": true' "$TEMP_DIR"/telemetry-*.out | wc -l | tr -d ' ')"
TELEMETRY_REJECTED="$(rg -l '"accepted": false' "$TEMP_DIR"/telemetry-*.out | wc -l | tr -d ' ')"
TELEMETRY_COUNT="$(PGPASSWORD=postgres psql "$DB_URL" -qAtc \
    "select count(*) from public.wonder_product_events
     where user_id = '$TELEMETRY_USER'::uuid;")"
if [[ "$TELEMETRY_ACCEPTED" != "1" || "$TELEMETRY_REJECTED" != "1" || "$TELEMETRY_COUNT" != "200" ]]; then
    printf 'unexpected telemetry cap result: accepted=%s rejected=%s rows=%s\n' \
        "$TELEMETRY_ACCEPTED" "$TELEMETRY_REJECTED" "$TELEMETRY_COUNT" >&2
    exit 1
fi

printf 'adversarial probes verified: contested_awarded=%s contested_stale=%s cap_rejected=%s telemetry_rows=%s\n' \
    "$CAP_AFTER_RETRY" "$CAP_STALE" "$CAP_REJECTED" "$TELEMETRY_COUNT"
