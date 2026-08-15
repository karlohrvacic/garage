-- Properties migration 0024 has to establish, asserted against a live database.
--
-- Run with:
--   supabase db query --local -f test_rls/webhook_dispatch_check.sql
--   supabase db query --linked -f test_rls/webhook_dispatch_check.sql
--
-- Raises on the first broken property; prints one row per property otherwise.
-- The Dart suite cannot cover this: PostgREST exposes `public`, and every
-- assertion here is about pg_catalog, the `net` schema, or a GUC.
do $$
declare
  missing text;
begin
  -- 1. pg_net is what actually performs the call, asynchronously, so a slow or
  --    dead receiver cannot hold a user's insert open.
  if not exists (select 1 from pg_extension where extname = 'pg_net') then
    raise exception 'pg_net is not installed';
  end if;

  -- 2. One trigger per table a household's dashboard cares about.
  for missing in
    select t
    from unnest(array['fuel_entries', 'service_entries', 'cost_entries']) as t
    where not exists (
      select 1
      from pg_trigger tr
      join pg_class c on c.oid = tr.tgrelid
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = t
        and tr.tgname = 'dispatch_webhook_on_insert'
        and not tr.tgisinternal
    )
  loop
    raise exception 'no dispatch trigger on public.%', missing;
  end loop;

  -- 3. The dispatcher runs as definer: it is called from a trigger on a table
  --    the caller may only reach through RLS, and must not depend on their
  --    rights to queue the call.
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'dispatch_entry_webhook'
      and p.prosecdef
  ) then
    raise exception 'dispatch_entry_webhook is missing or not security definer';
  end if;

  -- Configuration is environment state, not a property of the schema: an
  -- unconfigured database is correct locally and wrong in production, so this
  -- reports it rather than judging it.
  raise notice 'webhook dispatch wiring is in place (endpoint: %)',
    coalesce(
      (select endpoint from public.webhook_dispatch_config limit 1),
      'not configured'
    );
end;
$$;
