begin;

select plan(40);

select ok(
    exists (
        select 1
        from pg_catalog.pg_roles
        where rolname = 'authenticated'
          and rolconfig @> array['statement_timeout=5s']
    )
    and exists (
        select 1
        from pg_catalog.pg_roles
        where rolname = 'service_role'
          and rolconfig @> array['statement_timeout=5s']
    ),
    'authenticated and service_role have the dedicated five-second role timeout'
);

select is(
    (
        select count(*)::integer
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('public', 'wonder_private')
          and p.proname like 'wonder_%'
          and exists (
              select 1
              from unnest(coalesce(p.proconfig, array[]::text[])) as c(value)
              where value like 'statement_timeout=%'
          )
    ),
    0,
    'no wonder function declares a function-level statement timeout'
);

select is(
    (
        select count(*)::integer
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
          and p.proname like 'wonder_%'
          and p.proname not in ('wonder_auth_gate', 'wonder_refresh_state')
          and exists (
              select 1
              from unnest(coalesce(p.proconfig, array[]::text[])) as c(value)
              where value = 'search_path=""'
          )
          and exists (
              select 1
              from unnest(coalesce(p.proconfig, array[]::text[])) as c(value)
              where value = 'lock_timeout=2s'
          )
    ),
    22,
    'every state-changing public RPC has the empty search path and two-second lock timeout'
);

select is(
    (
        select count(*)::integer
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
          and p.proname like 'wonder_%'
          and has_function_privilege('authenticated', p.oid, 'execute')
    ),
    23,
    'authenticated receives exactly the reviewed public RPC allowlist'
);

select is(
    (
        select count(*)::integer
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
          and p.proname like 'wonder_%'
          and has_function_privilege('service_role', p.oid, 'execute')
    ),
    1,
    'service_role receives only the verified Wander RPC'
);

insert into auth.users (id)
values ('00000000-0000-0000-0000-000000000101'::uuid);

insert into public.wonder_profiles (user_id)
values ('00000000-0000-0000-0000-000000000101'::uuid);

insert into public.wonder_account_identities (
    user_id, provider, provider_identity_id, approval
)
values (
    '00000000-0000-0000-0000-000000000101'::uuid,
    'apple', 'fixture-apple-101', 'initial'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000101', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000101","role":"authenticated"}', true);

select is(
    (public.wonder_bootstrap('America/Los_Angeles', '00000000-0000-0000-0000-000000000201'::uuid)->>'ok'),
    'true',
    'bootstrap returns a successful typed response'
);

select is(
    (select count(*)::integer from public.wonder_daily_grants where user_id = '00000000-0000-0000-0000-000000000101'::uuid),
    1,
    'bootstrap grants one Daisy'
);

select is(
    (select count(*)::integer from public.wonder_vase_slots where user_id = '00000000-0000-0000-0000-000000000101'::uuid),
    3,
    'bootstrap creates all vase slots'
);

select is(
    (public.wonder_start_manual_wander(
        'manual', '00000000-0000-0000-0000-000000000202'::uuid,
        'America/Los_Angeles', 1, '00000000-0000-0000-0000-000000000202'::uuid, false
    )->>'ok'),
    'true',
    'online manual start returns a successful typed response'
);

select is(
    (select count(*)::integer from public.wonder_wander_offers where session_id = '00000000-0000-0000-0000-000000000202'::uuid),
    3,
    'online start persists exactly three distinct offers'
);

select is(
    (select count(*)::integer from public.wonder_wander_rewards where session_id = '00000000-0000-0000-0000-000000000202'::uuid),
    3,
    'online start persists three reserved daily tiers'
);

update public.wonder_wander_sessions
set start_utc = now() - interval '10 minutes',
    auto_close_utc = now() - interval '10 minutes' + interval '1 hour'
where session_id = '00000000-0000-0000-0000-000000000202'::uuid;

select is(
    (public.wonder_reconcile_wander('00000000-0000-0000-0000-000000000202'::uuid, 2, '00000000-0000-0000-0000-000000000203'::uuid)->>'ok'),
    'true',
    'reconcile advances the ten-minute threshold'
);

