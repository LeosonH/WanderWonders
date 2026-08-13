begin;

select plan(22);

select is(
    (
        select count(*)::integer
        from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public'
          and c.relkind = 'r'
          and left(c.relname, 7) = 'wonder_'
    ),
    22,
    'exactly 22 public wonder tables exist'
);

select is(
    (
        select count(*)::integer
        from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public'
          and c.relkind = 'r'
          and left(c.relname, 7) = 'wonder_'
          and c.relrowsecurity
          and c.relforcerowsecurity
    ),
    22,
    'all wonder tables enable and force RLS'
);

select is(
    (
        select count(*)::integer
        from unnest(array[
            'wonder_profiles',
            'wonder_account_identities',
            'wonder_player_settings',
            'wonder_app_config',
            'wonder_species',
            'wonder_discoveries',
            'wonder_wander_sessions',
            'wonder_flower_instances',
            'wonder_flower_events',
            'wonder_daily_grants',
            'wonder_wander_offers',
            'wonder_wander_rewards',
            'wonder_vase_slots',
            'wonder_vase_assignments',
            'wonder_shelf_assignments',
            'wonder_shop_items',
            'wonder_player_entitlements',
            'wonder_glow_ledger',
            'wonder_daily_step_credits',
            'wonder_hibernate_intervals',
            'wonder_idempotency_keys',
            'wonder_product_events'
        ]) as expected(table_name)
        where has_table_privilege('anon', format('public.%I', expected.table_name), 'select')
           or has_table_privilege('authenticated', format('public.%I', expected.table_name), 'select')
           or has_table_privilege('anon', format('public.%I', expected.table_name), 'insert')
           or has_table_privilege('authenticated', format('public.%I', expected.table_name), 'insert')
    ),
    0,
    'anon and authenticated have no direct table privileges'
);

select is(
    (
        with wonder_foreign_keys as (
            select c.conrelid, n.nspname, r.relname, c.conname, c.conkey
            from pg_catalog.pg_constraint c
            join pg_catalog.pg_class r on r.oid = c.conrelid
            join pg_catalog.pg_namespace n on n.oid = r.relnamespace
            where c.contype = 'f'
              and n.nspname = 'public'
              and left(r.relname, 7) = 'wonder_'
        )
        select count(*)::integer
        from wonder_foreign_keys fk
        where not exists (
            select 1
            from pg_catalog.pg_index i
            where i.indrelid = fk.conrelid
              and i.indisvalid
              and i.indisready
              and i.indpred is null
              and i.indnkeyatts >= cardinality(fk.conkey)
              and (
                  select array_agg(i.indkey[pos] order by pos)
                  from generate_series(0, cardinality(fk.conkey) - 1) as pos
              ) = fk.conkey
        )
    ),
    0,
    'every public wonder foreign key has a namespace-safe leading index'
);

select is(
    (
        select count(*)::integer
        from pg_catalog.pg_trigger t
        join pg_catalog.pg_class c on c.oid = t.tgrelid
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where not t.tgisinternal
          and n.nspname = 'public'
          and t.tgname in (
              'wonder_flower_events_immutable',
              'wonder_wander_offers_immutable',
              'wonder_glow_ledger_immutable',
              'wonder_product_events_immutable'
          )
    ),
    4,
    'immutable event, offer, ledger, and telemetry triggers exist'
);

select is(
    (
        select count(*)::integer
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'wonder_private'
          and p.proname like 'wonder_%'
          and not exists (
              select 1
              from unnest(coalesce(p.proconfig, array[]::text[])) as config_value
              where config_value in ('search_path=', 'search_path=""')
          )
    ),
    0,
    'private helper has an empty search path'
);

select has_table('public', 'wonder_profiles', 'profiles table exists');
select has_table('public', 'wonder_wander_sessions', 'wander sessions table exists');
select has_table('public', 'wonder_wander_rewards', 'wander rewards table exists');
select has_table('public', 'wonder_glow_ledger', 'Glow ledger table exists');
select has_table('public', 'wonder_product_events', 'product events table exists');
select has_schema('wonder_private', 'private helper schema exists');

