-- A household's read-only API, for the owner's own automation: a Home
-- Assistant dashboard showing what fuel costs this month, a script that pages
-- when something is overdue.
--
-- Keys are stored as SHA-256 hashes. The key itself is shown once, in the app,
-- and never again — the same shape as any other credential.
create table public.api_keys (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  key_hash text not null unique check (key_hash ~ '^[0-9a-f]{64}$'),
  key_preview text not null,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  last_used_at timestamptz,
  revoked_at timestamptz
);

create index api_keys_household_idx on public.api_keys (household_id);

alter table public.api_keys enable row level security;

-- Members manage their own household's keys. The hash column is readable by
-- them, which is harmless: it is a hash, and they hold the key anyway.
create policy api_keys_select on public.api_keys
  for select to authenticated
  using (household_id in (select public.user_household_ids()));

create policy api_keys_insert on public.api_keys
  for insert to authenticated
  with check (
    household_id in (select public.user_household_ids())
    and created_by = (select auth.uid())
  );

create policy api_keys_update on public.api_keys
  for update to authenticated
  using (household_id in (select public.user_household_ids()))
  with check (household_id in (select public.user_household_ids()));

create policy api_keys_delete on public.api_keys
  for delete to authenticated
  using (household_id in (select public.user_household_ids()));

grant select, insert, update, delete on public.api_keys to authenticated;

-- Outbound notifications: a URL the household wants told when something
-- happens. Delivery is best-effort and signed with the secret below, so the
-- receiver can tell a real call from a spoofed one.
create table public.webhooks (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  url text not null check (url ~ '^https://'),
  secret text not null,
  events text[] not null default array['entry.created', 'reminder.due'],
  active boolean not null default true,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  last_delivery_at timestamptz,
  last_delivery_status int
);

create index webhooks_household_idx on public.webhooks (household_id);

alter table public.webhooks enable row level security;

create policy webhooks_select on public.webhooks
  for select to authenticated
  using (household_id in (select public.user_household_ids()));

create policy webhooks_insert on public.webhooks
  for insert to authenticated
  with check (
    household_id in (select public.user_household_ids())
    and created_by = (select auth.uid())
  );

create policy webhooks_update on public.webhooks
  for update to authenticated
  using (household_id in (select public.user_household_ids()))
  with check (household_id in (select public.user_household_ids()));

create policy webhooks_delete on public.webhooks
  for delete to authenticated
  using (household_id in (select public.user_household_ids()));

grant select, insert, update, delete on public.webhooks to authenticated;

-- Resolves a presented API key to the household it belongs to, and stamps the
-- key as used. Security definer so the edge function can call it with the
-- anon key: there is no session behind an API request.
create function public.household_for_api_key(key_hash_input text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target uuid;
begin
  update public.api_keys
     set last_used_at = now()
   where key_hash = key_hash_input
     and revoked_at is null
  returning household_id into target;

  return target;
end;
$$;

revoke execute on function public.household_for_api_key(text) from public;
grant execute on function public.household_for_api_key(text) to service_role;
