-- General vehicle costs beyond fuel and service: registration, insurance,
-- parking, tolls, and the like. One expense is one row; categories are fixed
-- language-neutral keys localized client-side.
create table public.cost_entries (
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

create index cost_entries_vehicle_date_idx
  on public.cost_entries (vehicle_id, entry_date desc);

alter table public.cost_entries enable row level security;

create policy cost_entries_select on public.cost_entries
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy cost_entries_insert on public.cost_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.user_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy cost_entries_update on public.cost_entries
  for update to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()))
  with check (vehicle_id in (select public.user_vehicle_ids()));

create policy cost_entries_delete on public.cost_entries
  for delete to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

grant select, insert, update, delete on public.cost_entries to authenticated;

alter publication supabase_realtime add table public.cost_entries;
