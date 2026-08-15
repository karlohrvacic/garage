-- Where the dispatch endpoint is configured.
--
-- 0024 read it from `app.settings.*`, which cannot be set on Supabase: only a
-- superuser may define a custom parameter at database level, and the managed
-- role is not one. A table works with the privileges we actually have, and has
-- the better property anyway — the value is visible to a `select` when someone
-- is asking "why did no webhook fire?", instead of hiding in a session GUC.
--
-- Configure a project by inserting its one row:
--
--   insert into public.webhook_dispatch_config (endpoint, auth_token)
--   values ('https://<ref>.supabase.co/functions/v1/dispatch-webhooks', '<anon key>')
--   on conflict (id) do update
--     set endpoint = excluded.endpoint,
--         auth_token = excluded.auth_token,
--         updated_at = now();
--
-- No row means no dispatch, which is what local development and CI want.
create table public.webhook_dispatch_config (
  -- One row, enforced by the type: `true` is the only value that passes.
  id boolean primary key default true check (id),
  endpoint text not null check (endpoint ~ '^https://'),
  auth_token text,
  updated_at timestamptz not null default now()
);

-- RLS on with no policy at all: this is operator configuration, and no signed-in
-- user has any business reading the token it holds. The dispatcher reaches it
-- as definer, which is not subject to policies.
alter table public.webhook_dispatch_config enable row level security;
revoke all on public.webhook_dispatch_config from anon, authenticated;

comment on table public.webhook_dispatch_config is
  'Single-row operator config for outbound webhook delivery. Not user data.';

create or replace function public.dispatch_entry_webhook()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  config public.webhook_dispatch_config;
begin
  select * into config from public.webhook_dispatch_config limit 1;
  if not found then
    return new;
  end if;

  -- Nothing about delivery may endanger the write that triggered it: a
  -- household logging fuel in a tunnel must not fail because a home-automation
  -- box is unreachable. pg_net queues the request and returns immediately, and
  -- anything it still manages to raise is swallowed here.
  begin
    perform net.http_post(
      url := config.endpoint,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || coalesce(config.auth_token, '')
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
  'webhook_dispatch_config has a row.';
