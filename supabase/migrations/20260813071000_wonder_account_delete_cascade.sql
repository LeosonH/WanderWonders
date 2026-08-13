begin;

create or replace function wonder_private.wonder_reject_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if tg_op = 'UPDATE' then
        raise exception 'immutable Wander Wonders row' using errcode = '42501';
    end if;

    if tg_op = 'DELETE' and exists (
        select 1
        from public.wonder_profiles
        where user_id = old.user_id
    ) then
        raise exception 'immutable Wander Wonders row' using errcode = '42501';
    end if;

    return old;
end;
$$;

revoke all on function wonder_private.wonder_reject_immutable() from public, anon, authenticated;

commit;
