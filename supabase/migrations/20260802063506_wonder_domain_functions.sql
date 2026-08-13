begin;

create type wonder_private.wonder_idempotency_result as (
    replayed boolean,
    response_json jsonb
);

create type wonder_private.wonder_reconcile_state as (
    changed boolean,
    session_state text,
    elapsed_seconds integer,
    earliest_unresolved_tier integer,
    auto_awarded_flower uuid
);

create type wonder_private.wonder_glow_result as (
    entry_id uuid,
    balance_after integer
);

create or replace function wonder_private.wonder_error(
    p_code text,
    p_message text,
    p_request_id uuid,
    p_retryable boolean,
    p_state_revision bigint,
    p_details jsonb default '{}'::jsonb
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
    select pg_catalog.jsonb_build_object(
        'ok', false,
        'error', pg_catalog.jsonb_build_object(
            'code', p_code,
            'message', p_message,
            'request_id', p_request_id,
            'retryable', p_retryable,
            'state_revision', p_state_revision,
            'details', p_details
        )
    );
$$;

create or replace function wonder_private.wonder_require_user()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := (select auth.uid());
begin
    if v_user_id is null then
        raise exception 'WW_AUTH_REQUIRED' using errcode = '42501';
    end if;
    return v_user_id;
end;
$$;

create or replace function public.wonder_reconcile_wander(
    p_session_id uuid,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_session public.wonder_wander_sessions%rowtype;
    v_reconcile wonder_private.wonder_reconcile_state;
    v_base bigint;
    v_revision bigint;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_changed boolean := false;
    v_response jsonb;
    v_rewards jsonb;
begin
    if v_user_id is null then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to restore Wander progress.', p_idempotency_key, false, 0);
    end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before restoring Wander progress.', p_idempotency_key, false, 0);
    end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(
        v_user_id, p_idempotency_key, 'wonder_reconcile_wander',
        pg_catalog.jsonb_build_object('session_id', p_session_id, 'expected_revision', p_expected_revision)
    );
    if v_idempotency.replayed then
        return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base));
    end if;
    if p_expected_revision is null or p_expected_revision <> v_base then
        v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;

    v_reconcile := wonder_private.wonder_reconcile_session(v_user_id, p_session_id, v_now);
    if v_reconcile.changed then v_changed := true; end if;
    select * into v_session
    from public.wonder_wander_sessions
    where user_id = v_user_id and session_id = p_session_id
    for update;
    if v_reconcile.elapsed_seconds > v_session.elapsed_high_water_seconds then
        update public.wonder_wander_sessions
        set elapsed_high_water_seconds = v_reconcile.elapsed_seconds
        where user_id = v_user_id and session_id = p_session_id;
        v_changed := true;
    end if;
    if v_changed then
        v_revision := wonder_private.wonder_increment_revision(v_user_id);
    else
        v_revision := v_base;
    end if;

    select coalesce(
        pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by r.tier), '[]'::jsonb
    ) into v_rewards
    from public.wonder_wander_rewards r
    where r.user_id = v_user_id and r.session_id = p_session_id;
    v_response := wonder_private.wonder_mutation_response(
        p_idempotency_key, v_base, v_revision, false,
        pg_catalog.jsonb_build_object(
            'session_id', p_session_id,
            'server_now', v_now,
            'authoritative_elapsed_seconds', v_reconcile.elapsed_seconds,
            'session_state', v_reconcile.session_state,
            'tier_states', v_rewards,
            'earliest_unresolved_tier', v_reconcile.earliest_unresolved_tier,
            'auto_awarded_flower', v_reconcile.auto_awarded_flower
        )
    );
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
    return v_response;
end;
$$;

create or replace function public.wonder_choose_wander_reward(
    p_session_id uuid,
    p_tier integer,
    p_species_slug text,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_reward public.wonder_wander_rewards%rowtype;
    v_session public.wonder_wander_sessions%rowtype;
    v_offer public.wonder_wander_offers%rowtype;
    v_reconcile wonder_private.wonder_reconcile_state;
    v_flower_id uuid;
    v_base bigint;
    v_revision bigint;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_response jsonb;
begin
    if v_user_id is null then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to choose a flower.', p_idempotency_key, false, 0);
    end if;
    if p_tier not in (10, 20) or p_species_slug is null or length(btrim(p_species_slug)) = 0 then
        return wonder_private.wonder_error('WW_INVALID_REQUEST', 'Choose a valid reached flower tier.', p_idempotency_key, false, 0);
    end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before choosing a flower.', p_idempotency_key, false, 0);
    end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(
        v_user_id, p_idempotency_key, 'wonder_choose_wander_reward',
        pg_catalog.jsonb_build_object('session_id', p_session_id, 'tier', p_tier, 'species_slug', p_species_slug, 'expected_revision', p_expected_revision)
    );
    if v_idempotency.replayed then
        return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base));
    end if;
    if p_expected_revision is null or p_expected_revision <> v_base then
        v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;

    v_reconcile := wonder_private.wonder_reconcile_session(v_user_id, p_session_id, v_now);
    if v_reconcile.changed then null; end if;
    select * into v_session from public.wonder_wander_sessions where user_id = v_user_id and session_id = p_session_id for update;
    if v_reconcile.elapsed_seconds > v_session.elapsed_high_water_seconds then
        update public.wonder_wander_sessions set elapsed_high_water_seconds = v_reconcile.elapsed_seconds where user_id = v_user_id and session_id = p_session_id;
    end if;
    select * into v_reward
    from public.wonder_wander_rewards
    where user_id = v_user_id and session_id = p_session_id and tier = p_tier
    for update;
    if not found or v_reward.status <> 'pending_resolution' then
        v_response := wonder_private.wonder_error('WW_TIER_NOT_REACHED', 'That flower tier is not ready to choose.', p_idempotency_key, true, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;
    select * into v_offer
    from public.wonder_wander_offers
    where user_id = v_user_id and session_id = p_session_id and species_slug = p_species_slug;
    if not found or exists (
        select 1 from public.wonder_wander_rewards
        where user_id = v_user_id and session_id = p_session_id
          and selected_species_id = v_offer.species_id and status = 'awarded'
    ) then
        v_response := wonder_private.wonder_error('WW_CATALOG_MISMATCH', 'Choose one of the original available offers.', p_idempotency_key, false, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;

    v_flower_id := wonder_private.wonder_award_flower(
        v_user_id, v_offer.species_id, 'wander', p_session_id, p_tier,
        v_now, v_session.time_zone, v_session.local_date
    );
    update public.wonder_wander_rewards
    set status = 'awarded', selected_species_id = v_offer.species_id,
        flower_id = v_flower_id, idempotency_key = p_idempotency_key,
        resolved_at = v_now
    where user_id = v_user_id and session_id = p_session_id and tier = p_tier;
    update public.wonder_wander_sessions
    set earned_count = earned_count + 1
    where user_id = v_user_id and session_id = p_session_id;
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(
        p_idempotency_key, v_base, v_revision, false,
        pg_catalog.jsonb_build_object(
            'session_id', p_session_id,
            'tier', p_tier,
            'reward', (select pg_catalog.to_jsonb(r) from public.wonder_wander_rewards r where r.user_id = v_user_id and r.session_id = p_session_id and r.tier = p_tier),
            'flower', (select pg_catalog.to_jsonb(f) from public.wonder_flower_instances f where f.user_id = v_user_id and f.flower_id = v_flower_id)
        )
    );
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
    return v_response;
end;
$$;

create or replace function public.wonder_end_wander(
    p_session_id uuid,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_session public.wonder_wander_sessions%rowtype;
    v_reconcile wonder_private.wonder_reconcile_state;
    v_base bigint;
    v_revision bigint;
    v_changed boolean := false;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_response jsonb;
    v_rewards jsonb;
begin
    if v_user_id is null then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to end a Wander.', p_idempotency_key, false, 0);
    end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before ending a Wander.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(
        v_user_id, p_idempotency_key, 'wonder_end_wander',
        pg_catalog.jsonb_build_object('session_id', p_session_id, 'expected_revision', p_expected_revision)
    );
    if v_idempotency.replayed then
        return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base));
    end if;
    if p_expected_revision is null or p_expected_revision <> v_base then
        v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;
    v_reconcile := wonder_private.wonder_reconcile_session(v_user_id, p_session_id, v_now);
    if v_reconcile.changed then v_changed := true; end if;
    select * into v_session from public.wonder_wander_sessions where user_id = v_user_id and session_id = p_session_id for update;
    if not found then
        v_response := wonder_private.wonder_error('WW_WANDER_NOT_FOUND', 'That Wander is no longer available.', p_idempotency_key, false, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;
    if v_session.state = 'active' then
        update public.wonder_wander_sessions set state = 'closed', end_utc = v_now where user_id = v_user_id and session_id = p_session_id;
        update public.wonder_wander_rewards
        set status = 'released', resolved_at = v_now
        where user_id = v_user_id and session_id = p_session_id and status = 'reserved' and reached_at is null;
        v_changed := true;
    end if;
    update public.wonder_wander_sessions s
    set reserved_count = (
        select count(*)::integer from public.wonder_wander_rewards r
        where r.user_id = v_user_id and r.session_id = p_session_id
          and r.status in ('reserved', 'pending_resolution')
    )
    where s.user_id = v_user_id and s.session_id = p_session_id;
    if v_changed then v_revision := wonder_private.wonder_increment_revision(v_user_id); else v_revision := v_base; end if;
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by r.tier), '[]'::jsonb) into v_rewards
    from public.wonder_wander_rewards r where r.user_id = v_user_id and r.session_id = p_session_id;
    v_response := wonder_private.wonder_mutation_response(
        p_idempotency_key, v_base, v_revision, false,
        pg_catalog.jsonb_build_object('session_id', p_session_id, 'session_state', 'closed', 'tier_states', v_rewards)
    );
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
    return v_response;
end;
$$;

