-- A journey you make over and over, so it can be compared with itself.
--
-- The question this exists for: "two years ago this commute took me 35
-- minutes, now it takes 45 — is that real?" Nothing in the app could answer
-- it. Trips carried a free-text `title`, `from_place` and `to_place`, which
-- means the same drive was recorded as "work", "Work", "to the office" and
-- "ured" and could never be grouped.
--
-- **A route is a named pair with a direction, and it holds no addresses.** Home
-- → Work and Work → Home are two rows, because they are two different drives:
-- different time of day, different traffic, often different roads. Storing
-- coordinates would add a category of personal data — where somebody lives —
-- for a feature that needs a label and nothing more.
--
-- Scoped to the household rather than the vehicle: the commute is the same
-- commute whichever car is taken, and grouping by car would split a history
-- exactly where it is most worth comparing.
create table public.routes (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index routes_household_idx on public.routes (household_id, name);

-- One name per garage. Two routes both called "Home → Work" would silently
-- split the very history the feature exists to join up.
create unique index routes_unique_name
  on public.routes (household_id, lower(name));

alter table public.trip_entries
  add column route_id uuid references public.routes (id) on delete set null;

-- The detour, the school run on the way, the day the road was shut. Excluded
-- from a trend by default and still drawn, because hiding them would let the
-- chart quietly answer a different question than the one asked.
--
-- Default true: an ordinary trip is comparable, and a person should have to
-- say when one is not rather than confirm it every time.
alter table public.trip_entries
  add column comparable boolean not null default true;

create index trip_entries_route_idx
  on public.trip_entries (route_id, entry_date desc)
  where route_id is not null;

alter table public.routes enable row level security;

create policy routes_select on public.routes
  for select to authenticated
  using (household_id in (select public.user_household_ids()));

create policy routes_insert on public.routes
  for insert to authenticated
  with check (
    household_id in (select public.user_household_ids())
    and created_by = (select auth.uid())
  );

create policy routes_update on public.routes
  for update to authenticated
  using (household_id in (select public.user_household_ids()))
  with check (household_id in (select public.user_household_ids()));

create policy routes_delete on public.routes
  for delete to authenticated
  using (household_id in (select public.user_household_ids()));

grant select, insert, update, delete on public.routes to authenticated;

create trigger routes_pin_created_by
  before update on public.routes
  for each row execute function public.pin_created_by();
