create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  nickname text not null check (char_length(trim(nickname)) between 1 and 60),
  fuel_type_key text not null default 'fuel_petrol',
  make text,
  model text,
  year int check (year between 1900 and 2100),
  trim text,
  vin text check (vin is null or char_length(vin) between 11 and 17),
  plate text,
  photo_path text,
  -- Baseline for projecting maintenance that has never been done on record.
  baseline_odometer_km int not null default 0 check (baseline_odometer_km >= 0),
  baseline_date date not null default current_date,
  archived boolean not null default false,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create index vehicles_household_idx on public.vehicles (household_id) where not archived;

create function public.user_vehicle_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select id from public.vehicles
  where household_id in (select public.user_household_ids())
$$;

revoke execute on function public.user_vehicle_ids() from public;
grant execute on function public.user_vehicle_ids() to authenticated;

alter table public.vehicles enable row level security;

create policy vehicles_select on public.vehicles
  for select to authenticated
  using (household_id in (select public.user_household_ids()));

create policy vehicles_insert on public.vehicles
  for insert to authenticated
  with check (
    household_id in (select public.user_household_ids())
    and created_by = (select auth.uid())
  );

create policy vehicles_update on public.vehicles
  for update to authenticated
  using (household_id in (select public.user_household_ids()))
  with check (household_id in (select public.user_household_ids()));

create policy vehicles_delete on public.vehicles
  for delete to authenticated
  using (household_id in (select public.user_household_ids()));

insert into storage.buckets (id, name, public)
values ('vehicle-photos', 'vehicle-photos', false)
on conflict (id) do nothing;

-- Objects are stored as {household_id}/{vehicle_id}, so the first path
-- segment is the tenancy key.
create policy vehicle_photos_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'vehicle-photos'
    and ((storage.foldername(name))[1])::uuid in (select public.user_household_ids())
  );

create policy vehicle_photos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'vehicle-photos'
    and ((storage.foldername(name))[1])::uuid in (select public.user_household_ids())
  );

create policy vehicle_photos_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'vehicle-photos'
    and ((storage.foldername(name))[1])::uuid in (select public.user_household_ids())
  );

create policy vehicle_photos_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'vehicle-photos'
    and ((storage.foldername(name))[1])::uuid in (select public.user_household_ids())
  );