create or replace function wonder_private.wonder_mutation_response(
    p_request_id uuid,
    p_base_revision bigint,
    p_state_revision bigint,
    p_replayed boolean,
    p_delta jsonb
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
    select pg_catalog.jsonb_build_object(
        'ok', true,
        'request_id', p_request_id,
        'base_revision', p_base_revision,
        'state_revision', p_state_revision,
        'replayed', p_replayed,
        'delta', p_delta
    );
$$;

create or replace function wonder_private.wonder_start_wander_core(
    p_user_id uuid,
    p_mode text,
    p_session_id uuid,
    p_time_zone text,
    p_expected_revision bigint,
    p_request_id uuid,
    p_allow_zero_reward boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_catalog_version integer;
    v_catalog_checksum text;
    v_local_date date;
    v_daily_count integer;
    v_reserved integer;
    v_base_revision bigint;
    v_state_revision bigint;
    v_changed boolean := false;
    v_offer record;
    v_session jsonb;
    v_offers jsonb;
    v_rewards jsonb;
    v_response jsonb;
begin
    if p_user_id is null or p_session_id is null or p_request_id is null then
        return wonder_private.wonder_error(
            'WW_INVALID_REQUEST', 'Required request identifiers are missing.',
            p_request_id, false, 0
        );
    end if;
    if p_mode not in ('verified', 'manual', 'fallback_step', 'time_only') then
        return wonder_private.wonder_error(
            'WW_INVALID_MODE', 'Unsupported Wander mode.',
            p_request_id, false, 0
        );
    end if;
    p_time_zone := wonder_private.wonder_require_time_zone(p_time_zone);

    v_idempotency := wonder_private.wonder_begin_idempotency(
        p_user_id,
        p_request_id,
        'wonder_start_manual_wander',
        pg_catalog.jsonb_build_object(
            'mode', p_mode,
            'session_id', p_session_id,
            'time_zone', p_time_zone,
            'expected_revision', p_expected_revision,
            'allow_zero_reward', p_allow_zero_reward
        )
    );
    if v_idempotency.replayed then
        return coalesce(
            v_idempotency.response_json,
            wonder_private.wonder_error(
                'WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.',
                p_request_id, true, 0
            )
        );
    end if;

    perform wonder_private.wonder_lock_player(p_user_id);
    select * into v_profile
    from public.wonder_profiles
    where user_id = p_user_id
    for update;
    if not found then
        v_response := wonder_private.wonder_error(
            'WW_AUTH_REQUIRED', 'Create an approved account before starting a Wander.',
            p_request_id, false, 0
        );
        perform wonder_private.wonder_finish_idempotency(p_user_id, p_request_id, v_response);
        return v_response;
    end if;
    v_base_revision := v_profile.state_revision;
    if p_expected_revision is null or p_expected_revision <> v_base_revision then
        v_response := wonder_private.wonder_error(
            'WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.',
            p_request_id, true, v_base_revision,
            pg_catalog.jsonb_build_object('expected_revision', p_expected_revision)
        );
        perform wonder_private.wonder_finish_idempotency(p_user_id, p_request_id, v_response);
        return v_response;
    end if;

    if exists (
        select 1 from public.wonder_hibernate_intervals
        where user_id = p_user_id and end_utc is null
    ) then
        v_response := wonder_private.wonder_error(
            'WW_HIBERNATING', 'Wander is unavailable during Hibernate.',
            p_request_id, false, v_base_revision
        );
        perform wonder_private.wonder_finish_idempotency(p_user_id, p_request_id, v_response);
        return v_response;
    end if;

    if wonder_private.wonder_close_stale_wander(p_user_id, v_now) > 0 then
        v_changed := true;
    end if;
    if wonder_private.wonder_process_expired_flowers(p_user_id, v_now) > 0 then
        v_changed := true;
    end if;

    v_local_date := (v_now at time zone p_time_zone)::date;
    select count(*)::integer into v_daily_count
    from public.wonder_wander_rewards r
    join public.wonder_wander_sessions s
      on s.user_id = r.user_id and s.session_id = r.session_id
    where r.user_id = p_user_id
      and s.local_date = v_local_date
      and r.status in ('reserved', 'pending_resolution', 'awarded');

    v_reserved := greatest(0, least(3, 6 - v_daily_count));
    if v_reserved = 0 and not p_allow_zero_reward then
        v_response := wonder_private.wonder_error(
            'WW_DAILY_FLOWER_CAP', 'Daily flower limit reached.',
            p_request_id, false, v_base_revision,
            pg_catalog.jsonb_build_object('daily_count', v_daily_count)
        );
        perform wonder_private.wonder_finish_idempotency(p_user_id, p_request_id, v_response);
        return v_response;
    end if;

    select coalesce(max(version), 1) into v_catalog_version
    from public.wonder_app_config
    where config_key = 'catalog_version';
    v_catalog_checksum := wonder_private.wonder_catalog_checksum(v_catalog_version);

    insert into public.wonder_wander_sessions (
        session_id, user_id, start_utc, auto_close_utc, local_date, time_zone,
        mode, offline, catalog_version, catalog_checksum, offer_season,
        reserved_count
    ) values (
        p_session_id, p_user_id, v_now, v_now + interval '1 hour', v_local_date, p_time_zone,
        p_mode, false, v_catalog_version, v_catalog_checksum, 'autumn', v_reserved
    );

    for v_offer in
        select * from wonder_private.wonder_select_autumn_offers(v_catalog_version)
    loop
        insert into public.wonder_wander_offers (
            user_id, session_id, position, species_id, species_slug,
            catalog_version, offer_checksum
        ) values (
            p_user_id, p_session_id, v_offer.offer_position, v_offer.species_id,
            v_offer.species_slug, v_catalog_version,
            encode(extensions.digest(
                p_session_id::text || ':' || v_catalog_version::text || ':autumn:' || v_offer.species_slug,
                'sha256'
            ), 'hex')
        );
    end loop;

    for v_tier in 1..v_reserved loop
        insert into public.wonder_wander_rewards (
            user_id, session_id, tier, status, resolution_mode
        ) values (
            p_user_id, p_session_id, v_tier * 10, 'reserved',
            case when v_tier = 3 then 'automatic' else 'player_choice' end
        );
    end loop;

    v_state_revision := wonder_private.wonder_increment_revision(p_user_id);
    v_session := pg_catalog.jsonb_build_object(
        'session_id', p_session_id,
        'mode', p_mode,
        'offline', false,
        'start_utc', v_now,
        'auto_close_utc', v_now + interval '1 hour',
        'local_date', v_local_date,
        'time_zone', p_time_zone,
        'catalog_version', v_catalog_version,
        'catalog_checksum', v_catalog_checksum,
        'reserved_count', v_reserved
    );
    select coalesce(
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'position', o.position,
                'species_id', o.species_id,
                'species_slug', o.species_slug,
                'catalog_version', o.catalog_version,
                'offer_checksum', o.offer_checksum
            ) order by o.position
        ), '[]'::jsonb
    ) into v_offers
    from public.wonder_wander_offers o
    where o.user_id = p_user_id and o.session_id = p_session_id;
    select coalesce(
        pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by r.tier), '[]'::jsonb
    ) into v_rewards
    from public.wonder_wander_rewards r
    where r.user_id = p_user_id and r.session_id = p_session_id;

    v_response := wonder_private.wonder_mutation_response(
        p_request_id, v_base_revision, v_state_revision, false,
        pg_catalog.jsonb_build_object(
            'session', v_session,
            'offers', v_offers,
            'rewards', v_rewards,
            'maintenance_changed', v_changed
        )
    );
    perform wonder_private.wonder_finish_idempotency(p_user_id, p_request_id, v_response);
    return v_response;
end;
$$;

