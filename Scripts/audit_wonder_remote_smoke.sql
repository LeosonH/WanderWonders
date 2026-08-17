begin;

insert into auth.users (id)
values ('00000000-0000-0000-0000-000000009901'::uuid);

insert into public.wonder_profiles (user_id)
values ('00000000-0000-0000-0000-000000009901'::uuid);

insert into public.wonder_account_identities (
    user_id, provider, provider_identity_id, approval
)
values (
    '00000000-0000-0000-0000-000000009901'::uuid,
    'apple', 'remote-smoke-9901', 'initial'
);

select set_config(
    'request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000009901',
    true
);
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000009901","role":"authenticated"}',
    true
);

do $smoke$
declare
    v_bootstrap jsonb;
    v_start jsonb;
    v_replay jsonb;
    v_refresh jsonb;
    v_revision bigint;
begin
    v_bootstrap := public.wonder_bootstrap(
        'America/Los_Angeles',
        '00000000-0000-0000-0000-000000009902'::uuid
    );
    if not coalesce((v_bootstrap ->> 'ok')::boolean, false) then
        raise exception 'bootstrap failed: %', v_bootstrap;
    end if;
    v_revision := (v_bootstrap ->> 'state_revision')::bigint;

    v_start := public.wonder_start_manual_wander(
        'manual',
        '00000000-0000-0000-0000-000000009903'::uuid,
        'America/Los_Angeles',
        v_revision,
        '00000000-0000-0000-0000-000000009904'::uuid,
        false
    );
    if not coalesce((v_start ->> 'ok')::boolean, false) then
        raise exception 'manual Wander failed: %', v_start;
    end if;

    v_replay := public.wonder_start_manual_wander(
        'manual',
        '00000000-0000-0000-0000-000000009903'::uuid,
        'America/Los_Angeles',
        v_revision,
        '00000000-0000-0000-0000-000000009904'::uuid,
        false
    );
    if not coalesce((v_replay ->> 'replayed')::boolean, false) then
        raise exception 'idempotent replay failed: %', v_replay;
    end if;

    if (select count(*) from public.wonder_wander_offers
        where session_id = '00000000-0000-0000-0000-000000009903'::uuid) <> 3 then
        raise exception 'manual Wander did not create exactly three offers';
    end if;
    if (select count(*) from public.wonder_wander_rewards
        where session_id = '00000000-0000-0000-0000-000000009903'::uuid) <> 3 then
        raise exception 'manual Wander did not reserve exactly three rewards';
    end if;

    v_refresh := public.wonder_refresh_state();
    if not coalesce((v_refresh ->> 'ok')::boolean, false) then
        raise exception 'refresh failed: %', v_refresh;
    end if;
end
$smoke$;

rollback;

select 'remote transactional smoke passed: bootstrap, manual Wander, replay, refresh' as result;
