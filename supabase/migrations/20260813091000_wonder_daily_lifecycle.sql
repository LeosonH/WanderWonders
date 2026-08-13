begin;

create or replace function wonder_private.wonder_grant_daily_daisy(
    p_user_id uuid,
    p_now timestamptz,
    p_time_zone text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_local_date date := (p_now at time zone p_time_zone)::date;
    v_species_id uuid;
    v_flower_id uuid;
begin
    if exists (
        select 1
        from public.wonder_hibernate_intervals
        where user_id = p_user_id and end_utc is null
    ) or exists (
        select 1
        from public.wonder_daily_grants
        where user_id = p_user_id
          and local_date = v_local_date
          and grant_type = 'daily_daisy'
    ) then
        return null;
    end if;

    select species_id
    into v_species_id
    from public.wonder_species
    where slug = 'daisy' and source = 'daily' and active;

    if v_species_id is null then
        raise exception 'WW_CATALOG_CORRUPT' using errcode = '22023';
    end if;

    v_flower_id := wonder_private.wonder_award_flower(
        p_user_id, v_species_id, 'daily', null, null,
        p_now, p_time_zone, v_local_date
    );

    insert into public.wonder_daily_grants (
        user_id, local_date, grant_type, time_zone, flower_id, granted_at
    ) values (
        p_user_id, v_local_date, 'daily_daisy', p_time_zone, v_flower_id, p_now
    );

    return v_flower_id;
end;
$$;

revoke all on function wonder_private.wonder_grant_daily_daisy(uuid, timestamptz, text)
from public, anon, authenticated, service_role;

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
        select flower_id, species_id
        from public.wonder_flower_instances
        where user_id = p_user_id
          and state = 'living'
          and deadline_utc <= p_now
        for update
    loop
        update public.wonder_flower_instances
        set state = 'pressed', version = version + 1
        where user_id = p_user_id
          and flower_id = v_flower.flower_id
          and state = 'living';

        delete from public.wonder_vase_assignments
        where user_id = p_user_id and flower_id = v_flower.flower_id;

        update public.wonder_discoveries
        set pressed_count = pressed_count + 1
        where user_id = p_user_id and species_id = v_flower.species_id;

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
begin
    select *
    into v_session
    from public.wonder_wander_sessions
    where user_id = p_user_id and session_id = p_session_id
    for update;

    if not found then
        raise exception 'WW_WANDER_NOT_FOUND' using errcode = '22023';
    end if;

    v_elapsed := greatest(
        0,
        least(3600, floor(extract(epoch from (p_now - v_session.start_utc)))::integer)
    );

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
        where user_id = p_user_id
          and session_id = p_session_id
          and tier = v_reward.tier;
        v_changed := true;
    end loop;

    if v_elapsed >= 1800
       and not exists (
           select 1
           from public.wonder_wander_rewards
           where user_id = p_user_id
             and session_id = p_session_id
             and tier in (10, 20)
             and status not in ('awarded', 'rejected', 'released')
       )
       and exists (
           select 1
           from public.wonder_wander_rewards
           where user_id = p_user_id
             and session_id = p_session_id
             and tier = 30
             and status = 'pending_resolution'
       ) then
        select o.species_id
        into v_remaining_species
        from public.wonder_wander_offers o
        where o.user_id = p_user_id
          and o.session_id = p_session_id
          and not exists (
              select 1
              from public.wonder_wander_rewards r
              where r.user_id = p_user_id
                and r.session_id = p_session_id
                and r.selected_species_id = o.species_id
                and r.status = 'awarded'
          )
        order by o.position
        limit 1;

        if v_remaining_species is not null then
            v_auto_flower := wonder_private.wonder_award_flower(
                p_user_id, v_remaining_species, 'wander', p_session_id, 30,
                p_now, v_session.time_zone, v_session.local_date
            );
            update public.wonder_wander_rewards
            set status = 'awarded',
                selected_species_id = v_remaining_species,
                flower_id = v_auto_flower,
                resolved_at = p_now
            where user_id = p_user_id
              and session_id = p_session_id
              and tier = 30;
            update public.wonder_wander_sessions
            set earned_count = earned_count + 1
            where user_id = p_user_id and session_id = p_session_id;
            v_changed := true;
        end if;
    end if;

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

    update public.wonder_wander_sessions s
    set reserved_count = (
        select count(*)::integer
        from public.wonder_wander_rewards r
        where r.user_id = p_user_id
          and r.session_id = p_session_id
          and r.status in ('reserved', 'pending_resolution')
    )
    where s.user_id = p_user_id and s.session_id = p_session_id;

    select min(tier)
    into v_earliest
    from public.wonder_wander_rewards
    where user_id = p_user_id
      and session_id = p_session_id
      and status = 'pending_resolution';

    return (
        v_changed,
        (select state
         from public.wonder_wander_sessions
         where user_id = p_user_id and session_id = p_session_id),
        v_elapsed,
        v_earliest,
        v_auto_flower
    )::wonder_private.wonder_reconcile_state;
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
    v_reconcile wonder_private.wonder_reconcile_state;
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
        v_reconcile := wonder_private.wonder_reconcile_session(
            p_user_id, v_session.session_id, p_now
        );
        if v_reconcile.changed then
            v_count := v_count + 1;
        end if;
    end loop;
    return v_count;
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
    v_daisy uuid;
    v_rows integer;
    v_created boolean := false;
    v_changed boolean := false;
    v_response jsonb;
begin
    if v_user_id is null then
        return wonder_private.wonder_error(
            'WW_AUTH_REQUIRED', 'Sign in before opening the garden.',
            p_idempotency_key, false, 0
        );
    end if;
    if not exists (
        select 1
        from public.wonder_account_identities
        where user_id = v_user_id and approval in ('initial', 'explicit_link')
    ) then
        return wonder_private.wonder_error(
            'WW_IDENTITY_NOT_APPROVED',
            'Approve this sign-in identity before opening the garden.',
            p_idempotency_key, false, 0
        );
    end if;

    p_time_zone := wonder_private.wonder_require_time_zone(p_time_zone);
    perform wonder_private.wonder_lock_player(v_user_id);

    insert into public.wonder_profiles (user_id)
    values (v_user_id)
    on conflict (user_id) do nothing;
    v_created := found;
    v_changed := v_created;

    select *
    into v_profile
    from public.wonder_profiles
    where user_id = v_user_id
    for update;
    v_base := v_profile.state_revision;

    v_idempotency := wonder_private.wonder_begin_idempotency(
        v_user_id, p_idempotency_key, 'wonder_bootstrap',
        pg_catalog.jsonb_build_object('time_zone', p_time_zone)
    );
    if v_idempotency.replayed then
        return coalesce(
            v_idempotency.response_json,
            wonder_private.wonder_error(
                'WW_RETRYABLE_IN_FLIGHT',
                'The request is still being finalized.',
                p_idempotency_key, true, v_base
            )
        );
    end if;

    insert into public.wonder_player_settings (user_id, time_zone)
    values (v_user_id, p_time_zone)
    on conflict (user_id) do update
        set time_zone = excluded.time_zone,
            updated_at = timezone('utc', now())
        where public.wonder_player_settings.time_zone is distinct from excluded.time_zone;
    get diagnostics v_rows = row_count;
    v_changed := v_changed or v_rows > 0;

    insert into public.wonder_vase_slots (user_id, slot, capacity, unlocked)
    values
        (v_user_id, 1, 1, true),
        (v_user_id, 2, 2, false),
        (v_user_id, 3, 3, false)
    on conflict (user_id, slot) do nothing;
    get diagnostics v_rows = row_count;
    v_changed := v_changed or v_rows > 0;

    insert into public.wonder_player_entitlements (user_id, item_key)
    select v_user_id, item_key
    from public.wonder_shop_items
    where item_key = 'classic_cream'
    on conflict (user_id, item_key) do nothing;
    get diagnostics v_rows = row_count;
    v_changed := v_changed or v_rows > 0;

    v_daisy := wonder_private.wonder_grant_daily_daisy(
        v_user_id, v_now, p_time_zone
    );
    v_changed := v_changed or v_daisy is not null;

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
    perform wonder_private.wonder_finish_idempotency(
        v_user_id, p_idempotency_key, v_response
    );
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
    v_time_zone text;
    v_daisy uuid;
    v_changed boolean := false;
    v_revision bigint;
begin
    if v_user_id is null then
        return wonder_private.wonder_error(
            'WW_AUTH_REQUIRED', 'Sign in to refresh the garden.', null, false, 0
        );
    end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    if not exists (
        select 1 from public.wonder_profiles where user_id = v_user_id
    ) then
        return wonder_private.wonder_error(
            'WW_AUTH_REQUIRED', 'Open the garden before refreshing it.',
            null, false, 0
        );
    end if;

    if wonder_private.wonder_close_stale_wander(v_user_id, v_now) > 0 then
        v_changed := true;
    end if;
    if wonder_private.wonder_process_expired_flowers(v_user_id, v_now) > 0 then
        v_changed := true;
    end if;

    select coalesce(time_zone, 'UTC')
    into v_time_zone
    from public.wonder_player_settings
    where user_id = v_user_id;
    v_time_zone := coalesce(v_time_zone, 'UTC');
    v_daisy := wonder_private.wonder_grant_daily_daisy(
        v_user_id, v_now, v_time_zone
    );
    v_changed := v_changed or v_daisy is not null;

    if v_changed then
        v_revision := wonder_private.wonder_increment_revision(v_user_id);
    else
        select state_revision
        into v_revision
        from public.wonder_profiles
        where user_id = v_user_id;
    end if;

    return pg_catalog.jsonb_build_object(
        'ok', true,
        'server_now', v_now,
        'state_revision', v_revision,
        'snapshot', wonder_private.wonder_build_snapshot(v_user_id, v_now)
    );
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
    if v_user_id is null then
        return wonder_private.wonder_error(
            'WW_AUTH_REQUIRED', 'Sign in to enter Hibernate.',
            p_idempotency_key, false, 0
        );
    end if;
    p_time_zone := wonder_private.wonder_require_time_zone(p_time_zone);
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile
    from public.wonder_profiles
    where user_id = v_user_id
    for update;
    if not found then
        return wonder_private.wonder_error(
            'WW_AUTH_REQUIRED', 'Open the garden before entering Hibernate.',
            p_idempotency_key, false, 0
        );
    end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(
        v_user_id, p_idempotency_key, 'wonder_enter_hibernate',
        pg_catalog.jsonb_build_object(
            'time_zone', p_time_zone,
            'expected_revision', p_expected_revision
        )
    );
    if v_idempotency.replayed then
        return coalesce(
            v_idempotency.response_json,
            wonder_private.wonder_error(
                'WW_RETRYABLE_IN_FLIGHT',
                'The request is still being finalized.',
                p_idempotency_key, true, v_base
            )
        );
    end if;
    if p_expected_revision is null or p_expected_revision <> v_base then
        v_response := wonder_private.wonder_error(
            'WW_STALE_REVISION',
            'Your saved garden changed. Refresh and try again.',
            p_idempotency_key, true, v_base
        );
        perform wonder_private.wonder_finish_idempotency(
            v_user_id, p_idempotency_key, v_response
        );
        return v_response;
    end if;

    select * into v_settings
    from public.wonder_player_settings
    where user_id = v_user_id;
    if not coalesce(v_settings.hibernate_enabled, true) then
        v_response := wonder_private.wonder_error(
            'WW_HIBERNATE_DISABLED', 'Hibernate is disabled in Settings.',
            p_idempotency_key, false, v_base
        );
        perform wonder_private.wonder_finish_idempotency(
            v_user_id, p_idempotency_key, v_response
        );
        return v_response;
    end if;
    if exists (
        select 1
        from public.wonder_hibernate_intervals
        where user_id = v_user_id and end_utc is null
    ) then
        v_response := wonder_private.wonder_error(
            'WW_ALREADY_HIBERNATING', 'Hibernate is already active.',
            p_idempotency_key, false, v_base
        );
        perform wonder_private.wonder_finish_idempotency(
            v_user_id, p_idempotency_key, v_response
        );
        return v_response;
    end if;

    perform wonder_private.wonder_process_expired_flowers(v_user_id, v_now);
    insert into public.wonder_hibernate_intervals (
        user_id, start_utc, start_local_date, start_time_zone
    ) values (
        v_user_id, v_now, (v_now at time zone p_time_zone)::date, p_time_zone
    );
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(
        p_idempotency_key, v_base, v_revision, false,
        pg_catalog.jsonb_build_object(
            'active', true,
            'start_utc', v_now,
            'time_zone', p_time_zone
        )
    );
    perform wonder_private.wonder_finish_idempotency(
        v_user_id, p_idempotency_key, v_response
    );
    return v_response;
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
    v_daisy uuid;
    v_base bigint;
    v_revision bigint;
    v_response jsonb;
begin
    if v_user_id is null then
        return wonder_private.wonder_error(
            'WW_AUTH_REQUIRED', 'Sign in to leave Hibernate.',
            p_idempotency_key, false, 0
        );
    end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile
    from public.wonder_profiles
    where user_id = v_user_id
    for update;
    if not found then
        return wonder_private.wonder_error(
            'WW_AUTH_REQUIRED', 'Open the garden before leaving Hibernate.',
            p_idempotency_key, false, 0
        );
    end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(
        v_user_id, p_idempotency_key, 'wonder_exit_hibernate',
        pg_catalog.jsonb_build_object('expected_revision', p_expected_revision)
    );
    if v_idempotency.replayed then
        return coalesce(
            v_idempotency.response_json,
            wonder_private.wonder_error(
                'WW_RETRYABLE_IN_FLIGHT',
                'The request is still being finalized.',
                p_idempotency_key, true, v_base
            )
        );
    end if;
    if p_expected_revision is null or p_expected_revision <> v_base then
        v_response := wonder_private.wonder_error(
            'WW_STALE_REVISION',
            'Your saved garden changed. Refresh and try again.',
            p_idempotency_key, true, v_base
        );
        perform wonder_private.wonder_finish_idempotency(
            v_user_id, p_idempotency_key, v_response
        );
        return v_response;
    end if;

    select * into v_interval
    from public.wonder_hibernate_intervals
    where user_id = v_user_id and end_utc is null
    for update;
    if not found then
        v_response := wonder_private.wonder_error(
            'WW_NOT_HIBERNATING', 'Hibernate is not active.',
            p_idempotency_key, false, v_base
        );
        perform wonder_private.wonder_finish_idempotency(
            v_user_id, p_idempotency_key, v_response
        );
        return v_response;
    end if;

    select * into v_settings
    from public.wonder_player_settings
    where user_id = v_user_id;
    update public.wonder_hibernate_intervals
    set end_utc = v_now,
        end_local_date = (
            v_now at time zone coalesce(
                v_settings.time_zone, v_interval.start_time_zone
            )
        )::date,
        end_time_zone = coalesce(
            v_settings.time_zone, v_interval.start_time_zone
        )
    where interval_id = v_interval.interval_id;

    v_duration := greatest(
        0,
        floor(extract(epoch from (v_now - v_interval.start_utc)))::integer
    );
    if v_duration > 0 then
        update public.wonder_flower_instances
        set deadline_utc = deadline_utc + (v_duration * interval '1 second'),
            version = version + 1
        where user_id = v_user_id and state = 'living';
    end if;

    v_daisy := wonder_private.wonder_grant_daily_daisy(
        v_user_id,
        v_now,
        coalesce(v_settings.time_zone, v_interval.start_time_zone)
    );
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(
        p_idempotency_key, v_base, v_revision, false,
        pg_catalog.jsonb_build_object(
            'active', false,
            'end_utc', v_now,
            'duration_seconds', v_duration,
            'daily_flower_id', v_daisy
        )
    );
    perform wonder_private.wonder_finish_idempotency(
        v_user_id, p_idempotency_key, v_response
    );
    return v_response;
end;
$$;

commit;