select lives_ok(
$$
    insert into auth.users (id)
    values
        ('00000000-0000-0000-0000-000000000001'::uuid),
        ('00000000-0000-0000-0000-000000000002'::uuid);

    insert into public.wonder_profiles (user_id)
    values
        ('00000000-0000-0000-0000-000000000001'::uuid),
        ('00000000-0000-0000-0000-000000000002'::uuid);

    insert into public.wonder_species (
        species_id, slug, common_name, source, season, bloom_duration_seconds,
        living_asset_key, fading_asset_key, pressed_asset_key, introduced_catalog_version
    ) values (
        '00000000-0000-0000-0000-000000000010'::uuid,
        'fixture_daisy', 'Fixture Daisy', 'daily', 'all', 86400,
        'fixture_daisy_living', 'fixture_daisy_fading', 'fixture_daisy_pressed', 1
    );

    insert into public.wonder_wander_sessions (
        session_id, user_id, start_utc, auto_close_utc, local_date, time_zone,
        mode, offline, catalog_version, catalog_checksum, offer_season
    ) values (
        '00000000-0000-0000-0000-000000000020'::uuid,
        '00000000-0000-0000-0000-000000000001'::uuid,
        '2026-01-01 00:00:00+00', '2026-01-01 01:00:00+00', '2026-01-01', 'UTC',
        'manual', false, 1, 'fixture', 'autumn'
    );

$$,
'valid owner rows and a Wander session can be inserted'
);

select throws_ok(
$$
    insert into public.wonder_wander_offers (
        user_id, session_id, position, species_id, species_slug, catalog_version, offer_checksum
    ) values (
        '00000000-0000-0000-0000-000000000002'::uuid,
        '00000000-0000-0000-0000-000000000020'::uuid,
        1, '00000000-0000-0000-0000-000000000010'::uuid, 'fixture_daisy', 1, 'fixture'
    );
$$,
'23503',
null,
'composite owner FK rejects a cross-owner offer'
);

select lives_ok(
$$
    insert into public.wonder_wander_offers (
        user_id, session_id, position, species_id, species_slug, catalog_version, offer_checksum
    ) values (
        '00000000-0000-0000-0000-000000000001'::uuid,
        '00000000-0000-0000-0000-000000000020'::uuid,
        2, '00000000-0000-0000-0000-000000000010'::uuid, 'fixture_daisy', 1, 'fixture'
    );
$$,
'valid owner offer can be inserted before cascade verification'
);

select throws_ok(
$$
    insert into public.wonder_vase_slots (user_id, slot, capacity, unlocked)
    values ('00000000-0000-0000-0000-000000000001'::uuid, 2, 1, false);
$$,
'23514',
null,
'vase slot capacity constraint rejects incoherent values'
);

select throws_ok(
$$
    delete from public.wonder_wander_offers
    where user_id = '00000000-0000-0000-0000-000000000001'::uuid;
$$,
'42501',
'immutable Wander Wonders row',
'immutable offer rejects direct deletion while its owner exists'
);

select lives_ok(
$$
    delete from auth.users
    where id = '00000000-0000-0000-0000-000000000001'::uuid;
$$,
'auth deletion cascades through the owner graph'
);

select is(
    (select count(*)::integer from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000001'::uuid),
    0,
    'deleted auth owner has no profile'
);

select is(
    (select count(*)::integer from public.wonder_wander_sessions where user_id = '00000000-0000-0000-0000-000000000001'::uuid),
    0,
    'deleted auth owner has no Wander session'
);

select is(
    (select count(*)::integer from public.wonder_wander_offers where user_id = '00000000-0000-0000-0000-000000000001'::uuid),
    0,
    'deleted auth owner has no immutable Wander offers'
);

select is(
    (select count(*)::integer from public.wonder_profiles where user_id = '00000000-0000-0000-0000-000000000002'::uuid),
    1,
    'cascade deletion does not remove another owner'
);

select * from finish();
rollback;
