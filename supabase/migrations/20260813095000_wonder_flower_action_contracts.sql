begin;

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
    if p_expected_revision is null or p_expected_revision <> v_base then v_response := wonder_private.wonder_error('WW_STALE_REVISION', 'Your saved garden changed. Refresh and try again.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;

    select * into v_flower from public.wonder_flower_instances where user_id = v_user_id and flower_id = p_flower_id for update;
    if not found then v_response := wonder_private.wonder_error('WW_FLOWER_NOT_FOUND', 'That flower is not in your garden.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_flower.version <> p_expected_version then v_response := wonder_private.wonder_error('WW_STALE_OBJECT', 'That flower changed. Refresh its arrangement.', p_idempotency_key, true, v_base, pg_catalog.jsonb_build_object('flower_version', v_flower.version)); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_flower.state <> 'living' or v_flower.deadline_utc <= v_now then v_response := wonder_private.wonder_error('WW_FLOWER_EXPIRED', 'Only a living flower can be displayed.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    select * into v_slot from public.wonder_vase_slots where user_id = v_user_id and slot = p_slot for update;
    if not found or not v_slot.unlocked or p_position > v_slot.capacity then v_response := wonder_private.wonder_error('WW_VASE_LOCKED', 'That vase position is not unlocked.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if exists (select 1 from public.wonder_vase_assignments where user_id = v_user_id and slot = p_slot and position = p_position) then v_response := wonder_private.wonder_error('WW_VASE_POSITION_TAKEN', 'That vase position is already occupied.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if exists (select 1 from public.wonder_vase_assignments where user_id = v_user_id and flower_id = p_flower_id) then v_response := wonder_private.wonder_error('WW_FLOWER_ALREADY_DISPLAYED', 'That flower is already displayed.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;

    perform wonder_private.wonder_process_expired_flowers(v_user_id, v_now);
    insert into public.wonder_vase_assignments (user_id, slot, position, flower_id, assigned_at) values (v_user_id, p_slot, p_position, p_flower_id, v_now);
    update public.wonder_flower_instances set version = version + 1 where user_id = v_user_id and flower_id = p_flower_id;
    insert into public.wonder_flower_events (user_id, flower_id, event_type, occurred_at, idempotency_key, vase_slot, vase_position) values (v_user_id, p_flower_id, 'vase_assigned', v_now, p_idempotency_key, p_slot, p_position);
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('assignment', pg_catalog.jsonb_build_object('slot', p_slot, 'position', p_position, 'flower_id', p_flower_id), 'flower_version', p_expected_version + 1));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
    return v_response;
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

    select * into v_flower from public.wonder_flower_instances where user_id = v_user_id and flower_id = p_flower_id for update;
    if not found then v_response := wonder_private.wonder_error('WW_FLOWER_NOT_FOUND', 'That flower is not in your garden.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_flower.version <> p_expected_version then v_response := wonder_private.wonder_error('WW_STALE_OBJECT', 'That flower changed. Refresh its arrangement.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_flower.state <> 'living' or v_flower.deadline_utc <= v_now then v_response := wonder_private.wonder_error('WW_FLOWER_EXPIRED', 'That flower has already faded.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    select * into v_assignment from public.wonder_vase_assignments where user_id = v_user_id and flower_id = p_flower_id for update;
    if not found then v_response := wonder_private.wonder_error('WW_NOT_DISPLAYED', 'That flower is not currently displayed.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;

    perform wonder_private.wonder_process_expired_flowers(v_user_id, v_now);
    delete from public.wonder_vase_assignments where user_id = v_user_id and flower_id = p_flower_id;
    update public.wonder_flower_instances set version = version + 1 where user_id = v_user_id and flower_id = p_flower_id;
    insert into public.wonder_flower_events (user_id, flower_id, event_type, occurred_at, idempotency_key, vase_slot, vase_position) values (v_user_id, p_flower_id, 'vase_removed', v_now, p_idempotency_key, v_assignment.slot, v_assignment.position);
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('flower_id', p_flower_id, 'removed_slot', v_assignment.slot, 'removed_position', v_assignment.position, 'flower_version', p_expected_version + 1));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
    return v_response;
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

    select * into v_flower from public.wonder_flower_instances where user_id = v_user_id and flower_id = p_flower_id for update;
    if not found then v_response := wonder_private.wonder_error('WW_FLOWER_NOT_FOUND', 'That flower is not in your garden.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_flower.version <> p_expected_version then v_response := wonder_private.wonder_error('WW_STALE_OBJECT', 'That flower changed. Refresh its arrangement.', p_idempotency_key, true, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;
    if v_flower.state <> 'living' or v_flower.deadline_utc <= v_now then v_response := wonder_private.wonder_error('WW_FLOWER_EXPIRED', 'That flower has already faded.', p_idempotency_key, false, v_base); perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response); return v_response; end if;

    perform wonder_private.wonder_process_expired_flowers(v_user_id, v_now);
    delete from public.wonder_vase_assignments where user_id = v_user_id and flower_id = p_flower_id;
    update public.wonder_flower_instances set state = 'pressed', version = version + 1 where user_id = v_user_id and flower_id = p_flower_id;
    update public.wonder_discoveries set pressed_count = pressed_count + 1 where user_id = v_user_id and species_id = v_flower.species_id;
    insert into public.wonder_flower_events (user_id, flower_id, event_type, occurred_at, idempotency_key) values (v_user_id, p_flower_id, 'pressed_early', v_now, p_idempotency_key);
    v_revision := wonder_private.wonder_increment_revision(v_user_id);
    v_response := wonder_private.wonder_mutation_response(p_idempotency_key, v_base, v_revision, false, pg_catalog.jsonb_build_object('flower_id', p_flower_id, 'state', 'pressed', 'flower_version', p_expected_version + 1));
    perform wonder_private.wonder_finish_idempotency(v_user_id, p_idempotency_key, v_response);
    return v_response;
end;
$$;

commit;
