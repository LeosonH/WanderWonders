begin;

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
    v_hibernate_open boolean;
    v_changed boolean := false;
    v_response jsonb;
begin
    if v_user_id is null then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to sync steps.', p_idempotency_key, false, 0);
    end if;
    if p_health_high_water < 0
       or p_fallback_high_water < 0
       or p_mode not in ('health', 'fallback', 'mixed', 'time_only') then
        return wonder_private.wonder_error('WW_INVALID_REQUEST', 'Step data is invalid.', p_idempotency_key, false, 0);
    end if;

    p_time_zone := wonder_private.wonder_require_time_zone(p_time_zone);
    v_today := (v_now at time zone p_time_zone)::date;
    if p_local_date < v_today - 6 or p_local_date > v_today then
        return wonder_private.wonder_error('WW_INVALID_STEP_DATE', 'Step data must be from the current local day or prior six days.', p_idempotency_key, false, 0);
    end if;

    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile
    from public.wonder_profiles
    where user_id = v_user_id
    for update;
    if not found then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before syncing steps.', p_idempotency_key, false, 0);
    end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(
        v_user_id, p_idempotency_key, 'wonder_sync_steps',
        pg_catalog.jsonb_build_object(
            'local_date', p_local_date,
            'time_zone', p_time_zone,
            'health_high_water', p_health_high_water,
            'fallback_high_water', p_fallback_high_water,
            'mode', p_mode,
            'expected_revision', p_expected_revision
        )
    );
    if v_idempotency.replayed then
        return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base));
    end if;
    if p_expected_revision is null or p_expected_revision <> v_base then
        v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;

    insert into public.wonder_daily_step_credits (
        user_id, local_date, time_zone
    ) values (
        v_user_id, p_local_date, p_time_zone
    ) on conflict (user_id, local_date) do nothing;
    select * into v_credit
    from public.wonder_daily_step_credits
    where user_id = v_user_id and local_date = p_local_date
    for update;

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

    select exists (
        select 1
        from public.wonder_hibernate_intervals h
        where h.user_id = v_user_id
          and h.end_utc is null
          and h.start_local_date <= p_local_date
    ) into v_hibernate_open;
    if v_hibernate_open then
        v_delta := 0;
    end if;

    if v_delta > 0 then
        v_ledger := wonder_private.wonder_append_glow_entry(
            v_user_id, v_delta, 'step_credit', p_idempotency_key, null
        );
    end if;
    if v_new_health <> v_credit.health_high_water
       or v_new_fallback <> v_credit.fallback_high_water
       or v_delta > 0
       or v_credit.time_zone <> p_time_zone
       or v_credit.credit_mode <> v_mode then
        update public.wonder_daily_step_credits
        set time_zone = p_time_zone,
            health_high_water = v_new_health,
            fallback_high_water = v_new_fallback,
            credited_glow = credited_glow + v_delta,
            credit_mode = v_mode,
            synced_at = v_now
        where user_id = v_user_id and local_date = p_local_date;
        v_changed := true;
    end if;

    if v_changed then
        v_revision := wonder_private.wonder_increment_revision(v_user_id);
    else
        v_revision := v_base;
    end if;
    v_response := wonder_private.wonder_mutation_response(
        p_idempotency_key, v_base, v_revision, false,
        pg_catalog.jsonb_build_object(
            'local_date', p_local_date,
            'health_high_water', v_new_health,
            'fallback_high_water', v_new_fallback,
            'credited_glow', v_credit.credited_glow + v_delta,
            'credited_delta', v_delta,
            'glow_balance', coalesce(v_ledger.balance_after, v_profile.glow_balance),
            'hibernate_excluded', v_hibernate_open
        )
    );
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
    return v_response;
end;
$$;

commit;
