-- Schedules the daily push for reminders entering their due window.
--
-- The function itself has been in the repo since 0013 and was activated by
-- hand, from a snippet in a runbook, which is the same "someone remembers to
-- run it" problem that kept the RLS suite out of CI. Migrations apply
-- themselves on push to main, so the schedule belongs in one.
--
-- The credential does not. `push-due-reminders` checks the Authorization
-- header against `SUPABASE_SERVICE_ROLE_KEY`, and that key is the whole
-- database, so it is read from Vault rather than committed here or kept in a
-- plain table the way `webhook_dispatch_config` keeps its anon token. Nothing
-- in this file is a secret, and a checkout without the secrets simply does
-- nothing.
--
-- Configure a project once, in the SQL editor, and never in git:
--
--   select vault.create_secret('https://<ref>.supabase.co/functions/v1/push-due-reminders', 'push_endpoint');
--   select vault.create_secret('<service-role-key>', 'push_service_role_key');
--
-- Rotate by replacing the secret; the schedule reads it fresh on every run.

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

-- Wrapped in a function rather than inlined into cron.schedule so that an
-- unconfigured project — local development, CI, a fresh clone — returns
-- quietly instead of failing a job every morning and filling cron.job_run_details
-- with noise nobody asked for.
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
    body := '{}'::jsonb
  );
end;
$$;

comment on function public.run_due_reminders_push is
  'Calls the push-due-reminders Edge Function. No-op until the push_endpoint '
  'and push_service_role_key secrets exist in Vault.';

-- Nobody signs in and calls this.
revoke all on function public.run_due_reminders_push() from anon, authenticated;

-- 06:00 UTC daily. The function pushes an item on exactly one day — the lead
-- time it shares with the app — so running once a day is what makes that
-- single-shot without any bookkeeping table; running it more often would send
-- the same reminder again.
--
-- (This comment said "14, 7, 1 and 0 days" when it was applied. The function
-- was later cut back to the one lead time the app schedules its own reminders
-- with, so a household is not told about the same visit four times. The SQL
-- below is unchanged and this file has already run; only the wrong sentence
-- is corrected.)
select cron.unschedule('push-due-reminders-daily')
where exists (
  select 1 from cron.job where jobname = 'push-due-reminders-daily'
);

select cron.schedule(
  'push-due-reminders-daily',
  '0 6 * * *',
  $$select public.run_due_reminders_push()$$
);
