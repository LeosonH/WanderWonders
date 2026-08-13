\set ON_ERROR_STOP on

do $audit$
declare
    v_count integer;
begin
    select count(*) into v_count
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relname like 'wonder\_%' escape '\';
    if v_count <> 22 then raise exception 'expected 22 wonder tables, found %', v_count; end if;

    select count(*) into v_count
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'wonder\_%' escape '\';
    if v_count <> 24 then raise exception 'expected 24 public RPCs, found %', v_count; end if;

    select count(*) into v_count
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'wonder_private';
    if v_count <> 22 then raise exception 'expected 22 private helpers after additive hardening, found %', v_count; end if;

    select count(*) into v_count
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relname like 'wonder\_%' escape '\'
      and c.relrowsecurity and c.relforcerowsecurity;
    if v_count <> 22 then raise exception 'all 22 tables must enable and force RLS, found %', v_count; end if;

    select count(*) into v_count
    from information_schema.role_table_grants
    where table_schema = 'public' and table_name like 'wonder\_%' escape '\'
      and grantee in ('PUBLIC', 'anon', 'authenticated');
    if v_count <> 0 then raise exception 'client-facing direct table grants found: %', v_count; end if;

    if not exists (
        select 1
        from pg_catalog.pg_constraint c
        join pg_catalog.pg_class child on child.oid = c.conrelid
        join pg_catalog.pg_namespace n on n.oid = child.relnamespace
        where c.contype = 'f' and n.nspname = 'public' and child.relname = 'wonder_profiles'
          and c.confdeltype = 'c'
    ) then raise exception 'wonder_profiles auth owner cascade is missing'; end if;
end
$audit$;

select 'schema audit passed: 22 tables, 24 RPCs, 22 helpers, forced RLS, no client table grants' as result;
