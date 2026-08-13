begin;

select plan(51);

insert into auth.users (id)
values ('00000000-0000-0000-0000-000000000501'::uuid);

insert into auth.identities (
    id, provider_id, user_id, identity_data, provider
) values (
    '00000000-0000-0000-0000-000000000502'::uuid,
    'apple-provider-501',
    '00000000-0000-0000-0000-000000000501'::uuid,
    '{"sub":"apple-provider-501"}'::jsonb,
    'apple'
);

select is(
    (select count(*)::integer from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
    1,
    'supported Auth identity creates the game profile'
);

select is(
    (select approval from public.wonder_account_identities where identity_id = '00000000-0000-0000-0000-000000000502'::uuid),
    'initial',
    'first supported Auth identity is registered as initial'
);

insert into auth.identities (
    id, provider_id, user_id, identity_data, provider
) values (
    '00000000-0000-0000-0000-000000000503'::uuid,
    'google-provider-501',
    '00000000-0000-0000-0000-000000000501'::uuid,
    '{"sub":"google-provider-501"}'::jsonb,
    'google'
);

select is(
    (select approval from public.wonder_account_identities where identity_id = '00000000-0000-0000-0000-000000000503'::uuid),
    'explicit_link',
    'later supported Auth identity is registered as an explicit link'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000501', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000501","role":"authenticated"}', true);

select is(
    (public.wonder_auth_gate('apple', 'apple-provider-501')->>'gate'),
    'approved',
    'registered Auth identity passes the game auth gate'
);

select is(
    (public.wonder_bootstrap('America/Los_Angeles', '00000000-0000-0000-0000-000000000510'::uuid)->>'ok'),
    'true',
    'Auth-created profile bootstraps the garden'
);

select is(
    (select count(*)::integer from public.wonder_daily_grants where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
    1,
    'bootstrap grants the first daily Daisy'
);

update public.wonder_daily_grants
set local_date = local_date - 1
where user_id = '00000000-0000-0000-0000-000000000501'::uuid;

select is(
    (public.wonder_enter_hibernate(
        'America/Los_Angeles',
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000511'::uuid
    )->>'ok'),
    'true',
    'Hibernate entry succeeds'
);

select is(
    (public.wonder_enter_hibernate(
        'America/Los_Angeles',
        1,
        '00000000-0000-0000-0000-000000000511'::uuid
    )->>'replayed'),
    'true',
    'lost Hibernate entry response replays without a second interval'
);

select is(
    (select count(*)::integer from public.wonder_hibernate_intervals where user_id = '00000000-0000-0000-0000-000000000501'::uuid and end_utc is null),
    1,
    'Hibernate replay leaves exactly one open interval'
);

select is(
    (public.wonder_refresh_state()->>'ok'),
    'true',
    'refresh remains available during Hibernate'
);

select is(
    (
        select count(*)::integer
        from public.wonder_daily_grants
        where user_id = '00000000-0000-0000-0000-000000000501'::uuid
          and local_date = (clock_timestamp() at time zone 'America/Los_Angeles')::date
    ),
    0,
    'refresh does not grant a Daisy during Hibernate'
);

select is(
    (public.wonder_exit_hibernate(
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000512'::uuid
    )->>'ok'),
    'true',
    'Hibernate exit succeeds'
);

select is(
    (public.wonder_exit_hibernate(
        2,
        '00000000-0000-0000-0000-000000000512'::uuid
    )->>'replayed'),
    'true',
    'lost Hibernate exit response replays without extending twice'
);

select is(
    (
        select count(*)::integer
        from public.wonder_daily_grants
        where user_id = '00000000-0000-0000-0000-000000000501'::uuid
          and local_date = (clock_timestamp() at time zone 'America/Los_Angeles')::date
    ),
    1,
    'Hibernate exit grants only the current-day Daisy'
);

select is(
    (select count(*)::integer from public.wonder_hibernate_intervals where user_id = '00000000-0000-0000-0000-000000000501'::uuid and end_utc is not null),
    1,
    'Hibernate interval is closed exactly once'
);

update public.wonder_flower_instances
set deadline_utc = timezone('utc', clock_timestamp()) - interval '1 second'
where flower_id = (
    select flower_id
    from public.wonder_daily_grants
    where user_id = '00000000-0000-0000-0000-000000000501'::uuid
    order by local_date
    limit 1
);

select is(
    (public.wonder_refresh_state()->>'ok'),
    'true',
    'refresh processes an expired living flower'
);

select is(
    (
        select state
        from public.wonder_flower_instances
        where flower_id = (
            select flower_id
            from public.wonder_daily_grants
            where user_id = '00000000-0000-0000-0000-000000000501'::uuid
            order by local_date
            limit 1
        )
    ),
    'pressed',
    'natural expiry moves the flower into Pressbook state'
);

select is(
    (
        select pressed_count
        from public.wonder_discoveries d
        join public.wonder_species s on s.species_id = d.species_id
        where d.user_id = '00000000-0000-0000-0000-000000000501'::uuid
          and s.slug = 'daisy'
    ),
    1,
    'natural expiry increments the species pressed count'
);

select is(
    (public.wonder_start_manual_wander(
        'manual',
        '00000000-0000-0000-0000-000000000520'::uuid,
        'America/Los_Angeles',
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000521'::uuid,
        false
    )->>'ok'),
    'true',
    'online Wander starts for lifecycle regression'
);

update public.wonder_wander_sessions
set start_utc = fixture.start_utc,
    auto_close_utc = fixture.start_utc + interval '1 hour'
from (
    select clock_timestamp() - interval '61 minutes' as start_utc
) fixture
where session_id = '00000000-0000-0000-0000-000000000520'::uuid;

select is(
    (public.wonder_refresh_state()->>'ok'),
    'true',
    'refresh reconciles a session beyond sixty minutes'
);

select is(
    (select state from public.wonder_wander_sessions where session_id = '00000000-0000-0000-0000-000000000520'::uuid),
    'closed',
    'sixty-minute Wander is closed'
);

select is(
    (select count(*)::integer from public.wonder_wander_rewards where session_id = '00000000-0000-0000-0000-000000000520'::uuid and status = 'pending_resolution'),
    3,
    'sixty-minute close preserves all reached tiers as pending'
);

select is(
    (select count(*)::integer from public.wonder_wander_rewards where session_id = '00000000-0000-0000-0000-000000000520'::uuid and status = 'released'),
    0,
    'sixty-minute close releases no reached tier'
);

select is(
    (public.wonder_choose_wander_reward(
        '00000000-0000-0000-0000-000000000520'::uuid,
        10,
        (select species_slug from public.wonder_wander_offers where session_id = '00000000-0000-0000-0000-000000000520'::uuid and position = 1),
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000522'::uuid
    )->>'ok'),
    'true',
    'closed session resolves its ten-minute choice'
);

select is(
    (public.wonder_choose_wander_reward(
        '00000000-0000-0000-0000-000000000520'::uuid,
        20,
        (select species_slug from public.wonder_wander_offers where session_id = '00000000-0000-0000-0000-000000000520'::uuid and position = 2),
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000523'::uuid
    )->>'ok'),
    'true',
    'closed session resolves its twenty-minute choice'
);

select is(
    (public.wonder_reconcile_wander(
        '00000000-0000-0000-0000-000000000520'::uuid,
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000524'::uuid
    )->>'ok'),
    'true',
    'reconcile awards the final remaining offer after ordered choices'
);

select is(
    (select count(*)::integer from public.wonder_wander_rewards where session_id = '00000000-0000-0000-0000-000000000520'::uuid and status = 'awarded'),
    3,
    'ten, twenty, and automatic thirty tiers award exactly once'
);

select is(
    (public.wonder_sell_flower(
        (select flower_id from public.wonder_daily_grants where user_id = '00000000-0000-0000-0000-000000000501'::uuid order by local_date desc limit 1),
        999,
        (select f.version from public.wonder_flower_instances f join public.wonder_daily_grants g on g.flower_id = f.flower_id where g.user_id = '00000000-0000-0000-0000-000000000501'::uuid order by g.local_date desc limit 1),
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000530'::uuid
    )->'error'->>'code'),
    'WW_SALE_VALUE_CHANGED',
    'stale sale preview requires explicit reconfirmation'
);

select is(
    (public.wonder_sell_flower(
        (select flower_id from public.wonder_daily_grants where user_id = '00000000-0000-0000-0000-000000000501'::uuid order by local_date desc limit 1),
        (
            select wonder_private.wonder_calculate_sale_value(f.deadline_utc, timezone('utc', clock_timestamp()))
            from public.wonder_flower_instances f
            join public.wonder_daily_grants g on g.flower_id = f.flower_id
            where g.user_id = '00000000-0000-0000-0000-000000000501'::uuid
            order by g.local_date desc
            limit 1
        ),
        (select f.version from public.wonder_flower_instances f join public.wonder_daily_grants g on g.flower_id = f.flower_id where g.user_id = '00000000-0000-0000-0000-000000000501'::uuid order by g.local_date desc limit 1),
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000531'::uuid
    )->>'ok'),
    'true',
    'reconfirmed current sale preview succeeds'
);

select is(
    (select count(*)::integer from public.wonder_glow_ledger where user_id = '00000000-0000-0000-0000-000000000501'::uuid and reason = 'sale'),
    1,
    'sale reconfirmation creates one ledger credit'
);

select is(
    (public.wonder_apply_sunshine(
        (select flower_id from public.wonder_flower_instances where user_id = '00000000-0000-0000-0000-000000000501'::uuid and source = 'wander' and state = 'living' order by acquired_at limit 1),
        0,
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000532'::uuid
    )->'error'->>'code'),
    'WW_NOT_DISPLAYED',
    'Sunshine rejects a living flower that is not displayed'
);

select is(
    (public.wonder_assign_flower_to_vase(
        (select flower_id from public.wonder_flower_instances where user_id = '00000000-0000-0000-0000-000000000501'::uuid and source = 'wander' and state = 'living' order by acquired_at limit 1),
        1, 1, 0,
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000533'::uuid
    )->>'ok'),
    'true',
    'living Wander flower can be displayed for Sunshine checks'
);

select is(
    (public.wonder_apply_sunshine(
        (select flower_id from public.wonder_vase_assignments where user_id = '00000000-0000-0000-0000-000000000501'::uuid and slot = 1 and position = 1),
        1,
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000534'::uuid
    )->'error'->>'code'),
    'WW_INSUFFICIENT_GLOW',
    'Sunshine returns a typed insufficient-Glow error'
);

select is(
    (public.wonder_sync_steps(
        (timezone('utc', clock_timestamp()))::date,
        'UTC', 99, 0, 'health',
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000540'::uuid
    )->'delta'->>'credited_delta'),
    '0',
    'ninety-nine steps credit zero Glow'
);

select is(
    (public.wonder_sync_steps(
        (timezone('utc', clock_timestamp()))::date,
        'UTC', 100, 0, 'health',
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000541'::uuid
    )->'delta'->>'credited_delta'),
    '1',
    'one hundred steps credit one Glow'
);

select is(
    (public.wonder_sync_steps(
        (timezone('utc', clock_timestamp()))::date,
        'UTC', 199, 0, 'health',
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000542'::uuid
    )->'delta'->>'credited_delta'),
    '0',
    'one hundred ninety-nine steps do not duplicate the first Glow'
);

select is(
    (public.wonder_sync_steps(
        (timezone('utc', clock_timestamp()))::date,
        'UTC', 200, 0, 'health',
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000543'::uuid
    )->'delta'->>'credited_delta'),
    '1',
    'two hundred steps credit only the second Glow'
);

select is(
    (public.wonder_sync_steps(
        (timezone('utc', clock_timestamp()))::date,
        'UTC', 2000, 0, 'health',
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000544'::uuid
    )->'delta'->>'credited_delta'),
    '18',
    'later high-water credits only the positive step difference'
);

select is(
    (public.wonder_apply_sunshine(
        (select flower_id from public.wonder_vase_assignments where user_id = '00000000-0000-0000-0000-000000000501'::uuid and slot = 1 and position = 1),
        1,
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000545'::uuid
    )->>'ok'),
    'true',
    'displayed living flower can consume Sunshine when Glow is sufficient'
);

select is(
    (select extension_seconds from public.wonder_flower_instances where flower_id = (select flower_id from public.wonder_vase_assignments where user_id = '00000000-0000-0000-0000-000000000501'::uuid and slot = 1 and position = 1)),
    86400,
    'Sunshine extends the flower by exactly one day'
);

select is(
    (public.wonder_remove_flower_from_vase(
        (select flower_id from public.wonder_vase_assignments where user_id = '00000000-0000-0000-0000-000000000501'::uuid and slot = 1 and position = 1),
        (select f.version from public.wonder_flower_instances f join public.wonder_vase_assignments a on a.flower_id = f.flower_id and a.user_id = f.user_id where a.user_id = '00000000-0000-0000-0000-000000000501'::uuid and a.slot = 1 and a.position = 1),
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000546'::uuid
    )->>'ok'),
    'true',
    'displayed living flower can be removed reversibly'
);

select is(
    (select count(*)::integer from public.wonder_vase_assignments where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
    0,
    'remove clears the vase assignment'
);

select is(
    (public.wonder_press_flower(
        (select flower_id from public.wonder_flower_instances where user_id = '00000000-0000-0000-0000-000000000501'::uuid and source = 'wander' and state = 'living' order by acquired_at desc limit 1),
        (select version from public.wonder_flower_instances where user_id = '00000000-0000-0000-0000-000000000501'::uuid and source = 'wander' and state = 'living' order by acquired_at desc limit 1),
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000547'::uuid
    )->>'ok'),
    'true',
    'living flower can be pressed early'
);

select is(
    (select count(*)::integer from public.wonder_flower_events where user_id = '00000000-0000-0000-0000-000000000501'::uuid and idempotency_key = '00000000-0000-0000-0000-000000000547'::uuid and event_type = 'pressed_early'),
    1,
    'early press records one immutable event'
);

insert into public.wonder_product_events (
    user_id, event_name, occurred_at_utc, local_date, time_zone
)
select
    '00000000-0000-0000-0000-000000000501'::uuid,
    'wander_started',
    timezone('utc', clock_timestamp()),
    (timezone('utc', clock_timestamp()))::date,
    'UTC'
from generate_series(1, 199);

select is(
    (public.wonder_record_ui_event('wander_started')->>'accepted'),
    'true',
    'telemetry accepts the two-hundredth UTC-day event'
);

select is(
    (public.wonder_record_ui_event('wander_started')->>'accepted'),
    'false',
    'telemetry rejects the two-hundred-first UTC-day event'
);

select is(
    (public.wonder_sync_offline_wander(
        '00000000-0000-0000-0000-000000000550'::uuid,
        timezone('utc', clock_timestamp()) - interval '5 minutes',
        (timezone('utc', clock_timestamp()))::date - 1,
        'UTC', 1, 'fixture',
        array['aster', 'goldenrod', 'salvia'],
        '[]'::jsonb,
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000551'::uuid
    )->'error'->>'code'),
    'WW_INVALID_OFFLINE_PROOF',
    'offline sync rejects a local date that does not match start time'
);

select is(
    (public.wonder_sync_offline_wander(
        '00000000-0000-0000-0000-000000000552'::uuid,
        timezone('utc', clock_timestamp()),
        (timezone('utc', clock_timestamp()))::date,
        'UTC', 1, 'fixture',
        array['aster', 'goldenrod', 'salvia'],
        '[{"tier":10,"species_slug":"aster","elapsed_seconds":600}]'::jsonb,
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000553'::uuid
    )->'error'->>'code'),
    'WW_INVALID_OFFLINE_PROOF',
    'offline sync rejects threshold evidence that has not elapsed'
);

select is(
    (public.wonder_sync_offline_wander(
        '00000000-0000-0000-0000-000000000554'::uuid,
        timezone('utc', clock_timestamp()) - interval '20 minutes',
        (timezone('utc', clock_timestamp()))::date,
        'UTC', 1, 'fixture',
        array['aster', 'goldenrod', 'salvia'],
        '[{"tier":10,"species_slug":"aster","elapsed_seconds":600},{"tier":20,"species_slug":"aster","elapsed_seconds":1200}]'::jsonb,
        (select state_revision from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
        '00000000-0000-0000-0000-000000000555'::uuid
    )->'error'->>'code'),
    'WW_CATALOG_MISMATCH',
    'offline sync rejects duplicate offer choices across tiers'
);

select lives_ok(
$$
    delete from auth.users
    where id = '00000000-0000-0000-0000-000000000501'::uuid;
$$,
'account deletion cascades through populated immutable game history'
);

select is(
    (select count(*)::integer from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000501'::uuid),
    0,
    'populated deleted account leaves no game profile'
);

select * from finish();
rollback;
