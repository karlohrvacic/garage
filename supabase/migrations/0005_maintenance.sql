-- A null household_id marks a built-in preset: world-readable, never writable
-- by users. Households may add their own rows alongside them.
create table public.service_types (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references public.households (id) on delete cascade,
  key text not null check (key ~ '^[a-z0-9_]+$'),
  default_interval_km int check (default_interval_km > 0),
  default_interval_months int check (default_interval_months > 0),
  is_statutory boolean not null default false,
  country_code text check (country_code is null or char_length(country_code) = 2),
  created_at timestamptz not null default now()
);

-- Nulls compare as distinct in a plain unique constraint, so presets need
-- their own partial index to stay unique.
create unique index service_types_preset_key_idx
  on public.service_types (key) where household_id is null;
create unique index service_types_household_key_idx
  on public.service_types (household_id, key) where household_id is not null;

create table public.reminder_rules (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  service_type_key text not null,
  interval_km int check (interval_km > 0),
  interval_months int check (interval_months > 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint reminder_rules_needs_an_interval
    check (interval_km is not null or interval_months is not null),
  unique (vehicle_id, service_type_key)
);

create index reminder_rules_vehicle_idx
  on public.reminder_rules (vehicle_id) where active;

-- One shop visit is one row. A visit that covered several items — a completed
-- bundle — carries several keys in service_type_keys.
create table public.service_entries (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  entry_date date not null,
  odometer_km int not null check (odometer_km >= 0),
  service_type_keys text[] not null check (cardinality(service_type_keys) > 0),
  cost numeric(12, 2) check (cost >= 0),
  shop text,
  notes text,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create index service_entries_vehicle_date_idx
  on public.service_entries (vehicle_id, entry_date desc);
create index service_entries_keys_idx
  on public.service_entries using gin (service_type_keys);

alter table public.service_types enable row level security;
alter table public.reminder_rules enable row level security;
alter table public.service_entries enable row level security;

create policy service_types_select on public.service_types
  for select to authenticated
  using (
    household_id is null
    or household_id in (select public.user_household_ids())
  );

-- Presets are read-only: household_id must be a household the caller belongs
-- to, which a null can never satisfy.
create policy service_types_insert on public.service_types
  for insert to authenticated
  with check (household_id in (select public.user_household_ids()));

create policy service_types_update on public.service_types
  for update to authenticated
  using (household_id in (select public.user_household_ids()))
  with check (household_id in (select public.user_household_ids()));

create policy service_types_delete on public.service_types
  for delete to authenticated
  using (household_id in (select public.user_household_ids()));

create policy reminder_rules_select on public.reminder_rules
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy reminder_rules_insert on public.reminder_rules
  for insert to authenticated
  with check (vehicle_id in (select public.user_vehicle_ids()));

create policy reminder_rules_update on public.reminder_rules
  for update to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()))
  with check (vehicle_id in (select public.user_vehicle_ids()));

create policy reminder_rules_delete on public.reminder_rules
  for delete to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy service_entries_select on public.service_entries
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy service_entries_insert on public.service_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.user_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy service_entries_update on public.service_entries
  for update to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()))
  with check (vehicle_id in (select public.user_vehicle_ids()));

create policy service_entries_delete on public.service_entries
  for delete to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

-- Built-in presets. Intervals are generic starting points the user is expected
-- to override per vehicle: there is no affordable EU-wide source of
-- manufacturer schedules, so these are deliberately conservative defaults
-- rather than claims about any specific model.
insert into public.service_types
  (household_id, key, default_interval_km, default_interval_months, is_statutory, country_code)
values
  (null, 'service_oil_change',        15000, 12,  false, null),
  (null, 'service_oil_filter',        15000, 12,  false, null),
  (null, 'service_air_filter',        30000, 24,  false, null),
  (null, 'service_cabin_filter',      15000, 12,  false, null),
  (null, 'service_spark_plugs',       60000, 48,  false, null),
  (null, 'service_brake_fluid',       null,  24,  false, null),
  (null, 'service_brake_pads_front',  40000, null, false, null),
  (null, 'service_brake_pads_rear',   60000, null, false, null),
  (null, 'service_timing_belt',      120000, 72,  false, null),
  (null, 'service_coolant',          null,   48,  false, null),
  (null, 'service_transmission_oil',  60000, 48,  false, null),
  (null, 'service_tire_rotation',     10000, 12,  false, null),
  (null, 'service_tire_swap_seasonal', null,  6,  false, null),
  (null, 'service_battery',          null,   48,  false, null),
  (null, 'service_wipers',           null,   12,  false, null),
  -- Croatia statutory items. Verified for the Croatian market only; other
  -- countries get their own rows opportunistically as users from those
  -- markets appear, rather than shipping an unverified library up front.
  (null, 'service_registration',     null,   12,  true,  'HR'),
  (null, 'service_technical_inspection', null, 12, true, 'HR'),
  (null, 'service_insurance',        null,   12,  true,  'HR');
