-- Households are the tenancy boundary: every row of user data in this schema
-- belongs to exactly one household, and every RLS policy reduces to asking
-- whether the caller is a member of it.

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 80),
  currency_code text not null default 'EUR' check (char_length(currency_code) = 3),
  distance_unit text not null default 'km' check (distance_unit in ('km', 'mi')),
  volume_unit text not null default 'liter'
    check (volume_unit in ('liter', 'us_gallon', 'uk_gallon')),
  bundling_window_days int not null default 21 check (bundling_window_days between 0 and 365),
  bundling_window_km int not null default 500 check (bundling_window_km between 0 and 100000),
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 60),
  created_at timestamptz not null default now()
);

-- The role column is unused by the v1 UI, where all members are equal. It
-- exists so a permission model can be added later without a migration.
create table public.household_members (
  household_id uuid not null references public.households (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id)
);

create index household_members_user_idx on public.household_members (user_id);

-- Membership lookup for every policy in the schema.
--
-- SECURITY DEFINER is load-bearing, not a shortcut: the policy on
-- household_members needs to read household_members, and a plain subquery
-- would re-enter that same policy and recurse infinitely. Running as the
-- definer bypasses RLS for this one narrow, parameterless read.
create function public.user_household_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select household_id
  from public.household_members
  where user_id = (select auth.uid())
$$;

revoke execute on function public.user_household_ids() from public;
grant execute on function public.user_household_ids() to authenticated;

-- Creating a household means inserting two rows that must both exist or
-- neither: without the membership row the creator is locked out of the
-- household they just made. Doing it in one definer function keeps it atomic
-- and means no broad insert grant on household_members is needed.
create function public.create_household(household_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
  caller uuid := (select auth.uid());
begin
  if caller is null then
    raise exception 'authentication required';
  end if;

  insert into public.households (name, created_by)
  values (household_name, caller)
  returning id into new_id;

  insert into public.household_members (household_id, user_id, role)
  values (new_id, caller, 'admin');

  return new_id;
end;
$$;

revoke execute on function public.create_household(text) from public;
grant execute on function public.create_household(text) to authenticated;

-- A household with no members is unreachable data. Clean it up rather than
-- letting it linger as an orphan the user can never delete.
create function public.delete_empty_household()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.household_members
    where household_id = old.household_id
  ) then
    delete from public.households where id = old.household_id;
  end if;
  return old;
end;
$$;

create trigger household_members_cleanup
after delete on public.household_members
for each row execute function public.delete_empty_household();

-- Give every new auth user a profile so the app never has to handle a
-- signed-in user without one.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id, display_name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      split_part(new.email, '@', 1)
    )
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.households enable row level security;
alter table public.profiles enable row level security;
alter table public.household_members enable row level security;

create policy households_select on public.households
  for select to authenticated
  using (id in (select public.user_household_ids()));

create policy households_update on public.households
  for update to authenticated
  using (id in (select public.user_household_ids()))
  with check (id in (select public.user_household_ids()));

create policy households_delete on public.households
  for delete to authenticated
  using (
    exists (
      select 1 from public.household_members
      where household_id = households.id
        and user_id = (select auth.uid())
        and role = 'admin'
    )
  );

-- Members can see each other, so entries can be attributed by name.
create policy members_select on public.household_members
  for select to authenticated
  using (household_id in (select public.user_household_ids()));

-- Leaving a household is allowed; removing someone else is not, in v1.
create policy members_delete_self on public.household_members
  for delete to authenticated
  using (user_id = (select auth.uid()));

create policy profiles_select on public.profiles
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1 from public.household_members
      where user_id = profiles.user_id
        and household_id in (select public.user_household_ids())
    )
  );

create policy profiles_update on public.profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
