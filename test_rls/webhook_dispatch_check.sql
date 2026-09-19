-- Properties migrations 0024 and 0079 have to establish, asserted against a
-- live database.
--
-- Run with:
--   supabase db query --local -f test_rls/webhook_dispatch_check.sql
--   supabase db query --linked -f test_rls/webhook_dispatch_check.sql
--
-- Raises on the first broken property; prints one row per property otherwise.
-- The Dart suite cannot cover this: PostgREST exposes `public`, and every
-- assertion here is about pg_catalog, the `net` and `cron` schemas, or a GUC.
do $$
declare
  missing text;
begin
  -- 1. pg_net is what actually performs the call, asynchronously, so a slow or
  --    dead receiver cannot hold a user's insert open.
  if not exists (select 1 from pg_extension where extname = 'pg_net') then
    raise exception 'pg_net is not installed';
  end if;

  -- 2. One outbox trigger per table a household's hooks hear about (0079),
  --    and the one that pokes the dispatcher for the app's test ping.
  for missing in
    select t
    from unnest(array[
      'fuel_entries', 'service_entries', 'cost_entries', 'odometer_entries',
      'trip_entries', 'income_entries', 'vehicles', 'vehicle_guest_passes',
      'household_members'
    ]) as t
    where not exists (
      select 1
      from pg_trigger tr
      join pg_class c on c.oid = tr.tgrelid
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = t
        and tr.tgname = 'dispatch_webhook_on_change'
        and not tr.tgisinternal
    )
  loop
    raise exception 'no dispatch trigger on public.%', missing;
  end loop;

  if not exists (
    select 1
    from pg_trigger tr
    join pg_class c on c.oid = tr.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'webhook_outbox'
      and tr.tgname = 'poke_on_ping'
      and not tr.tgisinternal
  ) then
    raise exception 'no poke trigger on public.webhook_outbox';
  end if;

  -- 3. Everything that writes the outbox or pokes runs as definer: it is
  --    called from a trigger on a table the caller may only reach through
  --    RLS, or from a function they may not call, and must not depend on
  --    their rights to queue the event.
  for missing in
    select f
    from unnest(array[
      'dispatch_entry_webhook', 'dispatch_vehicle_webhook',
      'dispatch_guest_pass_webhook', 'dispatch_member_webhook',
      'poke_on_ping', 'enqueue_webhook_event', 'poke_webhook_dispatch'
    ]) as f
    where not exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = f
        and p.prosecdef
    )
  loop
    raise exception '% is missing or not security definer', missing;
  end loop;

  -- 4. The cron is the guarantee behind the poke, and the sweep is what keeps
  --    the log to thirty days.
  for missing in
    select j
    from unnest(array['drain-webhooks', 'prune-webhook-history']) as j
    where not exists (select 1 from cron.job where jobname = j)
  loop
    raise exception 'cron job % is not scheduled', missing;
  end loop;

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
