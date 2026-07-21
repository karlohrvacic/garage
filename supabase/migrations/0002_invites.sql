create table public.invites (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  code text not null unique check (char_length(code) = 8),
  email text,
  expires_at timestamptz not null,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  redeemed_at timestamptz,
  redeemed_by uuid references auth.users (id)
);

create index invites_household_idx on public.invites (household_id);

alter table public.invites enable row level security;

-- Codes are readable only by the household that issued them. A joiner never
-- selects the invite row; they redeem it through the definer function below,
-- so an attacker cannot enumerate codes by querying the table.
create policy invites_select on public.invites
  for select to authenticated
  using (household_id in (select public.user_household_ids()));

create policy invites_delete on public.invites
  for delete to authenticated
  using (household_id in (select public.user_household_ids()));

-- Excludes visually ambiguous characters (0/O, 1/I) because these codes get
-- read aloud and typed by hand.
create function public.generate_invite_code()
returns text
language sql
volatile
as $$
  select string_agg(
    substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', floor(random() * 32)::int + 1, 1),
    ''
  )
  from generate_series(1, 8)
$$;

create function public.create_invite(
  target_household uuid,
  invite_email text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
  attempts int := 0;
begin
  if target_household not in (select public.user_household_ids()) then
    raise exception 'not a member of this household';
  end if;

  loop
    new_code := public.generate_invite_code();
    exit when not exists (select 1 from public.invites where code = new_code);
    attempts := attempts + 1;
    if attempts > 10 then
      raise exception 'could not allocate an invite code';
    end if;
  end loop;

  insert into public.invites (household_id, code, email, expires_at, created_by)
  values (
    target_household,
    new_code,
    nullif(trim(invite_email), ''),
    now() + interval '14 days',
    (select auth.uid())
  );

  return new_code;
end;
$$;

revoke execute on function public.create_invite(uuid, text) from public;
grant execute on function public.create_invite(uuid, text) to authenticated;

create function public.join_household_with_code(invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  invite public.invites;
  caller uuid := (select auth.uid());
begin
  if caller is null then
    raise exception 'authentication required';
  end if;

  select * into invite
  from public.invites
  where code = upper(trim(invite_code))
  for update;

  if invite is null then
    raise exception 'invalid invite code' using errcode = 'P0002';
  end if;
  if invite.expires_at < now() then
    raise exception 'invite code has expired' using errcode = 'P0003';
  end if;
  if invite.redeemed_at is not null then
    raise exception 'invite code has already been used' using errcode = 'P0004';
  end if;

  insert into public.household_members (household_id, user_id, role)
  values (invite.household_id, caller, 'member')
  on conflict (household_id, user_id) do nothing;

  update public.invites
  set redeemed_at = now(), redeemed_by = caller
  where id = invite.id;

  return invite.household_id;
end;
$$;

revoke execute on function public.join_household_with_code(text) from public;
grant execute on function public.join_household_with_code(text) to authenticated;
