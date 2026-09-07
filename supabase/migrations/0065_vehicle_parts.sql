-- What this car takes: the numbers a DIY owner looks up before every job.
--
-- Oil viscosity and spec, a filter's part number, a bulb type, wiper lengths,
-- the battery. Roadmap item 12 asked for a curated database of these keyed by
-- make, model and engine; there is no free authoritative source, and a wrong
-- part number costs more than no part number. So this is the half that needs
-- no data at all: the household looks it up **once**, and the app is what
-- remembers.
--
-- Keyed by `service_type_key`, the vocabulary the app already uses for
-- reminders and service entries, so "oil change" on the service sheet can show
-- what the car takes without a second mapping to keep in step. A key the app
-- does not know is kept rather than rejected, the way every other stored key in
-- this schema behaves.
create table public.vehicle_parts (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  service_type_key text not null check (service_type_key ~ '^[a-z0-9_]+$'),
  -- "5W-30 ACEA C3", "W 712/95", "H7 55W", "600 mm / 400 mm". Free text on
  -- purpose: a spec, a part number and a size are three different shapes and
  -- the owner is copying whichever one their car's book gives them.
  spec text not null check (
    char_length(trim(spec)) > 0 and char_length(spec) <= 200
  ),
  notes text check (notes is null or char_length(notes) <= 500),
  -- Nullable, and cleared when the author's account goes: what a car takes
  -- is a fact about the car, and outlives whoever looked it up (the same
  -- rule as every entry table since account deletion was built).
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  -- One answer per job per car. A second viscosity for the same engine is a
  -- correction, not a new fact, and two rows would leave the service sheet
  -- choosing between them.
  constraint vehicle_parts_one_per_job unique (vehicle_id, service_type_key)
);

create index vehicle_parts_vehicle_idx
  on public.vehicle_parts (vehicle_id);

alter table public.vehicle_parts enable row level security;

create policy vehicle_parts_select on public.vehicle_parts
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy vehicle_parts_insert on public.vehicle_parts
  for insert to authenticated
  with check (
    vehicle_id in (select public.user_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy vehicle_parts_update on public.vehicle_parts
  for update to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()))
  with check (vehicle_id in (select public.user_vehicle_ids()));

create policy vehicle_parts_delete on public.vehicle_parts
  for delete to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

-- A guest may read them: somebody holding the car for the weekend, or a
-- mechanic given a pass, is exactly who needs to know what fits it. Additive,
-- like every other guest policy — never by widening `user_vehicle_ids`.
create policy vehicle_parts_select_guest on public.vehicle_parts
  for select to authenticated
  using (
    vehicle_id in (select public.guest_vehicle_ids('vehicle'))
  );