create or replace function wonder_private.wonder_require_time_zone(p_time_zone text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
    if p_time_zone is null
       or not exists (
           select 1
           from pg_catalog.pg_timezone_names
           where name = p_time_zone
       ) then
        raise exception 'WW_INVALID_TIME_ZONE' using errcode = '22023';
    end if;
    return p_time_zone;
end;
$$;

create or replace function wonder_private.wonder_begin_idempotency(
    p_user_id uuid,
    p_request_id uuid,
    p_operation text,
    p_canonical_request jsonb
)
returns wonder_private.wonder_idempotency_result
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_existing public.wonder_idempotency_keys%rowtype;
begin
    if p_request_id is null or p_operation is null or p_operation not like 'wonder_%' then
        raise exception 'WW_INVALID_IDEMPOTENCY_INPUT' using errcode = '22023';
    end if;

    insert into public.wonder_idempotency_keys (
        user_id, request_id, operation, canonical_request
    ) values (
        p_user_id, p_request_id, p_operation, p_canonical_request
    ) on conflict (user_id, request_id) do nothing;

    if found then
        return (false, null)::wonder_private.wonder_idempotency_result;
    end if;

    select * into v_existing
    from public.wonder_idempotency_keys
    where user_id = p_user_id and request_id = p_request_id
    for update;

    if v_existing.operation <> p_operation
       or v_existing.canonical_request is distinct from p_canonical_request then
        raise exception 'WW_IDEMPOTENCY_REUSED' using errcode = '22023';
    end if;

    return (
        true,
        case
            when v_existing.response_json is null then null
            else pg_catalog.jsonb_set(v_existing.response_json, '{replayed}', 'true'::jsonb)
        end
    )::wonder_private.wonder_idempotency_result;
end;
$$;

create or replace function wonder_private.wonder_finish_idempotency(
    p_user_id uuid,
    p_request_id uuid,
    p_response_json jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.wonder_idempotency_keys
    set response_json = p_response_json,
        completed_at = timezone('utc', now())
    where user_id = p_user_id and request_id = p_request_id;
end;
$$;

create or replace function wonder_private.wonder_lock_player(p_user_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
    select pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(p_user_id::text, 0)
    );
$$;

create or replace function wonder_private.wonder_increment_revision(p_user_id uuid)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_revision bigint;
begin
    update public.wonder_profiles
    set state_revision = state_revision + 1,
        updated_at = timezone('utc', now())
    where user_id = p_user_id
    returning state_revision into v_revision;

    if v_revision is null then
        raise exception 'WW_AUTH_REQUIRED' using errcode = '42501';
    end if;
    return v_revision;
end;
$$;

create or replace function wonder_private.wonder_process_expired_flowers(
    p_user_id uuid,
    p_now timestamptz
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_flower record;
    v_count integer := 0;
begin
    if exists (
        select 1
        from public.wonder_hibernate_intervals
        where user_id = p_user_id and end_utc is null
    ) then
        return 0;
    end if;

    for v_flower in
        select flower_id
        from public.wonder_flower_instances
        where user_id = p_user_id
          and state = 'living'
          and deadline_utc <= p_now
        for update
    loop
        update public.wonder_flower_instances
        set state = 'pressed', version = version + 1
        where user_id = p_user_id and flower_id = v_flower.flower_id and state = 'living';

        delete from public.wonder_vase_assignments
        where user_id = p_user_id and flower_id = v_flower.flower_id;

        insert into public.wonder_flower_events (
            user_id, flower_id, event_type, occurred_at
        ) values (
            p_user_id, v_flower.flower_id, 'natural_fade', p_now
        );
        v_count := v_count + 1;
    end loop;
    return v_count;
end;
$$;

create or replace function wonder_private.wonder_close_stale_wander(
    p_user_id uuid,
    p_now timestamptz
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_session record;
    v_count integer := 0;
begin
    for v_session in
        select session_id
        from public.wonder_wander_sessions
        where user_id = p_user_id
          and state = 'active'
          and auto_close_utc <= p_now
        for update
    loop
        update public.wonder_wander_sessions
        set state = 'closed', end_utc = p_now
        where user_id = p_user_id and session_id = v_session.session_id and state = 'active';

        update public.wonder_wander_rewards
        set status = 'released', resolved_at = p_now
        where user_id = p_user_id
          and session_id = v_session.session_id
          and status = 'reserved'
          and reached_at is null;

        update public.wonder_wander_sessions s
        set reserved_count = (
            select count(*)::integer
            from public.wonder_wander_rewards r
            where r.user_id = p_user_id
              and r.session_id = s.session_id
              and r.status in ('reserved', 'pending_resolution')
        )
        where s.user_id = p_user_id and s.session_id = v_session.session_id;
        v_count := v_count + 1;
    end loop;
    return v_count;
end;
$$;

create or replace function wonder_private.wonder_select_autumn_offers(
    p_catalog_version integer
)
returns table (
    offer_position integer,
    species_id uuid,
    species_slug text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_ids uuid[];
    v_slugs text[];
    v_weights integer[];
    v_total integer;
    v_draw integer;
    v_cumulative integer;
    v_index integer;
    v_length integer;
    v_selected_id uuid;
    v_selected_slug text;
begin
    select
        pg_catalog.array_agg(s.species_id order by s.slug),
        pg_catalog.array_agg(s.slug order by s.slug),
        pg_catalog.array_agg(s.offer_weight order by s.slug)
    into v_ids, v_slugs, v_weights
    from public.wonder_species s
    where s.source = 'wander'
      and s.season = 'autumn'
      and s.active
      and s.introduced_catalog_version <= p_catalog_version
      and (s.retired_catalog_version is null or s.retired_catalog_version > p_catalog_version);

    if coalesce(pg_catalog.array_length(v_ids, 1), 0) < 3
       or exists (select 1 from pg_catalog.unnest(v_weights) w(weight) where w.weight <= 0) then
        raise exception 'WW_CATALOG_CORRUPT' using errcode = '22023';
    end if;

    for v_position in 1..3 loop
        select coalesce(sum(w.weight), 0)::integer
        into v_total
        from pg_catalog.unnest(v_weights) w(weight);
        v_draw := pg_catalog.floor(pg_catalog.random() * v_total)::integer;
        v_cumulative := 0;
        v_length := pg_catalog.array_length(v_ids, 1);
        v_index := 1;

        while v_index <= v_length loop
            v_cumulative := v_cumulative + v_weights[v_index];
            if v_draw < v_cumulative then
                v_selected_id := v_ids[v_index];
                v_selected_slug := v_slugs[v_index];
                exit;
            end if;
            v_index := v_index + 1;
        end loop;

        offer_position := v_position;
        species_id := v_selected_id;
        species_slug := v_selected_slug;
        return next;

        if v_index = 1 then
            if v_length = 1 then
                v_ids := array[]::uuid[];
                v_slugs := array[]::text[];
                v_weights := array[]::integer[];
            else
                v_ids := v_ids[2:v_length];
                v_slugs := v_slugs[2:v_length];
                v_weights := v_weights[2:v_length];
            end if;
        elsif v_index = v_length then
            v_ids := v_ids[1:v_length - 1];
            v_slugs := v_slugs[1:v_length - 1];
            v_weights := v_weights[1:v_length - 1];
        else
            v_ids := v_ids[1:v_index - 1] || v_ids[v_index + 1:v_length];
            v_slugs := v_slugs[1:v_index - 1] || v_slugs[v_index + 1:v_length];
            v_weights := v_weights[1:v_index - 1] || v_weights[v_index + 1:v_length];
        end if;
    end loop;
end;
$$;

create or replace function wonder_private.wonder_catalog_checksum(p_catalog_version integer)
returns text
language sql
security definer
set search_path = ''
as $$
    select encode(
        extensions.digest(
            coalesce(
                (
                    select string_agg(
                        s.slug || ':' || coalesce(s.offer_weight::text, '') || ':' ||
                        s.living_asset_key || ':' || s.fading_asset_key || ':' || s.pressed_asset_key,
                        e'\n' order by s.slug
                    )
                    from public.wonder_species s
                    where s.introduced_catalog_version <= p_catalog_version
                      and (s.retired_catalog_version is null or s.retired_catalog_version > p_catalog_version)
                      and s.active
                ),
                ''
            ),
            'sha256'
        ),
        'hex'
    );
$$;

create or replace function wonder_private.wonder_calculate_sale_value(
    p_deadline_utc timestamptz,
    p_now timestamptz
)
returns integer
language sql
immutable
security definer
set search_path = ''
as $$
    select 5 * greatest(
        1,
        ceil(
            greatest(0, extract(epoch from (p_deadline_utc - p_now))) / 86400.0
        )::integer
    );
$$;

create or replace function wonder_private.wonder_append_glow_entry(
    p_user_id uuid,
    p_amount integer,
    p_reason text,
    p_idempotency_key uuid,
    p_domain_id uuid
)
returns wonder_private.wonder_glow_result
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_existing public.wonder_glow_ledger%rowtype;
    v_balance integer;
    v_entry_id uuid;
begin
    select * into v_existing
    from public.wonder_glow_ledger
    where user_id = p_user_id and idempotency_key = p_idempotency_key
    for update;
    if found then
        return (v_existing.entry_id, v_existing.balance_after)::wonder_private.wonder_glow_result;
    end if;

    select glow_balance into v_balance
    from public.wonder_profiles
    where user_id = p_user_id
    for update;

    if v_balance is null then
        raise exception 'WW_AUTH_REQUIRED' using errcode = '42501';
    end if;
    if p_amount < 0 and v_balance + p_amount < 0 then
        raise exception 'WW_INSUFFICIENT_GLOW' using errcode = '22023';
    end if;

    v_balance := v_balance + p_amount;
    insert into public.wonder_glow_ledger (
        user_id, amount, balance_after, reason, idempotency_key, domain_id
    ) values (
        p_user_id, p_amount, v_balance, p_reason, p_idempotency_key, p_domain_id
    ) returning entry_id into v_entry_id;

    update public.wonder_profiles
    set glow_balance = v_balance,
        updated_at = timezone('utc', now())
    where user_id = p_user_id;

    return (v_entry_id, v_balance)::wonder_private.wonder_glow_result;
end;
$$;

create or replace function wonder_private.wonder_award_flower(
    p_user_id uuid,
    p_species_id uuid,
    p_source text,
    p_session_id uuid,
    p_tier integer,
    p_acquired_at timestamptz,
    p_time_zone text,
    p_local_date date
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_flower_id uuid;
    v_duration integer;
begin
    select bloom_duration_seconds into v_duration
    from public.wonder_species
    where species_id = p_species_id and active;
    if v_duration is null then
        raise exception 'WW_CATALOG_MISMATCH' using errcode = '22023';
    end if;

    insert into public.wonder_flower_instances (
        user_id, species_id, source, session_id, tier, acquired_at,
        duration_seconds, deadline_utc
    ) values (
        p_user_id, p_species_id, p_source, p_session_id, p_tier, p_acquired_at,
        v_duration, p_acquired_at + (v_duration * interval '1 second')
    ) returning flower_id into v_flower_id;

    insert into public.wonder_discoveries (
        user_id, species_id, first_discovered_at, first_local_date, time_zone
    ) values (
        p_user_id, p_species_id, p_acquired_at, p_local_date, p_time_zone
    ) on conflict (user_id, species_id) do nothing;

    insert into public.wonder_flower_events (
        user_id, flower_id, session_id, event_type, occurred_at
    ) values (
        p_user_id, v_flower_id, p_session_id, 'acquired', p_acquired_at
    );
    return v_flower_id;
end;
$$;

create or replace function wonder_private.wonder_reconcile_session(
    p_user_id uuid,
    p_session_id uuid,
    p_now timestamptz
)
returns wonder_private.wonder_reconcile_state
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_session public.wonder_wander_sessions%rowtype;
    v_reward record;
    v_changed boolean := false;
    v_elapsed integer;
    v_earliest integer;
    v_auto_flower uuid;
    v_remaining_species uuid;
    v_local_date date;
    v_time_zone text;
begin
    select * into v_session
    from public.wonder_wander_sessions
    where user_id = p_user_id and session_id = p_session_id
    for update;

    if not found then
        raise exception 'WW_WANDER_NOT_FOUND' using errcode = '22023';
    end if;

    v_elapsed := greatest(
        0,
        least(
            3600,
            floor(extract(epoch from (p_now - v_session.start_utc)))::integer
        )
    );
    v_local_date := v_session.local_date;
    v_time_zone := v_session.time_zone;

    if v_session.state = 'active' and p_now >= v_session.auto_close_utc then
        update public.wonder_wander_sessions
        set state = 'closed', end_utc = p_now
        where user_id = p_user_id and session_id = p_session_id;
        update public.wonder_wander_rewards
        set status = 'released', resolved_at = p_now
        where user_id = p_user_id
          and session_id = p_session_id
          and status = 'reserved'
          and reached_at is null;
        v_changed := true;
    end if;

    for v_reward in
        select tier
        from public.wonder_wander_rewards
        where user_id = p_user_id
          and session_id = p_session_id
          and status = 'reserved'
          and v_elapsed >= tier * 60
        order by tier
        for update
    loop
        update public.wonder_wander_rewards
        set status = 'pending_resolution', reached_at = p_now
        where user_id = p_user_id and session_id = p_session_id and tier = v_reward.tier;
        v_changed := true;
    end loop;

    if v_elapsed >= 1800
       and not exists (
           select 1 from public.wonder_wander_rewards
           where user_id = p_user_id and session_id = p_session_id
             and tier in (10, 20) and status not in ('awarded', 'rejected', 'released')
       )
       and exists (
           select 1 from public.wonder_wander_rewards
           where user_id = p_user_id and session_id = p_session_id
             and tier = 30 and status = 'pending_resolution'
       ) then
        select o.species_id into v_remaining_species
        from public.wonder_wander_offers o
        where o.user_id = p_user_id and o.session_id = p_session_id
          and not exists (
              select 1
              from public.wonder_wander_rewards r
              where r.user_id = p_user_id and r.session_id = p_session_id
                and r.selected_species_id = o.species_id
                and r.status = 'awarded'
          )
        order by o.position;

        if v_remaining_species is not null then
            v_auto_flower := wonder_private.wonder_award_flower(
                p_user_id, v_remaining_species, 'wander', p_session_id, 30,
                p_now, v_time_zone, v_local_date
            );
            update public.wonder_wander_rewards
            set status = 'awarded', selected_species_id = v_remaining_species,
                flower_id = v_auto_flower, resolved_at = p_now
            where user_id = p_user_id and session_id = p_session_id and tier = 30;
            update public.wonder_wander_sessions
            set earned_count = earned_count + 1
            where user_id = p_user_id and session_id = p_session_id;
            v_changed := true;
        end if;
    end if;

    select min(tier) into v_earliest
    from public.wonder_wander_rewards
    where user_id = p_user_id
      and session_id = p_session_id
      and status = 'pending_resolution';

    return (
        v_changed,
        (select state from public.wonder_wander_sessions where user_id = p_user_id and session_id = p_session_id),
        v_elapsed,
        v_earliest,
        v_auto_flower
    )::wonder_private.wonder_reconcile_state;
end;
$$;

create or replace function wonder_private.wonder_build_snapshot(
    p_user_id uuid,
    p_server_now timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_profile jsonb;
    v_settings jsonb;
    v_living jsonb;
    v_pressed jsonb;
    v_active_wander jsonb;
    v_vases jsonb;
    v_shelf jsonb;
    v_shop jsonb;
    v_entitlements jsonb;
    v_daily_grants jsonb;
    v_steps jsonb;
    v_hibernate jsonb;
    v_revision bigint;
begin
    select pg_catalog.jsonb_build_object(
        'user_id', p.user_id,
        'glow_balance', p.glow_balance,
        'state_revision', p.state_revision
    ), p.state_revision
    into v_profile, v_revision
    from public.wonder_profiles p
    where p.user_id = p_user_id;

    if v_profile is null then
        raise exception 'WW_AUTH_REQUIRED' using errcode = '42501';
    end if;

    select pg_catalog.to_jsonb(s) into v_settings
    from public.wonder_player_settings s
    where s.user_id = p_user_id;

    select coalesce(
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'flower_id', f.flower_id,
                'species_id', f.species_id,
                'source', f.source,
                'session_id', f.session_id,
                'tier', f.tier,
                'acquired_at', f.acquired_at,
                'duration_seconds', f.duration_seconds,
                'deadline_utc', f.deadline_utc,
                'extension_seconds', f.extension_seconds,
                'state', f.state,
                'version', f.version,
                'sale_glow', wonder_private.wonder_calculate_sale_value(f.deadline_utc, p_server_now)
            ) order by f.acquired_at
        ),
        '[]'::jsonb
    ) into v_living
    from public.wonder_flower_instances f
    where f.user_id = p_user_id and f.state = 'living';

    select coalesce(
        pg_catalog.jsonb_agg(pg_catalog.to_jsonb(f) order by f.acquired_at),
        '[]'::jsonb
    ) into v_pressed
    from public.wonder_flower_instances f
    where f.user_id = p_user_id and f.state = 'pressed';

    select pg_catalog.jsonb_build_object(
        'session_id', s.session_id,
        'state', s.state,
        'mode', s.mode,
        'offline', s.offline,
        'start_utc', s.start_utc,
        'auto_close_utc', s.auto_close_utc,
        'local_date', s.local_date,
        'time_zone', s.time_zone,
        'catalog_version', s.catalog_version,
        'catalog_checksum', s.catalog_checksum,
        'offers', coalesce((
            select pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                    'position', o.position,
                    'species_id', o.species_id,
                    'species_slug', o.species_slug,
                    'catalog_version', o.catalog_version,
                    'offer_checksum', o.offer_checksum
                ) order by o.position
            ) from public.wonder_wander_offers o
            where o.user_id = p_user_id and o.session_id = s.session_id
        ), '[]'::jsonb),
        'rewards', coalesce((
            select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by r.tier)
            from public.wonder_wander_rewards r
            where r.user_id = p_user_id and r.session_id = s.session_id
        ), '[]'::jsonb)
    ) into v_active_wander
    from public.wonder_wander_sessions s
    where s.user_id = p_user_id and s.state = 'active'
    order by s.start_utc desc
    limit 1;

    select coalesce(
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'slot', s.slot,
                'capacity', s.capacity,
                'unlocked', s.unlocked,
                'pattern_key', s.pattern_key,
                'assignments', coalesce((
                    select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(a) order by a.position)
                    from public.wonder_vase_assignments a
                    where a.user_id = p_user_id and a.slot = s.slot
                ), '[]'::jsonb)
            ) order by s.slot
        ),
        '[]'::jsonb
    ) into v_vases
    from public.wonder_vase_slots s
    where s.user_id = p_user_id;

    select coalesce(
        pg_catalog.jsonb_agg(pg_catalog.to_jsonb(s) order by s.position),
        '[]'::jsonb
    ) into v_shelf
    from public.wonder_shelf_assignments s
    where s.user_id = p_user_id;

    select coalesce(
        pg_catalog.jsonb_agg(pg_catalog.to_jsonb(s) order by s.item_key),
        '[]'::jsonb
    ) into v_shop
    from public.wonder_shop_items s
    where s.active;

    select coalesce(
        pg_catalog.jsonb_agg(pg_catalog.to_jsonb(e) order by e.item_key),
        '[]'::jsonb
    ) into v_entitlements
    from public.wonder_player_entitlements e
    where e.user_id = p_user_id;

    select coalesce(
        pg_catalog.jsonb_agg(pg_catalog.to_jsonb(g) order by g.local_date desc),
        '[]'::jsonb
    ) into v_daily_grants
    from public.wonder_daily_grants g
    where g.user_id = p_user_id;

    select coalesce(
        pg_catalog.jsonb_agg(pg_catalog.to_jsonb(s) order by s.local_date desc),
        '[]'::jsonb
    ) into v_steps
    from (
        select * from public.wonder_daily_step_credits
        where user_id = p_user_id
        order by local_date desc
        limit 7
    ) s;

    select coalesce(
        pg_catalog.jsonb_agg(pg_catalog.to_jsonb(h) order by h.start_utc),
        '[]'::jsonb
    ) into v_hibernate
    from public.wonder_hibernate_intervals h
    where h.user_id = p_user_id
      and h.start_utc >= p_server_now - interval '8 days';

    return pg_catalog.jsonb_build_object(
        'server_now', p_server_now,
        'state_revision', v_revision,
        'profile', v_profile,
        'settings', coalesce(v_settings, '{}'::jsonb),
        'catalog_version', coalesce((
            select max(version) from public.wonder_app_config where config_key = 'catalog_version'
        ), 1),
        'active_wander', coalesce(v_active_wander, 'null'::jsonb),
        'living_flowers', v_living,
        'pressed_flowers', v_pressed,
        'vases', v_vases,
        'shelf_assignments', v_shelf,
        'shop_items', v_shop,
        'player_entitlements', v_entitlements,
        'daily_grants', v_daily_grants,
        'step_summaries', v_steps,
        'hibernate_intervals', v_hibernate
    );