select is(
    (select count(*)::integer from public.wonder_wander_rewards where session_id = '00000000-0000-0000-0000-000000000202'::uuid and tier = 10 and status = 'pending_resolution'),
    1,
    'ten-minute tier becomes pending resolution'
);

select is(
    (public.wonder_choose_wander_reward(
        '00000000-0000-0000-0000-000000000202'::uuid, 10,
        (select species_slug from public.wonder_wander_offers where session_id = '00000000-0000-0000-0000-000000000202'::uuid and position = 1),
        3, '00000000-0000-0000-0000-000000000204'::uuid
    )->>'ok'),
    'true',
    'tier ten choice awards one flower'
);

select is(
    (select count(*)::integer from public.wonder_flower_instances where user_id = '00000000-0000-0000-0000-000000000101'::uuid and source = 'wander'),
    1,
    'tier ten creates exactly one Wander flower'
);

select is(
    (public.wonder_choose_wander_reward(
        '00000000-0000-0000-0000-000000000202'::uuid, 10,
        (select species_slug from public.wonder_wander_offers where session_id = '00000000-0000-0000-0000-000000000202'::uuid and position = 1),
        3, '00000000-0000-0000-0000-000000000204'::uuid
    )->>'replayed'),
    'true',
    'repeating the choice request replays the stored response'
);

select is(
    (select count(*)::integer from public.wonder_flower_instances where user_id = '00000000-0000-0000-0000-000000000101'::uuid and source = 'wander'),
    1,
    'replayed choice does not create a duplicate flower'
);

select throws_ok(
$$
    select public.wonder_choose_wander_reward(
        '00000000-0000-0000-0000-000000000202'::uuid, 10,
        (select species_slug from public.wonder_wander_offers where session_id = '00000000-0000-0000-0000-000000000202'::uuid and position = 2),
        3, '00000000-0000-0000-0000-000000000204'::uuid
    );
$$,
'22023',
null,
'reusing one request UUID with a different canonical payload is rejected'
);

update public.wonder_wander_sessions
set start_utc = now() - interval '20 minutes',
    auto_close_utc = now() - interval '20 minutes' + interval '1 hour'
where session_id = '00000000-0000-0000-0000-000000000202'::uuid;

select is(
    (public.wonder_reconcile_wander('00000000-0000-0000-0000-000000000202'::uuid, 4, '00000000-0000-0000-0000-000000000205'::uuid)->>'ok'),
    'true',
    'reconcile advances the twenty-minute threshold'
);

select is(
    (public.wonder_choose_wander_reward(
        '00000000-0000-0000-0000-000000000202'::uuid, 20,
        (select species_slug from public.wonder_wander_offers where session_id = '00000000-0000-0000-0000-000000000202'::uuid and position = 2),
        5, '00000000-0000-0000-0000-000000000206'::uuid
    )->>'ok'),
    'true',
    'tier twenty choice awards the second flower'
);

update public.wonder_wander_sessions
set start_utc = now() - interval '30 minutes',
    auto_close_utc = now() - interval '30 minutes' + interval '1 hour'
where session_id = '00000000-0000-0000-0000-000000000202'::uuid;

select is(
    (public.wonder_reconcile_wander('00000000-0000-0000-0000-000000000202'::uuid, 6, '00000000-0000-0000-0000-000000000207'::uuid)->>'ok'),
    'true',
    'reconcile awards the final automatic tier at thirty minutes'
);

select is(
    (select count(*)::integer from public.wonder_wander_rewards where session_id = '00000000-0000-0000-0000-000000000202'::uuid and status = 'awarded'),
    3,
    'all three online tiers are awarded exactly once'
);

select is(
    (select count(*)::integer from public.wonder_flower_instances where user_id = '00000000-0000-0000-0000-000000000101'::uuid and state = 'living'),
    4,
    'Daisy plus three Wander flowers are living'
);

select is(
    (public.wonder_end_wander('00000000-0000-0000-0000-000000000202'::uuid, 7, '00000000-0000-0000-0000-000000000208'::uuid)->>'ok'),
    'true',
    'ending a Wander closes the session'
);

select is(
    (select count(*)::integer from public.wonder_wander_sessions where session_id = '00000000-0000-0000-0000-000000000202'::uuid and state = 'closed'),
    1,
    'ended Wander is durably closed'
);

