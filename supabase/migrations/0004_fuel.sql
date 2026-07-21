create table public.fuel_entries (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  entry_date date not null,
  odometer_km int not null check (odometer_km >= 0),
  volume_l numeric(10, 3) not null check (volume_l > 0),
  price_per_l numeric(10, 4) check (price_per_l >= 0),
  total numeric(12, 2) check (total >= 0),
  full_tank boolean not null default true,
  -- Set when fuel went in unlogged. The economy algorithm discards the span
  -- ending here rather than reporting an impossibly good figure.
  missed_fill boolean not null default false,
  station text,
  notes text,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

-- The economy algorithm walks entries per vehicle in odometer order.
create index fuel_entries_vehicle_odometer_idx
  on public.fuel_entries (vehicle_id, odometer_km);

alter table public.fuel_entries enable row level security;

create policy fuel_entries_select on public.fuel_entries
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy fuel_entries_insert on public.fuel_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.user_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy fuel_entries_update on public.fuel_entries
  for update to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()))
  with check (vehicle_id in (select public.user_vehicle_ids()));

create policy fuel_entries_delete on public.fuel_entries
  for delete to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));
