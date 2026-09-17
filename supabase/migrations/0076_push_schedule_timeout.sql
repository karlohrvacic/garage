-- The daily reminder run is given a minute to answer, and only the schedule
-- may start it.
--
-- The run now calls the garages' webhooks, and waits up to ten seconds on
-- them, before it sends a single push. 0027 started it with pg_net's default
-- timeout of five seconds, after which pg_net stops waiting and records the
-- request in `net._http_response` as timed out, with no answer to read. A
-- minute covers the hooks and the pushes after them.
--
-- 0027 revoked the function from `anon` and `authenticated` but not from
-- PUBLIC, which every role belongs to and which Postgres grants execute on a
-- new function. Both could therefore still call it through the API, as
-- `rpc/run_due_reminders_push`, and it starts the run with the service-role
-- key it reads from Vault: anybody holding the anon key, which ships in every
-- copy of the app, could have every garage's due reminders sent again, pushes
-- and webhooks alike, as often as they liked. The job runs as the function's
-- owner, who keeps the right to execute it.
--
-- The function is otherwise 0027's, word for word.

create or replace function public.run_due_reminders_push()
returns void
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  endpoint text;
  auth_token text;
begin
  select decrypted_secret into endpoint
  from vault.decrypted_secrets where name = 'push_endpoint';

  select decrypted_secret into auth_token
  from vault.decrypted_secrets where name = 'push_service_role_key';

  if endpoint is null or auth_token is null then
    -- Not configured for pushing. This is the normal state everywhere except
    -- production, so it is silent by design.
    return;
  end if;

  perform net.http_post(
    url := endpoint,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || auth_token
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
end;
$$;

revoke execute on function public.run_due_reminders_push() from public;
revoke all on function public.run_due_reminders_push() from anon, authenticated;
