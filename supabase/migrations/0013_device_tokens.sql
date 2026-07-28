-- FCM registration tokens, one row per device. Read in bulk by the
-- push-due-reminders Edge Function (service role); users only ever touch
-- their own rows.
create table public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  updated_at timestamptz not null default now()
);

create index device_tokens_user_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

create policy device_tokens_select on public.device_tokens
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy device_tokens_insert on public.device_tokens
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy device_tokens_update on public.device_tokens
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy device_tokens_delete on public.device_tokens
  for delete to authenticated
  using (user_id = (select auth.uid()));

grant select, insert, update, delete on public.device_tokens to authenticated;