end;
$$;

create or replace function public.wonder_auth_gate(
    p_provider text,
    p_provider_identity_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
    v_identity public.wonder_account_identities%rowtype;
begin
    if v_user_id is null then
        return pg_catalog.jsonb_build_object(
            'ok', false,
            'gate', 'auth_required',
            'code', 'WW_AUTH_REQUIRED'
        );
    end if;

    select * into v_identity
    from public.wonder_account_identities
    where provider = p_provider
      and provider_identity_id = p_provider_identity_id;

    if not found then
        return pg_catalog.jsonb_build_object(
            'ok', true,
            'gate', 'bootstrap_required',
            'approved', false,
            'quarantined', false,
            'provider', p_provider
        );
    end if;
    if v_identity.user_id <> v_user_id or v_identity.approval not in ('initial', 'explicit_link') then
        return pg_catalog.jsonb_build_object(
            'ok', false,
            'gate', 'quarantined',
            'approved', false,
            'quarantined', true,
            'code', 'WW_IDENTITY_NOT_APPROVED'
        );
    end if;

    return pg_catalog.jsonb_build_object(
        'ok', true,
        'gate', case when exists (
            select 1 from public.wonder_profiles where user_id = v_user_id
        ) then 'approved' else 'bootstrap_required' end,
        'approved', true,
        'quarantined', false,
        'user_id', v_user_id,
        'identity_id', v_identity.identity_id,
        'provider', v_identity.provider
    );
end;
$$;

create or replace function public.wonder_approve_linked_identity(
    p_identity_id uuid,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_identity public.wonder_account_identities%rowtype;
    v_base bigint;
    v_revision bigint;
    v_response jsonb;
begin
    if v_user_id is null then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to approve an identity.', p_idempotency_key, false, 0);
    end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Create an approved account first.', p_idempotency_key, false, 0);
    end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(
        v_user_id, p_idempotency_key, 'wonder_approve_linked_identity',
        pg_catalog.jsonb_build_object('identity_id', p_identity_id, 'expected_revision', p_expected_revision)
    );
    if v_idempotency.replayed then
        return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base));
    end if;
    if p_expected_revision is null or p_expected_revision <> v_base then
        v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;
    select * into v_identity
    from public.wonder_account_identities
    where identity_id = p_identity_id and user_id = v_user_id
    for update;
    if not found then
        v_response := wonder_private.wonder_error('WW_IDENTITY_NOT_APPROVED', 'That identity is not available to this account.', p_idempotency_key, false, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;
    if v_identity.approval <> 'explicit_link' then
        update public.wonder_account_identities
        set approval = 'explicit_link'
        where identity_id = p_identity_id and user_id = v_user_id;
        v_revision := wonder_private.wonder_increment_revision(v_user_id);
    else
        v_revision := v_base;
    end if;
    v_response := wonder_private.wonder_mutation_response(
        p_idempotency_key, v_base, v_revision, false,
        pg_catalog.jsonb_build_object('identity_id', p_identity_id, 'approval', 'explicit_link')
    );
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
    return v_response;
end;
$$;

create or replace function public.wonder_bootstrap(
    p_time_zone text,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_base bigint;
    v_revision bigint;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_local_date date;
    v_daisy_id uuid;
    v_flower_id uuid;
    v_created boolean := false;
    v_changed boolean := false;
    v_response jsonb;
begin
    if v_user_id is null then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in before opening the garden.', p_idempotency_key, false, 0);
    end if;
    if not exists (
        select 1 from public.wonder_account_identities
        where user_id = v_user_id and approval in ('initial', 'explicit_link')
    ) then
        return wonder_private.wonder_error('WW_IDENTITY_NOT_APPROVED', 'Approve this sign-in identity before opening the garden.', p_idempotency_key, false, 0);
    end if;
    p_time_zone := wonder_private.wonder_require_time_zone(p_time_zone);
    perform wonder_private.wonder_lock_player(v_user_id);

    insert into public.wonder_profiles (user_id)
    values (v_user_id)
    on conflict (user_id) do nothing;
    v_created := found;
    v_changed := v_created;
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    v_base := v_profile.state_revision;

    v_idempotency := wonder_private.wonder_begin_idempotency(
        v_user_id, p_idempotency_key, 'wonder_bootstrap',
        pg_catalog.jsonb_build_object('time_zone', p_time_zone)
    );
    if v_idempotency.replayed then
        return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base));
    end if;

    insert into public.wonder_player_settings (user_id, time_zone)
    values (v_user_id, p_time_zone)
    on conflict (user_id) do update
        set time_zone = excluded.time_zone, updated_at = timezone('utc', now());
    insert into public.wonder_vase_slots (user_id, slot, capacity, unlocked)
    values
        (v_user_id, 1, 1, true),
        (v_user_id, 2, 2, false),
        (v_user_id, 3, 3, false)
    on conflict (user_id, slot) do nothing;

    insert into public.wonder_player_entitlements (user_id, item_key)
    select v_user_id, item_key
    from public.wonder_shop_items
    where item_key = 'classic_cream'
    on conflict (user_id, item_key) do nothing;

    v_local_date := (v_now at time zone p_time_zone)::date;
    if not exists (
        select 1 from public.wonder_daily_grants
        where user_id = v_user_id and local_date = v_local_date and grant_type = 'daily_daisy'
    ) then
        select species_id into v_daisy_id
        from public.wonder_species
        where slug = 'daisy' and source = 'daily' and active;
        if v_daisy_id is null then
            v_response := wonder_private.wonder_error('WW_CATALOG_CORRUPT', 'The daily catalog is unavailable.', p_idempotency_key, false, v_base);
            perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
            return v_response;
        end if;
        v_flower_id := wonder_private.wonder_award_flower(
            v_user_id, v_daisy_id, 'daily', null, null, v_now, p_time_zone, v_local_date
        );
        insert into public.wonder_daily_grants (
            user_id, local_date, grant_type, time_zone, flower_id, granted_at
        ) values (
            v_user_id, v_local_date, 'daily_daisy', p_time_zone, v_flower_id, v_now
        );
        v_changed := true;
    end if;

    if v_changed then
        v_revision := wonder_private.wonder_increment_revision(v_user_id);
    else
        v_revision := v_base;
    end if;
    v_response := pg_catalog.jsonb_build_object(
        'ok', true,
        'request_id', p_idempotency_key,
        'replayed', false,
        'base_revision', v_base,
        'state_revision', v_revision,
        'snapshot', wonder_private.wonder_build_snapshot(v_user_id, v_now)
    );
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
    return v_response;
end;
$$;

create or replace function public.wonder_refresh_state()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_changed boolean := false;
    v_revision bigint;
begin
    if v_user_id is null then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to refresh the garden.', null, false, 0);
    end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    if not exists (select 1 from public.wonder_profiles where user_id = v_user_id) then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before refreshing it.', null, false, 0);
    end if;
    if wonder_private.wonder_close_stale_wander(v_user_id, v_now) > 0 then v_changed := true; end if;
    if wonder_private.wonder_process_expired_flowers(v_user_id, v_now) > 0 then v_changed := true; end if;
    if v_changed then
        v_revision := wonder_private.wonder_increment_revision(v_user_id);
    else
        select state_revision into v_revision from public.wonder_profiles where user_id = v_user_id;
    end if;
    return pg_catalog.jsonb_build_object(
        'ok', true,
        'server_now', v_now,
        'state_revision', v_revision,
        'snapshot', wonder_private.wonder_build_snapshot(v_user_id, v_now)
    );
