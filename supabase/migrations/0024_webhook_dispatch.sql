-- Fires the `dispatch-webhooks` edge function when a household logs something.
--
-- Supabase's dashboard "Database Webhooks" feature would do this too, but it
-- lives only in the dashboard: a fresh project would silently have no webhooks
-- until someone remembered to click it, and the trigger it writes embeds a
-- service-role key in its arguments, visible to anyone who can read the schema.
-- This is the same mechanism (pg_net) declared where the rest of the schema is.
--
-- The endpoint is configuration, not schema, so it is not written here: it
-- differs per project and this file is in git. 0025 moves it into
-- `webhook_dispatch_config` — the settings read below cannot be set on Supabase
-- without superuser, which this migration learned the hard way.
--
-- Unconfigured, the trigger is a no-op. That is deliberate: local development
-- and CI must not call out to anything.
create extension if not exists pg_net with schema extensions;

create or replace function public.dispatch_entry_webhook()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  endpoint text := nullif(
    current_setting('app.settings.webhook_dispatch_url', true), ''
  );
  token text := nullif(
    current_setting('app.settings.webhook_dispatch_key', true), ''
  );
begin
  if endpoint is null then
    return new;
  end if;

  -- Nothing about delivery may endanger the write that triggered it: a
  -- household logging fuel in a tunnel must not fail because a home-automation
  -- box is unreachable. pg_net queues the request and returns immediately, and
  -- anything it still manages to raise is swallowed here.
  begin
    perform net.http_post(
      url := endpoint,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || coalesce(token, '')
      ),
      -- The shape Supabase's own Database Webhooks post, so the edge function
      -- reads the same payload either way.
      body := jsonb_build_object(
        'type', tg_op,
        'table', tg_table_name,
        'record', to_jsonb(new),
        'old_record', null
      ),
      timeout_milliseconds := 5000
    );
  exception
    when others then
      null;
  end;

  return new;
end;
$$;

comment on function public.dispatch_entry_webhook() is
  'Posts a new entry to the dispatch-webhooks function; no-op until '
  'app.settings.webhook_dispatch_url is set.';

-- Only what a dashboard would want to react to. Deletes and edits are left
-- out: a receiver that missed one can read the current state from the API,
-- and every extra event is another URL call per user action.
create trigger dispatch_webhook_on_insert
  after insert on public.fuel_entries
  for each row execute function public.dispatch_entry_webhook();

create trigger dispatch_webhook_on_insert
  after insert on public.service_entries
  for each row execute function public.dispatch_entry_webhook();

create trigger dispatch_webhook_on_insert
  after insert on public.cost_entries
  for each row execute function public.dispatch_entry_webhook();
