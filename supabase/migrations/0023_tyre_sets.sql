-- Tyre sets a household owns, tracked in their own right.
--
-- A seasonal swap moves a whole set on and off the car, and each set wears on
-- its own schedule: "Set A – studded, 6 mm, in the cellar" is a different
-- object from the vehicle it spends half the year on. Modelling it as a
-- service entry would lose that — the set outlives any one fitting, and its
-- tread history is a series across many.
create table public.tyre_sets (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  -- Language-neutral, localized client-side.
  season text not null default 'all_season'
    check (season in ('summer', 'winter', 'all_season')),
  size text,
  storage_location text,
  -- Fitted to the car right now, or in storage. Exactly one set per vehicle
  /* can be fitted; enforced by the partial unique index below. */
  fitted boolean not null default false,
  fitted_at date,
  retired_at date,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create index tyre_sets_vehicle_idx on public.tyre_sets (vehicle_id);

create unique index tyre_sets_one_fitted_per_vehicle
  on public.tyre_sets (vehicle_id)
  where fitted;

alter table public.tyre_sets enable row level security;

create policy tyre_sets_select on public.tyre_sets
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy tyre_sets_insert on public.tyre_sets
  for insert to authenticated
  with check (
    vehicle_id in (select public.user_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy tyre_sets_update on public.tyre_sets
  for update to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()))
  with check (vehicle_id in (select public.user_vehicle_ids()));

create policy tyre_sets_delete on public.tyre_sets
  for delete to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

grant select, insert, update, delete on public.tyre_sets to authenticated;

alter publication supabase_realtime add table public.tyre_sets;

-- Tread readings belong to the set, not to the visit: a set measured in the
-- garage in March and at a shop in October has one series across both.
create table public.tyre_readings (
  id uuid primary key default gen_random_uuid(),
  tyre_set_id uuid not null references public.tyre_sets (id) on delete cascade,
  reading_date date not null,
  odometer_km int check (odometer_km >= 0),
  -- Per corner, in millimetres. Nullable: a household that measures one corner
  -- has still recorded something worth keeping.
  front_left_mm numeric(4, 1) check (front_left_mm >= 0),
  front_right_mm numeric(4, 1) check (front_right_mm >= 0),
  rear_left_mm numeric(4, 1) check (rear_left_mm >= 0),
  rear_right_mm numeric(4, 1) check (rear_right_mm >= 0),
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create index tyre_readings_set_idx
  on public.tyre_readings (tyre_set_id, reading_date desc);

alter table public.tyre_readings enable row level security;

create policy tyre_readings_select on public.tyre_readings
  for select to authenticated
  using (
    tyre_set_id in (
      select id from public.tyre_sets
      where vehicle_id in (select public.user_vehicle_ids())
    )
  );

create policy tyre_readings_insert on public.tyre_readings
  for insert to authenticated
  with check (
    tyre_set_id in (
      select id from public.tyre_sets
      where vehicle_id in (select public.user_vehicle_ids())
    )
    and created_by = (select auth.uid())
  );

create policy tyre_readings_delete on public.tyre_readings
  for delete to authenticated
  using (
    tyre_set_id in (
      select id from public.tyre_sets
      where vehicle_id in (select public.user_vehicle_ids())
    )
  );

grant select, insert, delete on public.tyre_readings to authenticated;