end;
$$;

create or replace function public.wonder_start_manual_wander(
    p_mode text,
    p_session_id uuid,
    p_time_zone text,
    p_expected_revision bigint,
    p_idempotency_key uuid,
    p_allow_zero_reward boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
begin
    if v_user_id is null then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in before starting a Wander.', p_idempotency_key, false, 0);
    end if;
    if p_mode not in ('manual', 'fallback_step', 'time_only') then
        return wonder_private.wonder_error('WW_INVALID_MODE', 'Choose a supported Wander mode.', p_idempotency_key, false, 0);
    end if;
    return wonder_private.wonder_start_wander_core(
        v_user_id, p_mode, p_session_id, p_time_zone,
        p_expected_revision, p_idempotency_key, p_allow_zero_reward
    );
end;
$$;

create or replace function public.wonder_start_verified_wander_internal(
    p_user_id uuid,
    p_session_id uuid,
    p_time_zone text,
    p_expected_revision bigint,
    p_idempotency_key uuid,
    p_allow_zero_reward boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
begin
    if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'This operation is service-only.', p_idempotency_key, false, 0);
    end if;
    return wonder_private.wonder_start_wander_core(
        p_user_id, 'verified', p_session_id, p_time_zone,
        p_expected_revision, p_idempotency_key, p_allow_zero_reward
    );
end;
$$;

create or replace function public.wonder_assign_flower_to_vase(
    p_flower_id uuid,
    p_slot integer,
    p_position integer,
    p_expected_version bigint,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_flower public.wonder_flower_instances%rowtype;
    v_slot public.wonder_vase_slots%rowtype;
    v_base bigint;
    v_revision bigint;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_response jsonb;
begin
    if v_user_id is null then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to arrange flowers.', p_idempotency_key, false, 0); end if;
    if p_slot not between 1 and 3 or p_position not between 1 and 3 then return wonder_private.wonder_error('WW_INVALID_REQUEST', 'Choose a valid vase position.', p_idempotency_key, false, 0); end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before arranging flowers.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(v_user_id, p_idempotency_key, 'wonder_assign_flower_to_vase', pg_catalog.jsonb_build_object('flower_id', p_flower_id, 'slot', p_slot, 'position', p_position, 'expected_version', p_expected_version, 'expected_revision', p_expected_revision));
    if v_idempotency.replayed then return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base)); end if;
    if p_expected_revision is null or p_expected_revision <> v_base then
        v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
    end if;
    perform wonder_private.wonder_process_expired_flowers(v_user_id, v_now);
    select * into v_flower from public.wonder_flower_instances where user_id = v_user_id and flower_id = p_flower_id for update;
    if not found then v_response := wonder_private.wonder_error('WW_FLOWER_NOT_FOUND', 'That flower is not in your garden.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_flower.version <> p_expected_version then v_response := wonder_private.wonder_error('WW_STALE_OBJECT', 'That flower changed. Refresh its arrangement.', p_idempotency_key, true, v_base, pg_catalog.jsonb_build_object('flower_version', v_flower.version)); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_flower.state <> 'living' then v_response := wonder_private.wonder_error('WW_FLOWER_EXPIRED', 'Only a living flower can be displayed.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    select * into v_slot from public.wonder_vase_slots where user_id = v_user_id and slot = p_slot for update;
    if not found or not v_slot.unlocked or p_position > v_slot.capacity then v_response := wonder_private.wonder_error('WW_VASE_LOCKED', 'That vase position is not unlocked.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if exists (select 1 from public.wonder_vase_assignments where user_id = v_user_id and slot = p_slot and position = p_position) then v_response := wonder_private.wonder_error('WW_VASE_POSITION_TAKEN', 'That vase position is already occupied.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if exists (select 1 from public.wonder_vase_assignments where user_id = v_user_id and flower_id = p_flower_id) then v_response := wonder_private.wonder_error('WW_FLOWER_ALREADY_DISPLAYED', 'That flower is already displayed.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    insert into public.wonder_vase_assignments (user_id, slot, position, flower_id, assigned_at) values (v_user_id, p_slot, p_position, p_flower_id, v_now);
    update public.wonder_flower_instances set version = version + 1 where user_id = v_user_id and flower_id = p_flower_id;
    insert into public.wonder_flower_events (user_id, flower_id, event_type, occurred_at, idempotency_key, vase_slot, vase_position) values (v_user_id, p_flower_id, 'vase_assigned', v_now, p_idempotency_key, p_slot, p_position);
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('assignment', pg_catalog.jsonb_build_object('slot', p_slot, 'position', p_position, 'flower_id', p_flower_id), 'flower_version', p_expected_version + 1));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
end;
$$;

create or replace function public.wonder_remove_flower_from_vase(
    p_flower_id uuid,
    p_expected_version bigint,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_flower public.wonder_flower_instances%rowtype;
    v_assignment public.wonder_vase_assignments%rowtype;
    v_base bigint;
    v_revision bigint;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_response jsonb;
begin
    if v_user_id is null then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to arrange flowers.', p_idempotency_key, false, 0); end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before arranging flowers.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(v_user_id, p_idempotency_key, 'wonder_remove_flower_from_vase', pg_catalog.jsonb_build_object('flower_id', p_flower_id, 'expected_version', p_expected_version, 'expected_revision', p_expected_revision));
    if v_idempotency.replayed then return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base)); end if;
    if p_expected_revision is null or p_expected_revision <> v_base then v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    perform wonder_private.wonder_process_expired_flowers(v_user_id, v_now);
    select * into v_flower from public.wonder_flower_instances where user_id = v_user_id and flower_id = p_flower_id for update;
    if not found then v_response := wonder_private.wonder_error('WW_FLOWER_NOT_FOUND', 'That flower is not in your garden.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_flower.version <> p_expected_version then v_response := wonder_private.wonder_error('WW_STALE_OBJECT', 'That flower changed. Refresh its arrangement.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    select * into v_assignment from public.wonder_vase_assignments where user_id = v_user_id and flower_id = p_flower_id for update;
    if not found then v_response := wonder_private.wonder_error('WW_NOT_DISPLAYED', 'That flower is not currently displayed.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    delete from public.wonder_vase_assignments where user_id = v_user_id and flower_id = p_flower_id;
    update public.wonder_flower_instances set version = version + 1 where user_id = v_user_id and flower_id = p_flower_id;
    insert into public.wonder_flower_events (user_id, flower_id, event_type, occurred_at, idempotency_key, vase_slot, vase_position) values (v_user_id, p_flower_id, 'vase_removed', v_now, p_idempotency_key, v_assignment.slot, v_assignment.position);
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('flower_id', p_flower_id, 'removed_slot', v_assignment.slot, 'removed_position', v_assignment.position, 'flower_version', p_expected_version + 1));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
end;
$$;

create or replace function public.wonder_press_flower(
    p_flower_id uuid,
    p_expected_version bigint,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_flower public.wonder_flower_instances%rowtype;
    v_base bigint;
    v_revision bigint;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_response jsonb;
begin
    if v_user_id is null then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to press a flower.', p_idempotency_key, false, 0); end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before pressing a flower.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(v_user_id, p_idempotency_key, 'wonder_press_flower', pg_catalog.jsonb_build_object('flower_id', p_flower_id, 'expected_version', p_expected_version, 'expected_revision', p_expected_revision));
    if v_idempotency.replayed then return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base)); end if;
    if p_expected_revision is null or p_expected_revision <> v_base then v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    perform wonder_private.wonder_process_expired_flowers(v_user_id, v_now);
    select * into v_flower from public.wonder_flower_instances where user_id = v_user_id and flower_id = p_flower_id for update;
    if not found then v_response := wonder_private.wonder_error('WW_FLOWER_NOT_FOUND', 'That flower is not in your garden.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_flower.version <> p_expected_version then v_response := wonder_private.wonder_error('WW_STALE_OBJECT', 'That flower changed. Refresh its arrangement.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_flower.state <> 'living' then v_response := wonder_private.wonder_error('WW_FLOWER_EXPIRED', 'That flower has already faded.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    delete from public.wonder_vase_assignments where user_id = v_user_id and flower_id = p_flower_id;
    update public.wonder_flower_instances set state = 'pressed', version = version + 1 where user_id = v_user_id and flower_id = p_flower_id;
    update public.wonder_discoveries set pressed_count = pressed_count + 1 where user_id = v_user_id and species_id = v_flower.species_id;
    insert into public.wonder_flower_events (user_id, flower_id, event_type, occurred_at, idempotency_key) values (v_user_id, p_flower_id, 'pressed_early', v_now, p_idempotency_key);
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('flower_id', p_flower_id, 'state', 'pressed', 'flower_version', p_expected_version + 1));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
end;
$$;

create or replace function public.wonder_sell_flower(
    p_flower_id uuid,
    p_expected_value integer,
    p_expected_version bigint,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_flower public.wonder_flower_instances%rowtype;
    v_ledger wonder_private.wonder_glow_result;
    v_base bigint;
    v_revision bigint;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_current_value integer;
    v_response jsonb;
begin
    if v_user_id is null then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to sell a flower.', p_idempotency_key, false, 0); end if;
    if p_expected_value is null or p_expected_version is null then return wonder_private.wonder_error('WW_INVALID_REQUEST', 'A current flower value and version are required.', p_idempotency_key, false, 0); end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before selling a flower.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(v_user_id, p_idempotency_key, 'wonder_sell_flower', pg_catalog.jsonb_build_object('flower_id', p_flower_id, 'expected_value', p_expected_value, 'expected_version', p_expected_version, 'expected_revision', p_expected_revision));
    if v_idempotency.replayed then return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base)); end if;
    if p_expected_revision is null or p_expected_revision <> v_base then v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    perform wonder_private.wonder_process_expired_flowers(v_user_id, v_now);
    select * into v_flower from public.wonder_flower_instances where user_id = v_user_id and flower_id = p_flower_id for update;
    if not found then v_response := wonder_private.wonder_error('WW_FLOWER_NOT_FOUND', 'That flower is not in your garden.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_flower.state <> 'living' then v_response := wonder_private.wonder_error('WW_FLOWER_EXPIRED', 'That flower is no longer living.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    v_current_value := wonder_private.wonder_calculate_sale_value(v_flower.deadline_utc, v_now);
    if v_flower.version <> p_expected_version or v_current_value <> p_expected_value then
        v_response := wonder_private.wonder_error('WW_SALE_VALUE_CHANGED', 'The flower value changed. Confirm the new value.', p_idempotency_key, true, v_base, pg_catalog.jsonb_build_object('current_sale_glow', v_current_value, 'server_now', v_now, 'flower_version', v_flower.version));
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
    end if;
    v_ledger := wonder_private.wonder_append_glow_entry(v_user_id, v_current_value, 'sale', p_idempotency_key, p_flower_id);
    update public.wonder_flower_instances set state = 'sold', version = version + 1 where user_id = v_user_id and flower_id = p_flower_id;
    delete from public.wonder_vase_assignments where user_id = v_user_id and flower_id = p_flower_id;
    insert into public.wonder_flower_events (user_id, flower_id, event_type, occurred_at, idempotency_key, sale_glow, glow_amount) values (v_user_id, p_flower_id, 'sold', v_now, p_idempotency_key, v_current_value, v_current_value);
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('flower_id', p_flower_id, 'state', 'sold', 'sale_glow', v_current_value, 'glow_balance', v_ledger.balance_after, 'flower_version', p_expected_version + 1));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
end;
$$;

create or replace function public.wonder_apply_sunshine(
    p_flower_id uuid,
    p_expected_version bigint,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_flower public.wonder_flower_instances%rowtype;
    v_ledger wonder_private.wonder_glow_result;
    v_base bigint;
    v_revision bigint;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_response jsonb;
begin
    if v_user_id is null then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to use Sunshine.', p_idempotency_key, false, 0); end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before using Sunshine.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(v_user_id, p_idempotency_key, 'wonder_apply_sunshine', pg_catalog.jsonb_build_object('flower_id', p_flower_id, 'expected_version', p_expected_version, 'expected_revision', p_expected_revision));
    if v_idempotency.replayed then return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base)); end if;
    if p_expected_revision is null or p_expected_revision <> v_base then v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    perform wonder_private.wonder_process_expired_flowers(v_user_id, v_now);
    if exists (select 1 from public.wonder_hibernate_intervals where user_id = v_user_id and end_utc is null) then v_response := wonder_private.wonder_error('WW_HIBERNATING', 'Sunshine is unavailable during Hibernate.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    select * into v_flower from public.wonder_flower_instances where user_id = v_user_id and flower_id = p_flower_id for update;
    if not found then v_response := wonder_private.wonder_error('WW_FLOWER_NOT_FOUND', 'That flower is not in your garden.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_flower.version <> p_expected_version then v_response := wonder_private.wonder_error('WW_STALE_OBJECT', 'That flower changed. Refresh its arrangement.', p_idempotency_key, true, v_base, pg_catalog.jsonb_build_object('flower_version', v_flower.version)); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_flower.state <> 'living' then v_response := wonder_private.wonder_error('WW_FLOWER_EXPIRED', 'That flower has already faded.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if not exists (select 1 from public.wonder_vase_assignments where user_id = v_user_id and flower_id = p_flower_id) then v_response := wonder_private.wonder_error('WW_NOT_DISPLAYED', 'Display the flower before using Sunshine.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    v_ledger := wonder_private.wonder_append_glow_entry(v_user_id, -20, 'sunshine', p_idempotency_key, p_flower_id);
    update public.wonder_flower_instances set deadline_utc = deadline_utc + interval '1 day', extension_seconds = extension_seconds + 86400, version = version + 1 where user_id = v_user_id and flower_id = p_flower_id;
    insert into public.wonder_flower_events (user_id, flower_id, event_type, occurred_at, idempotency_key, glow_amount) values (v_user_id, p_flower_id, 'sunshine', v_now, p_idempotency_key, -20);
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('flower_id', p_flower_id, 'extension_seconds', v_flower.extension_seconds + 86400, 'glow_balance', v_ledger.balance_after, 'flower_version', p_expected_version + 1));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
end;
$$;

create or replace function public.wonder_assign_shelf_species(
    p_position integer,
    p_species_slug text,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_species_id uuid;
    v_base bigint;
    v_revision bigint;
    v_response jsonb;
begin
    if v_user_id is null then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to arrange the Pressbook.', p_idempotency_key, false, 0); end if;
    if p_position not between 1 and 6 or p_species_slug is null or length(btrim(p_species_slug)) = 0 then return wonder_private.wonder_error('WW_INVALID_REQUEST', 'Choose a valid Pressbook position.', p_idempotency_key, false, 0); end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before arranging the Pressbook.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(v_user_id, p_idempotency_key, 'wonder_assign_shelf_species', pg_catalog.jsonb_build_object('position', p_position, 'species_slug', p_species_slug, 'expected_revision', p_expected_revision));
    if v_idempotency.replayed then return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base)); end if;
    if p_expected_revision is null or p_expected_revision <> v_base then v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    select d.species_id into v_species_id
    from public.wonder_discoveries d join public.wonder_species s on s.species_id = d.species_id
    where d.user_id = v_user_id and s.slug = p_species_slug;
    if v_species_id is null then v_response := wonder_private.wonder_error('WW_NOT_DISCOVERED', 'Discover that flower before placing it in the Pressbook.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if exists (select 1 from public.wonder_shelf_assignments where user_id = v_user_id and position = p_position) then v_response := wonder_private.wonder_error('WW_SHELF_POSITION_TAKEN', 'That Pressbook position is already occupied.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if exists (select 1 from public.wonder_shelf_assignments where user_id = v_user_id and species_id = v_species_id) then v_response := wonder_private.wonder_error('WW_SPECIES_ALREADY_PLACED', 'That species is already in the Pressbook.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    insert into public.wonder_shelf_assignments (user_id, position, species_id) values (v_user_id, p_position, v_species_id);
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('position', p_position, 'species_id', v_species_id, 'species_slug', p_species_slug));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
end;
$$;

create or replace function public.wonder_remove_shelf_species(
    p_position integer,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_species_id uuid;
    v_base bigint;
    v_revision bigint;
    v_response jsonb;
begin
    if v_user_id is null then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to arrange the Pressbook.', p_idempotency_key, false, 0); end if;
    if p_position not between 1 and 6 then return wonder_private.wonder_error('WW_INVALID_REQUEST', 'Choose a valid Pressbook position.', p_idempotency_key, false, 0); end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before arranging the Pressbook.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(v_user_id, p_idempotency_key, 'wonder_remove_shelf_species', pg_catalog.jsonb_build_object('position', p_position, 'expected_revision', p_expected_revision));
    if v_idempotency.replayed then return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base)); end if;
    if p_expected_revision is null or p_expected_revision <> v_base then v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    select species_id into v_species_id from public.wonder_shelf_assignments where user_id = v_user_id and position = p_position for update;
    if v_species_id is null then v_response := wonder_private.wonder_error('WW_SHELF_EMPTY', 'That Pressbook position is already empty.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    delete from public.wonder_shelf_assignments where user_id = v_user_id and position = p_position;
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('position', p_position, 'species_id', v_species_id));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
end;
$$;

create or replace function public.wonder_purchase_shop_item(
    p_item_key text,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_item public.wonder_shop_items%rowtype;
    v_ledger wonder_private.wonder_glow_result;
    v_base bigint;
    v_revision bigint;
    v_response jsonb;
begin
    if v_user_id is null then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to visit the Shop.', p_idempotency_key, false, 0); end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before shopping.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(v_user_id, p_idempotency_key, 'wonder_purchase_shop_item', pg_catalog.jsonb_build_object('item_key', p_item_key, 'expected_revision', p_expected_revision));
    if v_idempotency.replayed then return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base)); end if;
    if p_expected_revision is null or p_expected_revision <> v_base then v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    select * into v_item from public.wonder_shop_items where item_key = p_item_key and active for update;
    if not found then v_response := wonder_private.wonder_error('WW_SHOP_ITEM_UNAVAILABLE', 'That Shop item is unavailable.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if exists (select 1 from public.wonder_player_entitlements where user_id = v_user_id and item_key = p_item_key) then v_response := wonder_private.wonder_error('WW_ALREADY_OWNED', 'That item is already in your garden.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    v_ledger := wonder_private.wonder_append_glow_entry(v_user_id, -v_item.glow_cost, 'shop_purchase', p_idempotency_key, null);
    insert into public.wonder_player_entitlements (user_id, item_key, paid_ledger_id) values (v_user_id, p_item_key, v_ledger.entry_id);
    if v_item.kind = 'vase_slot_unlock' then
        update public.wonder_vase_slots set unlocked = true where user_id = v_user_id and slot = v_item.slot_number;
    end if;
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('item', pg_catalog.to_jsonb(v_item), 'entitlement', pg_catalog.jsonb_build_object('item_key', p_item_key), 'glow_balance', v_ledger.balance_after));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
end;
$$;