select is(
    (public.wonder_assign_flower_to_vase(
        (select flower_id from public.wonder_daily_grants where user_id = '00000000-0000-0000-0000-000000000101'::uuid limit 1),
        1, 1, 0, 8, '00000000-0000-0000-0000-000000000209'::uuid
    )->>'ok'),
    'true',
    'a living flower can be assigned to an unlocked vase'
);

select is(
    (public.wonder_sell_flower(
        (select flower_id from public.wonder_daily_grants where user_id = '00000000-0000-0000-0000-000000000101'::uuid limit 1),
        5, 1, 9, '00000000-0000-0000-0000-000000000210'::uuid
    )->>'ok'),
    'true',
    'selling uses the authoritative value and flower version'
);

select is(
    (select count(*)::integer from public.wonder_flower_instances f join public.wonder_daily_grants g on g.flower_id = f.flower_id where f.state = 'sold'),
    1,
    'sold flower becomes terminal'
);

select is(
    (select glow_balance from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000101'::uuid),
    5,
    'sale appends five Glow atomically'
);

select is(
    (public.wonder_sync_steps(current_date, 'UTC', 100, 0, 'health', 10, '00000000-0000-0000-0000-000000000211'::uuid)->>'ok'),
    'true',
    'step sync credits Glow through the same revision path'
);

select is(
    (select glow_balance from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000101'::uuid),
    6,
    'one hundred steps credit one Glow'
);

select is(
    (public.wonder_enter_hibernate('UTC', 11, '00000000-0000-0000-0000-000000000212'::uuid)->>'ok'),
    'true',
    'Hibernate entry is an authoritative mutation'
);

select is(
    (public.wonder_exit_hibernate(12, '00000000-0000-0000-0000-000000000213'::uuid)->>'ok'),
    'true',
    'Hibernate exit closes the interval and resumes deadlines'
);

select is(
    (select count(*)::integer from public.wonder_hibernate_intervals where user_id = '00000000-0000-0000-0000-000000000101'::uuid and end_utc is not null),
    1,
    'Hibernate interval is durably closed'
);

select lives_ok(
$$
do $offline$
declare
    v_session uuid := '00000000-0000-0000-0000-000000000214'::uuid;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_date date := (select local_date from public.wonder_wander_sessions where session_id = '00000000-0000-0000-0000-000000000202'::uuid);
    v_slugs text[];
    v_checksum text := wonder_private.wonder_catalog_checksum(1);
    v_result jsonb;
begin
    with eligible as (
        select s.slug,
               extensions.digest(
                   extensions.digest(convert_to(v_session::text || ':1:autumn', 'UTF8'), 'sha256')
                   || convert_to(':' || s.slug, 'UTF8'), 'sha256'
               ) as sort_key
        from public.wonder_species s
        where s.source = 'wander' and s.season = 'autumn' and s.active
    )
    select array_agg(slug order by sort_key, slug)
    into v_slugs
    from (select slug, sort_key from eligible order by sort_key, slug limit 3) q;
    v_result := public.wonder_sync_offline_wander(
        v_session, v_now - interval '5 minutes', v_date, 'UTC', 1, v_checksum,
        v_slugs,
        jsonb_build_array(jsonb_build_object('tier', 10, 'species_slug', v_slugs[1], 'elapsed_seconds', 600)),
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000101'::uuid),
        '00000000-0000-0000-0000-000000000215'::uuid
    );
    if coalesce((v_result->>'ok')::boolean, false) is not true then
        raise exception 'offline sync failed: %', v_result;
    end if;
end;
$offline$;
$$,
'offline sync accepts the canonical retained offer order'
);

select is(
    (select count(*)::integer from public.wonder_flower_instances where session_id = '00000000-0000-0000-0000-000000000214'::uuid and state = 'living'),
    1,
    'offline sync awards the accepted reached tier once'
);

insert into public.wonder_wander_sessions (
    session_id, user_id, start_utc, auto_close_utc, end_utc, local_date, time_zone,
    mode, state, offline, catalog_version, catalog_checksum, offer_season, earned_count
)
select
    '00000000-0000-0000-0000-000000000216'::uuid,
    '00000000-0000-0000-0000-000000000101'::uuid,
    now() - interval '20 minutes', now() - interval '20 minutes' + interval '1 hour', now(),
    local_date, 'UTC', 'offline', 'closed', true, 1, wonder_private.wonder_catalog_checksum(1), 'autumn', 1
from public.wonder_wander_sessions
where session_id = '00000000-0000-0000-0000-000000000202'::uuid;

insert into public.wonder_flower_instances (
    flower_id, user_id, species_id, source, session_id, tier, acquired_at,
    duration_seconds, deadline_utc
)
values
    ('00000000-0000-0000-0000-000000000216'::uuid, '00000000-0000-0000-0000-000000000101'::uuid, (select species_id from public.wonder_species where slug = 'aster'), 'wander', '00000000-0000-0000-0000-000000000216'::uuid, 10, now(), 259200, now() + interval '3 days');

insert into public.wonder_wander_rewards (
    user_id, session_id, tier, status, resolution_mode, selected_species_id, flower_id, reached_at, resolved_at
)
values
    ('00000000-0000-0000-0000-000000000101'::uuid, '00000000-0000-0000-0000-000000000216'::uuid, 10, 'awarded', 'player_choice', (select species_id from public.wonder_species where slug = 'aster'), '00000000-0000-0000-0000-000000000216'::uuid, now(), now()),
    ('00000000-0000-0000-0000-000000000101'::uuid, '00000000-0000-0000-0000-000000000216'::uuid, 20, 'pending_resolution', 'player_choice', null, null, now(), null);

select lives_ok(
$$
do $offlinecap$
declare
    v_session uuid := '00000000-0000-0000-0000-000000000218'::uuid;
    v_now timestamptz := timezone('utc', clock_timestamp());
    v_date date := (select local_date from public.wonder_wander_sessions where session_id = '00000000-0000-0000-0000-000000000202'::uuid);
    v_slugs text[];
    v_result jsonb;
begin
    with eligible as (
        select s.slug,
               extensions.digest(
                   extensions.digest(convert_to(v_session::text || ':1:autumn', 'UTF8'), 'sha256')
                   || convert_to(':' || s.slug, 'UTF8'), 'sha256'
               ) as sort_key
        from public.wonder_species s
        where s.source = 'wander' and s.season = 'autumn' and s.active
    )
    select array_agg(slug order by sort_key, slug)
    into v_slugs
    from (select slug, sort_key from eligible order by sort_key, slug limit 3) q;
    v_result := public.wonder_sync_offline_wander(
        v_session, v_now - interval '5 minutes', v_date, 'UTC', 1,
        wonder_private.wonder_catalog_checksum(1), v_slugs,
        jsonb_build_array(jsonb_build_object('tier', 10, 'species_slug', v_slugs[1], 'elapsed_seconds', 600)),
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000101'::uuid),
        '00000000-0000-0000-0000-000000000219'::uuid
    );
    if coalesce((v_result->>'ok')::boolean, false) is not true then
        raise exception 'offline cap sync failed: %', v_result;
    end if;
    if v_result->'delta'->>'rejected_tier' <> '10' then
        raise exception 'expected rejected_tier=10, got %', v_result;
    end if;
end;
$offlinecap$;
$$,
'unreserved offline tier is durably rejected at the six-flower cap'
);

select is(
    (select count(*)::integer from public.wonder_wander_rewards where session_id = '00000000-0000-0000-0000-000000000218'::uuid and status = 'rejected' and rejection_code = 'WW_DAILY_FLOWER_CAP'),
    1,
    'offline cap rejection names and persists the rejected tier'
);

select is(
    (select count(*)::integer from public.wonder_wander_rewards where session_id = '00000000-0000-0000-0000-000000000216'::uuid and tier = 20 and status = 'pending_resolution'),
    1,
    'a reached online reservation remains protected during later cap use'
);

insert into public.wonder_product_events (
    user_id, event_name, occurred_at_utc, local_date, time_zone
)
select
    '00000000-0000-0000-0000-000000000101'::uuid,
    'wander_started', timezone('utc', now()), current_date, 'UTC'
from generate_series(1, 200);

select is(
    (public.wonder_record_ui_event('wander_started')->>'accepted'),
    'false',
    'UI telemetry returns a non-error daily cap receipt at 200 rows'
);

select * from finish();
rollback;
