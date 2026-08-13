begin;

create extension if not exists pgcrypto;

create schema if not exists wonder_private;
revoke all on schema wonder_private from public, anon, authenticated;

create or replace function wonder_private.wonder_reject_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if tg_op in ('UPDATE', 'DELETE') then
        raise exception 'immutable Wander Wonders row' using errcode = '42501';
    end if;
    return new;
end;
$$;

revoke all on function wonder_private.wonder_reject_immutable() from public, anon, authenticated;

create table public.wonder_profiles (
    user_id uuid primary key references auth.users (id) on delete cascade,
    glow_balance integer not null default 0 check (glow_balance >= 0),
    state_revision bigint not null default 0 check (state_revision >= 0),
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create table public.wonder_account_identities (
    identity_id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    provider text not null check (provider in ('apple', 'google')),
    provider_identity_id text not null check (length(btrim(provider_identity_id)) > 0),
    approval text not null check (approval in ('initial', 'explicit_link')),
    created_at timestamptz not null default timezone('utc', now()),
    unique (provider, provider_identity_id),
    unique (user_id, provider)
);

create table public.wonder_player_settings (
    user_id uuid primary key references public.wonder_profiles (user_id) on delete cascade,
    time_zone text not null default 'UTC' check (length(btrim(time_zone)) > 0),
    onboarding_completed boolean not null default false,
    step_mode text not null default 'health' check (step_mode in ('health', 'motion', 'time_only')),
    hibernate_enabled boolean not null default true,
    notifications_enabled boolean not null default true,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create table public.wonder_app_config (
    config_key text primary key check (length(btrim(config_key)) > 0),
    config_value jsonb not null,
    version integer not null check (version > 0),
    updated_at timestamptz not null default timezone('utc', now())
);

create table public.wonder_species (
    species_id uuid primary key default gen_random_uuid(),
    slug text not null unique check (slug = lower(slug) and length(btrim(slug)) > 0),
    common_name text not null check (length(btrim(common_name)) > 0),
    source text not null check (source in ('daily', 'wander')),
    season text not null check (season in ('all', 'autumn')),
    bloom_duration_seconds integer not null check (bloom_duration_seconds > 0),
    offer_weight integer,
    living_asset_key text not null check (length(btrim(living_asset_key)) > 0),
    fading_asset_key text not null check (length(btrim(fading_asset_key)) > 0),
    pressed_asset_key text not null check (length(btrim(pressed_asset_key)) > 0),
    introduced_catalog_version integer not null check (introduced_catalog_version > 0),
    retired_catalog_version integer,
    active boolean not null default true,
    check (
        (source = 'daily' and season = 'all' and offer_weight is null)
        or (source = 'wander' and season = 'autumn' and offer_weight is not null and offer_weight > 0)
    ),
    check (retired_catalog_version is null or retired_catalog_version >= introduced_catalog_version)
);

create table public.wonder_discoveries (
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    species_id uuid not null references public.wonder_species (species_id) on delete restrict,
    first_discovered_at timestamptz not null,
    first_local_date date not null,
    time_zone text not null check (length(btrim(time_zone)) > 0),
    pressed_count integer not null default 0 check (pressed_count >= 0),
    primary key (user_id, species_id)
);

create table public.wonder_wander_sessions (
    session_id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    start_utc timestamptz not null,
    end_utc timestamptz,
    auto_close_utc timestamptz not null,
    local_date date not null,
    time_zone text not null check (length(btrim(time_zone)) > 0),
    mode text not null check (mode in ('verified', 'manual', 'fallback_step', 'time_only', 'offline')),
    state text not null default 'active' check (state in ('active', 'closed')),
    offline boolean not null default false,
    catalog_version integer not null check (catalog_version > 0),
    catalog_checksum text not null check (length(btrim(catalog_checksum)) > 0),
    offer_season text not null check (offer_season = 'autumn'),
    reserved_count integer not null default 0 check (reserved_count between 0 and 3),
    earned_count integer not null default 0 check (earned_count between 0 and 3),
    elapsed_high_water_seconds integer not null default 0 check (elapsed_high_water_seconds between 0 and 3600),
    created_at timestamptz not null default timezone('utc', now()),
    check (auto_close_utc = start_utc + interval '1 hour'),
    check (end_utc is null or end_utc >= start_utc),
    check (offline = (mode = 'offline')),
    unique (user_id, session_id)
);

create unique index wonder_wander_sessions_one_active_idx
    on public.wonder_wander_sessions (user_id)
    where state = 'active';

create table public.wonder_flower_instances (
    flower_id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    species_id uuid not null references public.wonder_species (species_id) on delete restrict,
    source text not null check (source in ('daily', 'wander')),
    session_id uuid,
    tier integer check (tier in (10, 20, 30)),
    acquired_at timestamptz not null,
    duration_seconds integer not null check (duration_seconds > 0),
    deadline_utc timestamptz not null,
    extension_seconds integer not null default 0 check (extension_seconds >= 0),
    state text not null default 'living' check (state in ('living', 'pressed', 'sold')),
    version bigint not null default 0 check (version >= 0),
    created_at timestamptz not null default timezone('utc', now()),
    check (
        (source = 'daily' and session_id is null and tier is null)
        or (source = 'wander' and session_id is not null and tier is not null)
    ),
    unique (user_id, flower_id),
    foreign key (user_id, session_id)
        references public.wonder_wander_sessions (user_id, session_id)
        on delete restrict
);

create unique index wonder_flower_instances_session_tier_idx
    on public.wonder_flower_instances (session_id, tier)
    where session_id is not null;

create table public.wonder_flower_events (
    event_id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    flower_id uuid not null,
    session_id uuid,
    event_type text not null check (event_type in ('acquired', 'natural_fade', 'pressed_early', 'sold', 'sunshine', 'vase_assigned', 'vase_removed')),
    occurred_at timestamptz not null default timezone('utc', now()),
    idempotency_key uuid,
    vase_slot integer check (vase_slot between 1 and 3),
    vase_position integer check (vase_position between 1 and 3),
    sale_glow integer check (sale_glow is null or sale_glow >= 0),
    glow_amount integer,
    foreign key (user_id, flower_id)
        references public.wonder_flower_instances (user_id, flower_id)
        on delete cascade,
    foreign key (user_id, session_id)
        references public.wonder_wander_sessions (user_id, session_id)
        on delete set null,
    unique (user_id, idempotency_key)
);

create table public.wonder_daily_grants (
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    local_date date not null,
    grant_type text not null check (grant_type = 'daily_daisy'),
    time_zone text not null check (length(btrim(time_zone)) > 0),
    flower_id uuid not null,
    granted_at timestamptz not null default timezone('utc', now()),
    primary key (user_id, local_date, grant_type),
    foreign key (user_id, flower_id)
        references public.wonder_flower_instances (user_id, flower_id)
        on delete restrict,
    unique (flower_id)
);

create table public.wonder_wander_offers (
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    session_id uuid not null,
    position integer not null check (position between 1 and 3),
    species_id uuid not null references public.wonder_species (species_id) on delete restrict,
    species_slug text not null check (length(btrim(species_slug)) > 0),
    catalog_version integer not null check (catalog_version > 0),
    offer_checksum text not null check (length(btrim(offer_checksum)) > 0),
    primary key (session_id, position),
    unique (session_id, species_id),
    foreign key (user_id, session_id)
        references public.wonder_wander_sessions (user_id, session_id)
        on delete cascade
);

create table public.wonder_wander_rewards (
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    session_id uuid not null,
    tier integer not null check (tier in (10, 20, 30)),
    status text not null check (status in ('reserved', 'pending_resolution', 'awarded', 'rejected', 'released')),
    resolution_mode text not null check (resolution_mode in ('player_choice', 'automatic')),
    selected_species_id uuid references public.wonder_species (species_id) on delete restrict,
    flower_id uuid references public.wonder_flower_instances (flower_id) on delete restrict,
    rejection_code text,
    idempotency_key uuid,
    reached_at timestamptz,
    resolved_at timestamptz,
    primary key (session_id, tier),
    foreign key (user_id, session_id)
        references public.wonder_wander_sessions (user_id, session_id)
        on delete cascade,
    check ((tier = 30 and resolution_mode = 'automatic') or (tier in (10, 20) and resolution_mode = 'player_choice')),
    check ((status = 'rejected') = (rejection_code is not null)),
    check (status <> 'awarded' or flower_id is not null)
);

create table public.wonder_vase_slots (
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    slot integer not null check (slot between 1 and 3),
    capacity integer not null check (capacity between 1 and 3),
    unlocked boolean not null default false,
    pattern_key text not null default 'classic_cream' check (pattern_key in ('classic_cream', 'meadow_dots', 'blue_vine')),
    primary key (user_id, slot),
    check ((slot = 1 and capacity = 1) or (slot = 2 and capacity = 2) or (slot = 3 and capacity = 3)),
    check (slot <> 1 or unlocked)
);

create table public.wonder_vase_assignments (
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    slot integer not null check (slot between 1 and 3),
    position integer not null check (position between 1 and 3),
    flower_id uuid not null,
    assigned_at timestamptz not null default timezone('utc', now()),
    primary key (user_id, slot, position),
    unique (user_id, flower_id),
    foreign key (user_id, slot)
        references public.wonder_vase_slots (user_id, slot)
        on delete cascade,
    foreign key (user_id, flower_id)
        references public.wonder_flower_instances (user_id, flower_id)
        on delete cascade
);

create table public.wonder_shelf_assignments (
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    position integer not null check (position between 1 and 6),
    species_id uuid not null references public.wonder_species (species_id) on delete restrict,
    assigned_at timestamptz not null default timezone('utc', now()),
    primary key (user_id, position),
    unique (user_id, species_id)
);

create table public.wonder_shop_items (
    item_key text primary key check (length(btrim(item_key)) > 0),
    kind text not null check (kind in ('vase_slot_unlock', 'vase_pattern')),
    glow_cost integer not null check (glow_cost >= 0),
    slot_number integer check (slot_number between 2 and 3),
    pattern_key text check (pattern_key in ('classic_cream', 'meadow_dots', 'blue_vine')),
    asset_key text not null check (length(btrim(asset_key)) > 0),
    active boolean not null default true,
    config_version integer not null check (config_version > 0),
    check ((kind = 'vase_slot_unlock' and slot_number is not null and pattern_key is null)
        or (kind = 'vase_pattern' and slot_number is null and pattern_key is not null))
);

create table public.wonder_player_entitlements (
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    item_key text not null references public.wonder_shop_items (item_key) on delete restrict,
    purchased_at timestamptz not null default timezone('utc', now()),
    paid_ledger_id uuid,
    primary key (user_id, item_key),
    unique (paid_ledger_id)
);

create table public.wonder_glow_ledger (
    entry_id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    amount integer not null check (amount <> 0),
    balance_after integer not null check (balance_after >= 0),
    reason text not null check (reason in ('step_credit', 'sale', 'shop_purchase', 'sunshine', 'compensation')),
    idempotency_key uuid,
    domain_id uuid,
    occurred_at timestamptz not null default timezone('utc', now()),
    unique (user_id, entry_id),
    unique (user_id, idempotency_key)
);

alter table public.wonder_player_entitlements
    add foreign key (user_id, paid_ledger_id)
    references public.wonder_glow_ledger (user_id, entry_id)
    on delete restrict;

create table public.wonder_daily_step_credits (
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    local_date date not null,
    time_zone text not null check (length(btrim(time_zone)) > 0),
    health_high_water bigint not null default 0 check (health_high_water >= 0),
    fallback_high_water bigint not null default 0 check (fallback_high_water >= 0),
    credited_glow integer not null default 0 check (credited_glow >= 0),
    credit_mode text not null default 'time_only' check (credit_mode in ('health', 'fallback', 'mixed', 'time_only')),
    synced_at timestamptz not null default timezone('utc', now()),
    primary key (user_id, local_date)
);

create table public.wonder_hibernate_intervals (
    interval_id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    start_utc timestamptz not null,
    end_utc timestamptz,
    start_local_date date not null,
    end_local_date date,
    start_time_zone text not null check (length(btrim(start_time_zone)) > 0),
    end_time_zone text,
    created_at timestamptz not null default timezone('utc', now()),
    check (end_utc is null or end_utc > start_utc),
    check (end_utc is null or end_local_date is not null),
    check (end_utc is null or end_time_zone is not null)
);

create unique index wonder_hibernate_intervals_one_open_idx
    on public.wonder_hibernate_intervals (user_id)
    where end_utc is null;

create table public.wonder_idempotency_keys (
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    request_id uuid not null,
    operation text not null check (operation like 'wonder_%'),
    canonical_request jsonb not null,
    response_json jsonb,
    created_at timestamptz not null default timezone('utc', now()),
    completed_at timestamptz,
    primary key (user_id, request_id)
);

create table public.wonder_product_events (
    event_id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.wonder_profiles (user_id) on delete cascade,
    event_name text not null check (event_name in (
        'onboarding_completed',
        'daily_daisy_granted',
        'wander_started',
        'wander_tier_resolved',
        'wander_tier_cap_rejected',
        'flower_action_completed',
        'shop_purchase_completed',
        'hibernate_changed',
        'refresh_after_revision_mismatch'
    )),
    occurred_at_utc timestamptz not null default timezone('utc', now()),
    local_date date not null,
    time_zone text not null check (length(btrim(time_zone)) > 0),
    domain_id uuid,
    numeric_value integer,
    boolean_value boolean
);

create index wonder_account_identities_user_idx on public.wonder_account_identities (user_id);
create index wonder_discoveries_species_idx on public.wonder_discoveries (species_id);
create index wonder_wander_sessions_user_start_idx on public.wonder_wander_sessions (user_id, start_utc);
create index wonder_flower_instances_user_idx on public.wonder_flower_instances (user_id, state);
create index wonder_flower_instances_species_idx on public.wonder_flower_instances (species_id);
create index wonder_flower_instances_session_idx on public.wonder_flower_instances (user_id, session_id);
create index wonder_flower_events_flower_idx on public.wonder_flower_events (user_id, flower_id, occurred_at);
create index wonder_flower_events_session_idx on public.wonder_flower_events (user_id, session_id, occurred_at);
create index wonder_daily_grants_flower_idx on public.wonder_daily_grants (user_id, flower_id);
create index wonder_wander_offers_user_session_idx on public.wonder_wander_offers (user_id, session_id);
create index wonder_wander_offers_species_idx on public.wonder_wander_offers (species_id);
create index wonder_wander_rewards_user_session_idx on public.wonder_wander_rewards (user_id, session_id);
create index wonder_wander_rewards_species_idx on public.wonder_wander_rewards (selected_species_id);
create index wonder_wander_rewards_flower_idx on public.wonder_wander_rewards (flower_id);
create index wonder_vase_assignments_flower_idx on public.wonder_vase_assignments (user_id, flower_id);
create index wonder_shelf_assignments_species_idx on public.wonder_shelf_assignments (species_id);
create index wonder_player_entitlements_item_idx on public.wonder_player_entitlements (item_key);
create index wonder_player_entitlements_ledger_idx on public.wonder_player_entitlements (user_id, paid_ledger_id);
create index wonder_glow_ledger_user_time_idx on public.wonder_glow_ledger (user_id, occurred_at);
create index wonder_daily_step_credits_user_date_idx on public.wonder_daily_step_credits (user_id, local_date);
create index wonder_hibernate_intervals_user_time_idx on public.wonder_hibernate_intervals (user_id, start_utc, end_utc);
create index wonder_idempotency_keys_user_created_idx on public.wonder_idempotency_keys (user_id, created_at);
create index wonder_product_events_owner_time_idx on public.wonder_product_events (user_id, occurred_at_utc);

create trigger wonder_flower_events_immutable
before update or delete on public.wonder_flower_events
for each row execute function wonder_private.wonder_reject_immutable();

create trigger wonder_wander_offers_immutable
before update or delete on public.wonder_wander_offers
for each row execute function wonder_private.wonder_reject_immutable();

create trigger wonder_glow_ledger_immutable
before update or delete on public.wonder_glow_ledger
for each row execute function wonder_private.wonder_reject_immutable();

create trigger wonder_product_events_immutable
before update or delete on public.wonder_product_events
for each row execute function wonder_private.wonder_reject_immutable();

do $$
declare
    table_name text;
begin
    foreach table_name in array array[
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
    ] loop
        execute format('alter table public.%I enable row level security', table_name);
        execute format('alter table public.%I force row level security', table_name);
        execute format('revoke all on table public.%I from public, anon, authenticated', table_name);
    end loop;
end;
$$;

commit;