create or replace function public.wonder_select_vase_pattern(
    p_slot integer,
    p_pattern_key text,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_slot public.wonder_vase_slots%rowtype;
    v_base bigint;
    v_revision bigint;
    v_response jsonb;
begin
    if v_user_id is null then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to choose a vase pattern.', p_idempotency_key, false, 0); end if;
    if p_slot not between 1 and 3 or p_pattern_key not in ('classic_cream', 'meadow_dots', 'blue_vine') then return wonder_private.wonder_error('WW_INVALID_REQUEST', 'Choose a valid vase pattern.', p_idempotency_key, false, 0); end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before choosing a pattern.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(v_user_id, p_idempotency_key, 'wonder_select_vase_pattern', pg_catalog.jsonb_build_object('slot', p_slot, 'pattern_key', p_pattern_key, 'expected_revision', p_expected_revision));
    if v_idempotency.replayed then return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base)); end if;
    if p_expected_revision is null or p_expected_revision <> v_base then v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    select * into v_slot from public.wonder_vase_slots where user_id = v_user_id and slot = p_slot for update;
    if not found or not v_slot.unlocked then v_response := wonder_private.wonder_error('WW_VASE_LOCKED', 'Unlock that vase before changing its pattern.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if not exists (select 1 from public.wonder_player_entitlements where user_id = v_user_id and item_key = p_pattern_key) then v_response := wonder_private.wonder_error('WW_NOT_OWNED', 'Purchase that pattern before selecting it.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_slot.pattern_key = p_pattern_key then
        v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_base, false, pg_catalog.jsonb_build_object('slot', p_slot, 'pattern_key', p_pattern_key, 'changed', false));
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
    end if;
    update public.wonder_vase_slots set pattern_key = p_pattern_key where user_id = v_user_id and slot = p_slot;
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('slot', p_slot, 'pattern_key', p_pattern_key, 'changed', true));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
end;
$$;

