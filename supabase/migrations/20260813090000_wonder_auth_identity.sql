begin;

create or replace function wonder_private.wonder_register_auth_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_approval text;
begin
    if new.provider not in ('apple', 'google') then
        return new;
    end if;

    insert into public.wonder_profiles (user_id)
    values (new.user_id)
    on conflict (user_id) do nothing;

    v_approval := case
        when exists (
            select 1
            from public.wonder_account_identities
            where user_id = new.user_id
        ) then 'explicit_link'
        else 'initial'
    end;

    insert into public.wonder_account_identities (
        identity_id, user_id, provider, provider_identity_id, approval
    ) values (
        new.id, new.user_id, new.provider, new.provider_id, v_approval
    ) on conflict do nothing;

    return new;
end;
$$;

revoke all on function wonder_private.wonder_register_auth_identity() from public, anon, authenticated, service_role;

drop trigger if exists wonder_register_auth_identity on auth.identities;
create trigger wonder_register_auth_identity
after insert on auth.identities
for each row execute function wonder_private.wonder_register_auth_identity();

insert into public.wonder_profiles (user_id)
select distinct i.user_id
from auth.identities i
where i.provider in ('apple', 'google')
on conflict (user_id) do nothing;

with supported as (
    select
        i.id,
        i.user_id,
        i.provider,
        i.provider_id,
        row_number() over (
            partition by i.user_id
            order by i.created_at, i.id
        ) as identity_order
    from auth.identities i
    where i.provider in ('apple', 'google')
)
insert into public.wonder_account_identities (
    identity_id, user_id, provider, provider_identity_id, approval
)
select
    id,
    user_id,
    provider,
    provider_id,
    case when identity_order = 1 then 'initial' else 'explicit_link' end
from supported
on conflict do nothing;

commit;
