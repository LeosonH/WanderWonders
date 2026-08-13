begin;

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
    if v_user_id is null then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to sell a flower.', p_idempotency_key, false, 0);
    end if;
    if p_expected_value is null or p_expected_version is null then
        return wonder_private.wonder_error('WW_INVALID_REQUEST', 'A current flower value and version are required.', p_idempotency_key, false, 0);
    end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before selling a flower.', p_idempotency_key, false, 0);
    end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(
        v_user_id, p_idempotency_key, 'wonder_sell_flower',
        pg_catalog.jsonb_build_object(
            'flower_id', p_flower_id,
            'expected_value', p_expected_value,
            'expected_version', p_expected_version,
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

    select * into v_flower
    from public.wonder_flower_instances
    where user_id = v_user_id and flower_id = p_flower_id
    for update;
    if not found then
        v_response := wonder_private.wonder_error('WW_FLOWER_NOT_FOUND', 'That flower is not in your garden.', p_idempotency_key, false, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;
    if v_flower.state <> 'living' or v_flower.deadline_utc <= v_now then
        v_response := wonder_private.wonder_error('WW_FLOWER_EXPIRED', 'That flower is no longer living.', p_idempotency_key, false, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;

    v_current_value := wonder_private.wonder_calculate_sale_value(v_flower.deadline_utc, v_now);
    if v_flower.version <> p_expected_version or v_current_value <> p_expected_value then
        v_response := wonder_private.wonder_error(
            'WW_SALE_VALUE_CHANGED',
            'The flower value changed. Confirm the new value.',
            p_idempotency_key,
            true,
            v_base,
            pg_catalog.jsonb_build_object(
                'current_sale_glow', v_current_value,
                'server_now', v_now,
                'flower_version', v_flower.version
            )
        );
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;

    perform wonder_private.wonder_process_expired_flowers(v_user_id, v_now);
    v_ledger := wonder_private.wonder_append_glow_entry(v_user_id, v_current_value, 'sale', p_idempotency_key, p_flower_id);
    update public.wonder_flower_instances
    set state = 'sold', version = version + 1
    where user_id = v_user_id and flower_id = p_flower_id;
    delete from public.wonder_vase_assignments
    where user_id = v_user_id and flower_id = p_flower_id;
    insert into public.wonder_flower_events (
        user_id, flower_id, event_type, occurred_at,
        idempotency_key, sale_glow, glow_amount
    ) values (
        v_user_id, p_flower_id, 'sold', v_now,
        p_idempotency_key, v_current_value, v_current_value
    );
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(
        p_idempotency_key, v_base, v_revision, false,
        pg_catalog.jsonb_build_object(
            'flower_id', p_flower_id,
            'state', 'sold',
            'sale_glow', v_current_value,
            'glow_balance', v_ledger.balance_after,
            'flower_version', p_expected_version + 1
        )
    );
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
    return v_response;
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
    if v_user_id is null then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to use Sunshine.', p_idempotency_key, false, 0);
    end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before using Sunshine.', p_idempotency_key, false, 0);
    end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(
        v_user_id, p_idempotency_key, 'wonder_apply_sunshine',
        pg_catalog.jsonb_build_object(
            'flower_id', p_flower_id,
            'expected_version', p_expected_version,
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
    if exists (
        select 1 from public.wonder_hibernate_intervals
        where user_id = v_user_id and end_utc is null
    ) then
        v_response := wonder_private.wonder_error('WW_HIBERNATING', 'Sunshine is unavailable during Hibernate.', p_idempotency_key, false, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;

    select * into v_flower
    from public.wonder_flower_instances
    where user_id = v_user_id and flower_id = p_flower_id
    for update;
    if not found then
        v_response := wonder_private.wonder_error('WW_FLOWER_NOT_FOUND', 'That flower is not in your garden.', p_idempotency_key, false, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;
    if v_flower.version <> p_expected_version then
        v_response := wonder_private.wonder_error('WW_STALE_OBJECT', 'That flower changed. Refresh its arrangement.', p_idempotency_key, true, v_base, pg_catalog.jsonb_build_object('flower_version', v_flower.version));
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;
    if v_flower.state <> 'living' or v_flower.deadline_utc <= v_now then
        v_response := wonder_private.wonder_error('WW_FLOWER_EXPIRED', 'That flower has already faded.', p_idempotency_key, false, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;
    if not exists (
        select 1 from public.wonder_vase_assignments
        where user_id = v_user_id and flower_id = p_flower_id
    ) then
        v_response := wonder_private.wonder_error('WW_NOT_DISPLAYED', 'Display the flower before using Sunshine.', p_idempotency_key, false, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;
    if v_profile.glow_balance < 20 then
        v_response := wonder_private.wonder_error(
            'WW_INSUFFICIENT_GLOW', 'You need 20 Glow to use Sunshine.',
            p_idempotency_key, false, v_base,
            pg_catalog.jsonb_build_object('required_glow', 20, 'glow_balance', v_profile.glow_balance)
        );
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;

    perform wonder_private.wonder_process_expired_flowers(v_user_id, v_now);
    v_ledger := wonder_private.wonder_append_glow_entry(v_user_id, -20, 'sunshine', p_idempotency_key, p_flower_id);
    update public.wonder_flower_instances
    set deadline_utc = deadline_utc + interval '1 day',
        extension_seconds = extension_seconds + 86400,
        version = version + 1
    where user_id = v_user_id and flower_id = p_flower_id;
    insert into public.wonder_flower_events (
        user_id, flower_id, event_type, occurred_at, idempotency_key, glow_amount
    ) values (
        v_user_id, p_flower_id, 'sunshine', v_now, p_idempotency_key, -20
    );
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(
        p_idempotency_key, v_base, v_revision, false,
        pg_catalog.jsonb_build_object(
            'flower_id', p_flower_id,
            'extension_seconds', v_flower.extension_seconds + 86400,
            'glow_balance', v_ledger.balance_after,
            'flower_version', p_expected_version + 1
        )
    );
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
    return v_response;
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
    v_balance integer;
    v_response jsonb;
begin
    if v_user_id is null then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Sign in to visit the Shop.', p_idempotency_key, false, 0);
    end if;
    perform wonder_private.wonder_lock_player(v_user_id);
    select * into v_profile from public.wonder_profiles where user_id = v_user_id for update;
    if not found then
        return wonder_private.wonder_error('WW_AUTH_REQUIRED', 'Open the garden before shopping.', p_idempotency_key, false, 0);
    end if;
    v_base := v_profile.state_revision;
    v_idempotency := wonder_private.wonder_begin_idempotency(
        v_user_id, p_idempotency_key, 'wonder_purchase_shop_item',
        pg_catalog.jsonb_build_object('item_key', p_item_key, 'expected_revision', p_expected_revision)
    );
    if v_idempotency.replayed then
        return coalesce(v_idempotency.response_json, wonder_private.wonder_error('WW_RETRYABLE_IN_FLIGHT', 'The request is still being finalized.', p_idempotency_key, true, v_base));
    end if;
    if p_expected_revision is null or p_expected_revision <> v_base then
        v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;

    select * into v_item
    from public.wonder_shop_items
    where item_key = p_item_key and active
    for update;
    if not found then
        v_response := wonder_private.wonder_error('WW_SHOP_ITEM_UNAVAILABLE', 'That Shop item is unavailable.', p_idempotency_key, false, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;
    if exists (
        select 1 from public.wonder_player_entitlements
        where user_id = v_user_id and item_key = p_item_key
    ) then
        v_response := wonder_private.wonder_error('WW_ALREADY_OWNED', 'That item is already in your garden.', p_idempotency_key, false, v_base);
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;
    if v_profile.glow_balance < v_item.glow_cost then
        v_response := wonder_private.wonder_error(
            'WW_INSUFFICIENT_GLOW', 'You do not have enough Glow for that item.',
            p_idempotency_key, false, v_base,
            pg_catalog.jsonb_build_object('required_glow', v_item.glow_cost, 'glow_balance', v_profile.glow_balance)
        );
        perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
        return v_response;
    end if;

    if v_item.glow_cost > 0 then
        v_ledger := wonder_private.wonder_append_glow_entry(v_user_id, -v_item.glow_cost, 'shop_purchase', p_idempotency_key, null);
        v_balance := v_ledger.balance_after;
    else
        v_balance := v_profile.glow_balance;
    end if;
    insert into public.wonder_player_entitlements (
        user_id, item_key, paid_ledger_id
    ) values (
        v_user_id, p_item_key, v_ledger.entry_id
    );
    if v_item.kind = 'vase_slot_unlock' then
        update public.wonder_vase_slots
        set unlocked = true
        where user_id = v_user_id and slot = v_item.slot_number;
    end if;
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(
        p_idempotency_key, v_base, v_revision, false,
        pg_catalog.jsonb_build_object(
            'item', pg_catalog.to_jsonb(v_item),
            'entitlement', pg_catalog.jsonb_build_object('item_key', p_item_key),
            'glow_balance', v_balance
        )
    );
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
    return v_response;
end;
$$;

commit;