create or replace function public.wonder_sync_steps(
    p_local_date date,
    p_time_zone text,
    p_health_high_water bigint,
    p_fallback_high_water bigint,
    p_mode text,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_credit public.wonder_daily_step_credits%rowtype;
    v_ledger wonder_private.wonder_glow_result;
    v_base bigint;
    v_revision bigint;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_today date;
    v_target integer;
    v_delta integer;
    v_new_health bigint;
    v_new_fallback bigint;
    v_mode text;
    v_changed boolean := false;
    v_response jsonb;
begin
    if v_user_id is null then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to sync steps.', p_idempotency_key, false, 0); end if;
    if p_health_high_water < 0 or p_fallback_high_water < 0 or p_mode not in ('health', 'fallback', 'mixed', 'time_only') then return wonder_private.wonder_error('WW_INVALID_REQUEST', 'Step data is invalid.', p_idempotency_key, false, 0); end if;
    p_time_zone := wonder_private.wonder_require_time_zone(p_time_zone);
    v_today := (v_now at time zone p_time_zone)::date;
    if p_local_date < v_today - 6 or p_local_date > v_today then return wonder_private.wonder_error('WW_INVALID_STEP_DATE', 'Step data must be from the current local day or prior six days.', p_idempotency_key, false, 0); end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before syncing steps.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(v_user_id, p_idempotency_key, 'wonder_sync_steps', pg_catalog.jsonb_build_object('local_date', p_local_date, 'time_zone', p_time_zone, 'health_high_water', p_health_high_water, 'fallback_high_water', p_fallback_high_water, 'mode', p_mode, 'expected_revision', p_expected_revision));
    if v_idempotency.replayed then return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base)); end if;
    if p_expected_revision is null or p_expected_revision <> v_base then v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    insert into public.wonder_daily_step_credits (user_id, local_date, time_zone) values (v_user_id, p_local_date, p_time_zone) on conflict (user_id, local_date) do nothing;
    select * into v_credit from public.wonder_daily_step_credits where user_id = v_user_id and local_date = p_local_date for update;
    v_new_health := greatest(v_credit.health_high_water, p_health_high_water);
    v_new_fallback := greatest(v_credit.fallback_high_water, p_fallback_high_water);
    v_mode := p_mode;
    v_target := case
        when p_mode = 'health' then floor(v_new_health / 100.0)::integer
        when p_mode = 'fallback' then floor(v_new_fallback / 100.0)::integer
        when p_mode = 'mixed' then floor(greatest(v_new_health, v_new_fallback) / 100.0)::integer
        else 0
    end;
    v_delta := greatest(0, v_target - v_credit.credited_glow);
    if exists (
        select 1 from public.wonder_hibernate_intervals h
        where h.user_id = v_user_id and h.start_local_date <= p_local_date
          and (h.end_local_date is null or h.end_local_date >= p_local_date)
    ) then
        v_delta := 0;
    end if;
    if v_delta > 0 then
        v_ledger := wonder_private.wonder_append_glow_entry(v_user_id, v_delta, 'step_credit', p_idempotency_key, null);
    end if;
    if v_new_health <> v_credit.health_high_water or v_new_fallback <> v_credit.fallback_high_water or v_delta > 0 or v_credit.time_zone <> p_time_zone or v_credit.credit_mode <> v_mode then
        update public.wonder_daily_step_credits
        set time_zone = p_time_zone, health_high_water = v_new_health,
            fallback_high_water = v_new_fallback,
            credited_glow = credited_glow + v_delta,
            credit_mode = v_mode, synced_at = v_now
        where user_id = v_user_id and local_date = p_local_date;
        v_changed := true;
    end if;
    if v_changed then v_revision := wonder_private.wonder_increment_revision(v_user_id); else v_revision := v_base; end if;
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('local_date', p_local_date, 'health_high_water', v_new_health, 'fallback_high_water', v_new_fallback, 'credited_glow', v_credit.credited_glow + v_delta, 'credited_delta', v_delta, 'glow_balance', coalesce(v_ledger.balance_after, v_profile.glow_balance), 'hibernate_excluded', v_delta = 0 and exists (select 1 from public.wonder_hibernate_intervals h where h.user_id = v_user_id and h.start_local_date <= p_local_date and (h.end_local_date is null or h.end_local_date >= p_local_date))));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
end;
$$;

create or replace function public.wonder_enter_hibernate(
    p_time_zone text,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_settings public.wonder_player_settings%rowtype;
    v_base bigint;
    v_revision bigint;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_response jsonb;
begin
    if v_user_id is null then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to enter Hibernate.', p_idempotency_key, false, 0); end if;
    p_time_zone := wonder_private.wonder_require_time_zone(p_time_zone);
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before entering Hibernate.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(v_user_id, p_idempotency_key, 'wonder_enter_hibernate', pg_catalog.jsonb_build_object('time_zone', p_time_zone, 'expected_revision', p_expected_revision));
    if v_idempotency.replayed then return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base)); end if;
    if p_expected_revision is null or p_expected_revision <> v_base then v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    select * into v_settings from public.wonder_player_settings where user_id = v_user_id;
    if not coalesce(v_settings.hibernate_enabled, true) then v_response := wonder_private.wonder_error('WW_HIBERNATE_DISABLED', 'Hibernate is disabled in Settings.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if exists (select 1 from public.wonder_hibernate_intervals where user_id = v_user_id and end_utc is null) then v_response := wonder_private.wonder_error('WW_ALREADY_HIBERNATING', 'Hibernate is already active.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    insert into public.wonder_hibernate_intervals (user_id, start_utc, start_local_date, start_time_zone) values (v_user_id, v_now, (v_now at time zone p_time_zone)::date, p_time_zone);
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('active', true, 'start_utc', v_now, 'time_zone', p_time_zone));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
end;
$$;

create or replace function public.wonder_exit_hibernate(
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_interval public.wonder_hibernate_intervals%rowtype;
    v_settings public.wonder_player_settings%rowtype;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_duration integer;
    v_base bigint;
    v_revision bigint;
    v_response jsonb;
begin
    if v_user_id is null then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to leave Hibernate.', p_idempotency_key, false, 0); end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before leaving Hibernate.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(v_user_id, p_idempotency_key, 'wonder_exit_hibernate', pg_catalog.jsonb_build_object('expected_revision', p_expected_revision));
    if v_idempotency.replayed then return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base)); end if;
    if p_expected_revision is null or p_expected_revision <> v_base then v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    select * into v_interval from public.wonder_hibernate_intervals where user_id = v_user_id and end_utc is null for update;
    if not found then v_response := wonder_private.wonder_error('WW_NOT_HIBERNATING', 'Hibernate is not active.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    select * into v_settings from public.wonder_player_settings where user_id = v_user_id;
    update public.wonder_hibernate_intervals
    set end_utc = v_now, end_local_date = (v_now at time zone coalesce(v_settings.time_zone, v_interval.start_time_zone))::date, end_time_zone = coalesce(v_settings.time_zone, v_interval.start_time_zone)
    where interval_id = v_interval.interval_id;
    v_duration := greatest(0, floor(extract(epoch from (v_now - v_interval.start_utc)))::integer);
    if v_duration > 0 then
        update public.wonder_flower_instances
        set deadline_utc = deadline_utc + (v_duration * interval '1 second'), version = version + 1
        where user_id = v_user_id and state = 'living';
    end if;
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('active', false, 'end_utc', v_now, 'duration_seconds', v_duration));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
end;
$$;

create or replace function public.wonder_update_settings(
    p_time_zone text,
    p_step_mode text,
    p_hibernate_enabled boolean,
    p_notifications_enabled boolean,
    p_onboarding_completed boolean,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_settings public.wonder_player_settings%rowtype;
    v_base bigint;
    v_revision bigint;
    v_changed boolean;
    v_response jsonb;
begin
    if v_user_id is null then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to update Settings.', p_idempotency_key, false, 0); end if;
    if p_step_mode not in ('health', 'motion', 'time_only') then return wonder_private.wonder_error('WW_INVALID_REQUEST', 'Choose a supported step mode.', p_idempotency_key, false, 0); end if;
    p_time_zone := wonder_private.wonder_require_time_zone(p_time_zone);
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before updating Settings.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(v_user_id, p_idempotency_key, 'wonder_update_settings', pg_catalog.jsonb_build_object('time_zone', p_time_zone, 'step_mode', p_step_mode, 'hibernate_enabled', p_hibernate_enabled, 'notifications_enabled', p_notifications_enabled, 'onboarding_completed', p_onboarding_completed, 'expected_revision', p_expected_revision));
    if v_idempotency.replayed then return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base)); end if;
    if p_expected_revision is null or p_expected_revision <> v_base then v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    select * into v_settings from public.wonder_player_settings where user_id = v_user_id for update;
    if p_hibernate_enabled = false and exists (select 1 from public.wonder_hibernate_intervals where user_id = v_user_id and end_utc is null) then v_response := wonder_private.wonder_error('WW_ALREADY_HIBERNATING', 'Leave Hibernate before disabling it.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    v_changed := v_settings.time_zone <> p_time_zone or v_settings.step_mode <> p_step_mode or v_settings.hibernate_enabled <> p_hibernate_enabled or v_settings.notifications_enabled <> p_notifications_enabled or v_settings.onboarding_completed <> p_onboarding_completed;
    update public.wonder_player_settings set time_zone = p_time_zone, step_mode = p_step_mode, hibernate_enabled = p_hibernate_enabled, notifications_enabled = p_notifications_enabled, onboarding_completed = p_onboarding_completed, updated_at = timezone('utc', now()) where user_id = v_user_id;
    if v_changed then v_revision := wonder_private.wonder_increment_revision(v_user_id); else v_revision := v_base; end if;
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('settings', (select pg_catalog.to_jsonb(s) from public.wonder_player_settings s where s.user_id = v_user_id), 'changed', v_changed));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
end;
$$;

create or replace function public.wonder_record_ui_event(
    p_event_name text,
    p_domain_id uuid default null,
    p_numeric_value integer default null,
    p_boolean_value boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_time_zone text := 'UTC';
    v_utc_start timestamptz := date_trunc('day', v_now);
    v_utc_date date := v_now::date;
    v_count integer;
begin
    if v_user_id is null then return pg_catalog.jsonb_build_object('accepted', false, 'reason', 'auth_required'); end if;
    if p_event_name not in ('onboarding_completed', 'daily_daisy_granted', 'wander_started', 'wander_tier_resolved', 'wander_tier_cap_rejected', 'flower_action_completed', 'shop_purchase_completed', 'hibernate_changed', 'refresh_after_revision_mismatch') then return pg_catalog.jsonb_build_object('accepted', false, 'reason', 'invalid_event'); end if;
    select time_zone into v_time_zone from public.wonder_player_settings where user_id = v_user_id;
    v_time_zone := coalesce(v_time_zone, 'UTC');
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('telemetry:' || v_user_id::text || ':' || v_utc_date::text, 0));
    select count(*)::integer into v_count from public.wonder_product_events where user_id = v_user_id and occurred_at_utc >= v_utc_start and occurred_at_utc < v_utc_start + interval '1 day';
    if v_count >= 200 then return pg_catalog.jsonb_build_object('accepted', false, 'reason', 'daily_cap'); end if;
    insert into public.wonder_product_events (user_id, event_name, occurred_at_utc, local_date, time_zone, domain_id, numeric_value, boolean_value) values (v_user_id, p_event_name, v_now, (v_now at time zone v_time_zone)::date, v_time_zone, p_domain_id, p_numeric_value, p_boolean_value);
    return pg_catalog.jsonb_build_object('accepted', true, 'occurred_at_utc', v_now);
end;
$$;

