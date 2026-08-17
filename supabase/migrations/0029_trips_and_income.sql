-- Two entry kinds that turn a cost log into a record of what a car actually
-- did and what it was worth.
--
-- Trips are a mileage logbook: where a journey went, how far, and whether it
-- was work. The private/business split is the only reason to keep one for tax,
-- so it is a constrained column rather than a free-text tag.
--
-- Income is money in. Without it "what has this car cost me" can only ever be
-- half an answer, and the sale price — the one figure that closes the book on a
-- vehicle — has nowhere to live at all.

create table public.trip_entries (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  entry_date date not null,
  title text,
  from_place text,
  to_place text,
  -- Stored rather than derived from the odometer range: a range says what the
  -- car did between two readings, and a day of errands between two readings is
  -- several trips.
  distance_km numeric(10, 1) not null check (distance_km >= 0),
  start_odometer_km int check (start_odometer_km >= 0),
  end_odometer_km int check (end_odometer_km >= 0),
  minutes int check (minutes >= 0),
  purpose text not null default 'private' check (purpose in ('private', 'business')),
  notes text,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  -- A range that runs backwards is a typo, not a journey.
  constraint trip_odometer_order check (
    start_odometer_km is null
    or end_odometer_km is null
    or end_odometer_km >= start_odometer_km
  )
);

create index trip_entries_vehicle_date_idx
  on public.trip_entries (vehicle_id, entry_date desc);

create table public.income_entries (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  entry_date date not null,
  category text not null check (category ~ '^[a-z0-9_]+$'),
  amount numeric(12, 2) not null check (amount >= 0),
  odometer_km int check (odometer_km >= 0),
  notes text,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create index income_entries_vehicle_date_idx
  on public.income_entries (vehicle_id, entry_date desc);

alter table public.trip_entries enable row level security;
alter table public.income_entries enable row level security;

create policy trip_entries_select on public.trip_entries
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy trip_entries_insert on public.trip_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.user_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy trip_entries_update on public.trip_entries
  for update to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()))
  with check (vehicle_id in (select public.user_vehicle_ids()));

create policy trip_entries_delete on public.trip_entries
  for delete to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy income_entries_select on public.income_entries
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy income_entries_insert on public.income_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.user_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy income_entries_update on public.income_entries
  for update to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()))
  with check (vehicle_id in (select public.user_vehicle_ids()));

create policy income_entries_delete on public.income_entries
  for delete to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

grant select, insert, update, delete on public.trip_entries to authenticated;
grant select, insert, update, delete on public.income_entries to authenticated;

alter publication supabase_realtime add table public.trip_entries;
alter publication supabase_realtime add table public.income_entries;
