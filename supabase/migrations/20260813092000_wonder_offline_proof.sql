begin;

alter function public.wonder_sync_offline_wander(
    uuid, timestamptz, date, text, integer, text, text[], jsonb, bigint, uuid
) set schema wonder_private;

revoke all on function wonder_private.wonder_sync_offline_wander(
    uuid, timestamptz, date, text, integer, text, text[], jsonb, bigint, uuid
) from public, anon, authenticated, service_role;

create or replace function public.wonder_sync_offline_wander(
    p_session_id uuid,
    p_start_utc timestamptz,
    p_local_date date,
    p_time_zone text,
    p_catalog_version integer,
    p_catalog_checksum text,
    p_offer_slugs text[],
    p_reached_tiers jsonb,
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
    v_now timestamptz := timezone('utc', clock_timestamp());
begin
    if p_start_utc is not null and p_time_zone is not null then
        p_time_zone := wonder_private.wonder_require_time_zone(p_time_zone);
        if p_local_date is distinct from (p_start_utc at time zone p_time_zone)::date then
            return wonder_private.wonder_error(
                'WW_INVALID_OFFLINE_PROOF',
                'The offline local date does not match its start time.',
                p_idempotency_key, false, 0
            );
        end if;
    end if;

    if pg_catalog.jsonb_typeof(p_reached_tiers) = 'array' then
        if exists (
            select 1
            from pg_catalog.jsonb_to_recordset(p_reached_tiers)
                as x(tier integer, species_slug text, elapsed_seconds integer)
            where x.elapsed_seconds is null
               or x.elapsed_seconds < 0
               or x.elapsed_seconds > 3600
               or p_start_utc + (x.elapsed_seconds * interval '1 second')
                    > v_now + interval '5 minutes'
        ) then
            return wonder_private.wonder_error(
                'WW_INVALID_OFFLINE_PROOF',
                'Offline threshold evidence exceeds elapsed time.',
                p_idempotency_key, false, 0
            );
        end if;

        if (
            exists (
                select 1
                from pg_catalog.jsonb_to_recordset(p_reached_tiers)
                    as x(tier integer)
                where x.tier = 20
            ) and not exists (
                select 1
                from pg_catalog.jsonb_to_recordset(p_reached_tiers)
                    as x(tier integer)
                where x.tier = 10
            )
        ) or (
            exists (
                select 1
                from pg_catalog.jsonb_to_recordset(p_reached_tiers)
                    as x(tier integer)
                where x.tier = 30
            ) and (
                not exists (
                    select 1
                    from pg_catalog.jsonb_to_recordset(p_reached_tiers)
                        as x(tier integer)
                    where x.tier = 10
                ) or not exists (
                    select 1
                    from pg_catalog.jsonb_to_recordset(p_reached_tiers)
                        as x(tier integer)
                    where x.tier = 20
                )
            )
        ) then
            return wonder_private.wonder_error(
                'WW_INVALID_OFFLINE_PROOF',
                'Offline tiers must be submitted in threshold order.',
                p_idempotency_key, false, 0
            );
        end if;

        if (
            select count(*) <> count(distinct species_slug)
            from pg_catalog.jsonb_to_recordset(p_reached_tiers)
                as x(species_slug text)
        ) then
            return wonder_private.wonder_error(
                'WW_CATALOG_MISMATCH',
                'Offline tiers must use distinct retained offers.',
                p_idempotency_key, false, 0
            );
        end if;
    end if;

    return wonder_private.wonder_sync_offline_wander(
        p_session_id,
        p_start_utc,
        p_local_date,
        p_time_zone,
        p_catalog_version,
        p_catalog_checksum,
        p_offer_slugs,
        p_reached_tiers,
        p_expected_revision,
        p_idempotency_key
    );
end;
$$;

revoke all on function public.wonder_sync_offline_wander(
    uuid, timestamptz, date, text, integer, text, text[], jsonb, bigint, uuid
) from public, anon, authenticated, service_role;
grant execute on function public.wonder_sync_offline_wander(
    uuid, timestamptz, date, text, integer, text, text[], jsonb, bigint, uuid
) to authenticated;

commit;