create or replace function public.wonder_sync_offline_wander(
    p_session_id uuid,
    p_start_utc timestamptz,
    p_local_date date,
    p_time_zone text,
    p_catalog_version integer,
    p_catalog_checksum text,
    p_offer_slugs text[],
    p_reached_tiers jsonb,
    p_expected_revision bigint,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '2s'
as $$
declare
    v_user_id uuid := auth.uid();
    v_idempotency wonder_private.wonder_idempotency_result;
    v_profile public.wonder_profiles%rowtype;
    v_base bigint;
    v_revision bigint;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_expected_checksum text;
    v_expected_slugs text[];
    v_offer record;
    v_choice record;
    v_species_id uuid;
    v_flower_id uuid;
    v_cap_count integer;
    v_earned_count integer := 0;
    v_rejected_tier integer;
    v_results jsonb := '[]'::jsonb;
    v_response jsonb;
begin
    if v_user_id is null then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to sync the offline Wander.', p_idempotency_key, false, 0); end if;
    if p_session_id is null or p_start_utc is null or p_local_date is null or p_catalog_version is null or p_catalog_checksum is null or p_offer_slugs is null or pg_catalog.array_length(p_offer_slugs, 1) <> 3 then return wonder_private.wonder_error('WW_INVALID_REQUEST', 'The offline Wander payload is incomplete.', p_idempotency_key, false, 0); end if;
    if pg_catalog.array_length(p_offer_slugs, 1) <> 3 or p_offer_slugs[1] = p_offer_slugs[2] or p_offer_slugs[1] = p_offer_slugs[3] or p_offer_slugs[2] = p_offer_slugs[3] then return wonder_private.wonder_error('WW_CATALOG_MISMATCH', 'The offline offer order is not valid.', p_idempotency_key, false, 0); end if;
    if pg_catalog.jsonb_typeof(p_reached_tiers) <> 'array' then return wonder_private.wonder_error('WW_INVALID_OFFLINE_PROOF', 'Offline threshold evidence is invalid.', p_idempotency_key, false, 0); end if;
    p_time_zone := wonder_private.wonder_require_time_zone(p_time_zone);
    if p_start_utc > v_now + interval '5 minutes' then return wonder_private.wonder_error('WW_INVALID_OFFLINE_PROOF', 'The offline start time is in the future.', p_idempotency_key, false, 0); end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before syncing an offline Wander.', p_idempotency_key, false, 0); end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(
        v_user_id, p_idempotency_key, 'wonder_sync_offline_wander',
        pg_catalog.jsonb_build_object(
            'session_id', p_session_id, 'start_utc', p_start_utc, 'local_date', p_local_date,
            'time_zone', p_time_zone, 'catalog_version', p_catalog_version,
            'catalog_checksum', p_catalog_checksum, 'offer_slugs', p_offer_slugs,
            'reached_tiers', p_reached_tiers, 'expected_revision', p_expected_revision
        )
    );
    if v_idempotency.replayed then return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base)); end if;
    if p_expected_revision is null or p_expected_revision <> v_base then v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if exists (select 1 from public.wonder_hibernate_intervals where user_id = v_user_id and end_utc is null) then v_response := wonder_private.wonder_error('WW_HIBERNATING', 'Offline Wander sync is unavailable during Hibernate.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if exists (select 1 from public.wonder_wander_sessions where user_id = v_user_id and state = 'active') then v_response := wonder_private.wonder_error('WW_ACTIVE_WANDER', 'Finish the active Wander before syncing another one.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;

    v_expected_checksum := wonder_private.wonder_catalog_checksum(p_catalog_version);
    if v_expected_checksum <> p_catalog_checksum then v_response := wonder_private.wonder_error('WW_CATALOG_MISMATCH', 'The offline catalog checksum is not current.', p_idempotency_key, false, v_base, pg_catalog.jsonb_build_object('expected_checksum', v_expected_checksum)); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    with eligible as (
        select s.species_id, s.slug,
               extensions.digest(
                   extensions.digest(convert_to(p_session_id::text || ':' || p_catalog_version::text || ':autumn', 'UTF8'), 'sha256')
                   || convert_to(':' || s.slug, 'UTF8'), 'sha256'
               ) as sort_key
        from public.wonder_species s
        where s.source = 'wander' and s.season = 'autumn' and s.active
          and s.introduced_catalog_version <= p_catalog_version
          and (s.retired_catalog_version is null or s.retired_catalog_version > p_catalog_version)
    )
    select pg_catalog.array_agg(slug order by sort_key, slug)
    into v_expected_slugs
    from (select slug, sort_key from eligible order by sort_key, slug limit 3) q;
    if v_expected_slugs is null or v_expected_slugs is distinct from p_offer_slugs then v_response := wonder_private.wonder_error('WW_CATALOG_MISMATCH', 'The offline offer order does not match the retained catalog.', p_idempotency_key, false, v_base, pg_catalog.jsonb_build_object('expected_offer_slugs', v_expected_slugs)); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if exists (select 1 from jsonb_to_recordset(p_reached_tiers) as x(tier integer, species_slug text, elapsed_seconds integer) group by tier having count(*) > 1) then v_response := wonder_private.wonder_error('WW_INVALID_OFFLINE_PROOF', 'Offline tiers must be unique.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;

    insert into public.wonder_wander_sessions (
        session_id, user_id, start_utc, auto_close_utc, end_utc, local_date, time_zone,
        mode, state, offline, catalog_version, catalog_checksum, offer_season, reserved_count
    ) values (
        p_session_id, v_user_id, p_start_utc, p_start_utc + interval '1 hour',
        least(v_now, p_start_utc + interval '1 hour'), p_local_date, p_time_zone,
        'offline', 'closed', true, p_catalog_version, p_catalog_checksum, 'autumn', 0
    );
    for v_offer in
        with eligible as (
            select s.species_id, s.slug,
                   extensions.digest(
                       extensions.digest(convert_to(p_session_id::text || ':' || p_catalog_version::text || ':autumn', 'UTF8'), 'sha256')
                       || convert_to(':' || s.slug, 'UTF8'), 'sha256'
                   ) as sort_key
            from public.wonder_species s
            where s.source = 'wander' and s.season = 'autumn' and s.active
              and s.introduced_catalog_version <= p_catalog_version
              and (s.retired_catalog_version is null or s.retired_catalog_version > p_catalog_version)
        )
        select row_number() over (order by sort_key, slug)::integer as offer_position,
               species_id, slug
        from eligible
        order by sort_key, slug
        limit 3
    loop
        insert into public.wonder_wander_offers (user_id, session_id, position, species_id, species_slug, catalog_version, offer_checksum)
        values (v_user_id, p_session_id, v_offer.offer_position, v_offer.species_id, v_offer.slug, p_catalog_version,
            encode(extensions.digest(p_session_id::text || ':' || p_catalog_version::text || ':autumn:' || v_offer.slug, 'sha256'), 'hex'));
    end loop;

    select count(*)::integer into v_cap_count
    from public.wonder_wander_rewards r join public.wonder_wander_sessions s on s.user_id = r.user_id and s.session_id = r.session_id
    where r.user_id = v_user_id and s.local_date = p_local_date and r.status in ('reserved', 'pending_resolution', 'awarded');
    for v_choice in select * from jsonb_to_recordset(p_reached_tiers) as x(tier integer, species_slug text, elapsed_seconds integer) order by tier loop
        if v_choice.tier not in (10, 20, 30) or v_choice.elapsed_seconds is null or v_choice.elapsed_seconds < v_choice.tier * 60 or v_choice.species_slug is null then v_response := wonder_private.wonder_error('WW_INVALID_OFFLINE_PROOF', 'Offline threshold evidence is invalid.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
        select species_id into v_species_id from public.wonder_wander_offers where user_id = v_user_id and session_id = p_session_id and species_slug = v_choice.species_slug;
        if v_species_id is null then v_response := wonder_private.wonder_error('WW_CATALOG_MISMATCH', 'The offline choice is not one of the persisted offers.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
        if v_cap_count >= 6 then
            insert into public.wonder_wander_rewards (user_id, session_id, tier, status, resolution_mode, rejection_code, resolved_at) values (v_user_id, p_session_id, v_choice.tier, 'rejected', case when v_choice.tier = 30 then 'automatic' else 'player_choice' end, 'WW_DAILY_FLOWER_CAP', v_now);
            v_rejected_tier := coalesce(v_rejected_tier, v_choice.tier);
            v_results := v_results || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('tier', v_choice.tier, 'rejected_tier', v_choice.tier, 'status', 'rejected', 'code', 'WW_DAILY_FLOWER_CAP', 'message', 'Daily flower limit reached.'));
        else
            v_flower_id := wonder_private.wonder_award_flower(v_user_id, v_species_id, 'wander', p_session_id, v_choice.tier, p_start_utc + (v_choice.elapsed_seconds * interval '1 second'), p_time_zone, p_local_date);
            insert into public.wonder_wander_rewards (user_id, session_id, tier, status, resolution_mode, selected_species_id, flower_id, idempotency_key, reached_at, resolved_at) values (v_user_id, p_session_id, v_choice.tier, 'awarded', case when v_choice.tier = 30 then 'automatic' else 'player_choice' end, v_species_id, v_flower_id, p_idempotency_key, p_start_utc + (v_choice.elapsed_seconds * interval '1 second'), v_now);
            v_cap_count := v_cap_count + 1;
            v_earned_count := v_earned_count + 1;
            v_results := v_results || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('tier', v_choice.tier, 'status', 'awarded', 'flower_id', v_flower_id, 'species_slug', v_choice.species_slug));
        end if;
    end loop;
    update public.wonder_wander_sessions set earned_count = v_earned_count where user_id = v_user_id and session_id = p_session_id;
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('session_id', p_session_id, 'offline', true, 'offer_slugs', p_offer_slugs, 'tier_results', v_results, 'rejected_tier', v_rejected_tier));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response;
end;
$$;

do $$
declare
    v_function record;
begin
    for v_function in
        select n.nspname, p.proname,
               pg_catalog.pg_get_function_identity_arguments(p.oid) as identity_arguments
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('public', 'wonder_private')
          and p.proname like 'wonder_%'
    loop
        execute pg_catalog.format(
            'revoke all on function %I.%I(%s) from public, anon, authenticated, service_role',
            v_function.nspname, v_function.proname, v_function.identity_arguments
        );
    end loop;
end;
$$;

grant execute on function public.wonder_auth_gate(text, text) to authenticated;
grant execute on function public.wonder_approve_linked_identity(uuid, bigint, uuid) to authenticated;
grant execute on function public.wonder_bootstrap(text, uuid) to authenticated;
grant execute on function public.wonder_refresh_state() to authenticated;
grant execute on function public.wonder_start_manual_wander(text, uuid, text, bigint, uuid, boolean) to authenticated;
grant execute on function public.wonder_reconcile_wander(uuid, bigint, uuid) to authenticated;
grant execute on function public.wonder_choose_wander_reward(uuid, integer, text, bigint, uuid) to authenticated;
grant execute on function public.wonder_end_wander(uuid, bigint, uuid) to authenticated;
grant execute on function public.wonder_sync_offline_wander(uuid, timestamptz, date, text, integer, text, text[], jsonb, bigint, uuid) to authenticated;
grant execute on function public.wonder_assign_flower_to_vase(uuid, integer, integer, bigint, bigint, uuid) to authenticated;
grant execute on function public.wonder_remove_flower_from_vase(uuid, bigint, bigint, uuid) to authenticated;
grant execute on function public.wonder_press_flower(uuid, bigint, bigint, uuid) to authenticated;
grant execute on function public.wonder_sell_flower(uuid, integer, bigint, bigint, uuid) to authenticated;
grant execute on function public.wonder_apply_sunshine(uuid, bigint, bigint, uuid) to authenticated;
grant execute on function public.wonder_assign_shelf_species(integer, text, bigint, uuid) to authenticated;
grant execute on function public.wonder_remove_shelf_species(integer, bigint, uuid) to authenticated;
grant execute on function public.wonder_purchase_shop_item(text, bigint, uuid) to authenticated;
grant execute on function public.wonder_select_vase_pattern(integer, text, bigint, uuid) to authenticated;
grant execute on function public.wonder_sync_steps(date, text, bigint, bigint, text, bigint, uuid) to authenticated;
grant execute on function public.wonder_enter_hibernate(text, bigint, uuid) to authenticated;
grant execute on function public.wonder_exit_hibernate(bigint, uuid) to authenticated;
grant execute on function public.wonder_update_settings(text, text, boolean, boolean, boolean, bigint, uuid) to authenticated;
grant execute on function public.wonder_record_ui_event(text, uuid, integer, boolean) to authenticated;
grant execute on function public.wonder_start_verified_wander_internal(uuid, uuid, text, bigint, uuid, boolean) to service_role;

commit;
