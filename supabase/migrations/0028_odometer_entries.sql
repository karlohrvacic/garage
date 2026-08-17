-- A reading of the odometer with no money attached.
--
-- Maintenance projection needs to know how far a car has gone, and until now
-- it could only learn that from something the owner paid for: a fill-up, a
-- service, or a cost entry that happened to carry a reading. A household that
-- services its car but pays cash at the pump had no way to record distance
-- short of inventing a fill-up, and every distance-based projection fell back
-- to an assumed rate. See docs/operations/known-bugs-and-risks.md.
create table public.odometer_entries (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  entry_date date not null,
  odometer_km int not null check (odometer_km >= 0),
  notes text,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create index odometer_entries_vehicle_date_idx
  on public.odometer_entries (vehicle_id, entry_date desc);

alter table public.odometer_entries enable row level security;

create policy odometer_entries_select on public.odometer_entries
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy odometer_entries_insert on public.odometer_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.user_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy odometer_entries_update on public.odometer_entries
  for update to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()))
  with check (vehicle_id in (select public.user_vehicle_ids()));

create policy odometer_entries_delete on public.odometer_entries
  for delete to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

grant select, insert, update, delete on public.odometer_entries to authenticated;

alter publication supabase_realtime add table public.odometer_entries;
