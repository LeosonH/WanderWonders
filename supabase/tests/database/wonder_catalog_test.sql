begin;

select plan(26);

select is(
    (select count(*)::integer from public.wonder_species where active),
    13,
    'seed contains exactly thirteen active species'
);

select is(
    (select count(*)::integer from public.wonder_species where active and source = 'wander' and season = 'autumn'),
    12,
    'seed contains exactly twelve active Autumn Wander species'
);

select is(
    (select count(*)::integer from public.wonder_species where active and source = 'wander' and (offer_weight is distinct from 100)),
    0,
    'all V1 Wander offer weights remain 100'
);

select is(
    (select count(*)::integer from public.wonder_species where (slug = 'daisy' and bloom_duration_seconds <> 86400) or (source = 'wander' and bloom_duration_seconds <> 259200)),
    0,
    'Daisy and Wander durations match the copied-deadline contract'
);

select is(
    (select count(*)::integer from (select living_asset_key from public.wonder_species union all select fading_asset_key from public.wonder_species union all select pressed_asset_key from public.wonder_species) keys),
    39,
    'seed contains thirty-nine flower asset keys'
);

select is(
    (select count(*)::integer from public.wonder_species where (source = 'daily' and season <> 'all') or (source = 'wander' and season <> 'autumn')),
    0,
    'source and season values are coherent'
);

select is(
    ((select config_value from public.wonder_app_config where config_key = 'catalog_version')->>'season'),
    'autumn',
    'catalog config fixes the release season to Autumn'
);

select is(
    ((select config_value from public.wonder_app_config where config_key = 'catalog_version')->'supported_seasons'->>0),
    'autumn',
    'only Autumn is supported in V1'
);

select is((select config_value::text from public.wonder_app_config where config_key = 'pocket_soft_capacity'), '12', 'Pocket soft capacity is 12');
select is((select config_value::text from public.wonder_app_config where config_key = 'daily_wander_cap'), '6', 'daily Wander cap is 6');
select is((select config_value::text from public.wonder_app_config where config_key = 'shelf_capacity'), '6', 'Pressbook shelf capacity is 6');
select is((select config_value::text from public.wonder_app_config where config_key = 'park_radius_meters'), '805', 'park radius is 805 meters');
select is((select config_value::text from public.wonder_app_config where config_key = 'accepted_park_types'), '["park", "city_park", "state_park", "national_park", "hiking_area", "botanical_garden"]', 'accepted park types match the contract');
select is((select config_value::text from public.wonder_app_config where config_key = 'sunshine_cost_glow'), '20', 'Sunshine costs 20 Glow');
select is((select config_value::text from public.wonder_app_config where config_key = 'steps_per_glow'), '100', 'step conversion is 100 steps per Glow');

select is((select count(*)::integer from public.wonder_shop_items where active), 5, 'seed contains five active shop items');
select is((select glow_cost from public.wonder_shop_items where item_key = 'slot_2'), 600, 'slot_2 costs 600 Glow');
select is((select glow_cost from public.wonder_shop_items where item_key = 'slot_3'), 1800, 'slot_3 costs 1800 Glow');
select is((select glow_cost from public.wonder_shop_items where item_key = 'classic_cream'), 0, 'classic_cream costs 0 Glow');
select is((select glow_cost from public.wonder_shop_items where item_key = 'meadow_dots'), 150, 'meadow_dots costs 150 Glow');
select is((select glow_cost from public.wonder_shop_items where item_key = 'blue_vine'), 200, 'blue_vine costs 200 Glow');

select ok(
    length(wonder_private.wonder_catalog_checksum(1)) = 64,
    'catalog checksum is a SHA-256 hex value'
);

select is(
    (
        with eligible as (
            select s.slug,
                   extensions.digest(
                       extensions.digest(convert_to('00000000-0000-0000-0000-000000000501:1:autumn', 'UTF8'), 'sha256')
                       || convert_to(':' || s.slug, 'UTF8'), 'sha256'
                   ) as sort_key
            from public.wonder_species s
            where s.active and s.source = 'wander' and s.season = 'autumn'
        )
        select array_agg(slug order by sort_key, slug)
        from (select slug, sort_key from eligible order by sort_key, slug limit 3) offers
    ),
    array['sedum', 'chrysanthemum', 'aster']::text[],
    'server offline validator matches the generated canonical offer order'
);

select is(
    (
        with eligible as (
            select s.slug,
                   extensions.digest(
                       extensions.digest(convert_to('00000000-0000-0000-0000-000000000501:1:autumn', 'UTF8'), 'sha256')
                       || convert_to(':' || s.slug, 'UTF8'), 'sha256'
                   ) as sort_key
            from public.wonder_species s
            where s.active and s.source = 'wander' and s.season = 'autumn'
        )
        select array_agg(encode(sort_key, 'hex') order by sort_key, slug)
        from (select slug, sort_key from eligible order by sort_key, slug limit 3) offers
    ),
    array[
        '18e4aacd17f7ec9985a3f0a120f4db9ecd712367790145d21d8cb74fd05bbc3b',
        '5f16eae99d8e0d188cc7a1866fb40acf787f19750438a7df35624c4394e0edd6',
        '6f9f9ee0c45dc415279fc1da2a7d415dd9c3eef01f52ceaf126cc1eaef1b5814'
    ]::text[],
    'server and generated offline fixture hashes match byte-for-byte'
);

update public.wonder_species
set active = false
where source = 'wander'
  and season = 'autumn'
  and slug not in ('sedum', 'chrysanthemum', 'aster');

select is(
    (select count(*)::integer from wonder_private.wonder_select_autumn_offers(1)),
    3,
    'runtime offer selection remains valid with exactly three eligible species'
);

select is(
    (select count(*)::integer from public.wonder_species where active and not ((source = 'daily' and season = 'all') or (source = 'wander' and season = 'autumn'))),
    0,
    'no non-Autumn runtime content is active'
);

select * from finish();
rollback;
