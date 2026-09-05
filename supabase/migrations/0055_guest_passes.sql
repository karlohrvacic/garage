-- Lending a car, and renting one out.
--
-- Until now there was exactly one way to let somebody at a vehicle: make them a
-- member of the garage. That is right for the people you share a car *with* and
-- wrong for everybody else — lending the Golf to a friend for a week meant
-- handing over every car, every cost and every document, permanently.
--
-- A guest pass is narrower and temporary: **this car, for this long, and only
-- these actions.** It serves a friend borrowing a car and a rental company
-- handing over keys with the same mechanism.
--
-- **Every policy below is additive.** Postgres combines permissive policies with
-- OR, so a new policy can only widen access for the rows it names, and the
-- member policies keep behaving exactly as their tests already assert. Teaching
-- `user_vehicle_ids()` about guests instead would have been fewer lines and
-- would have silently given every guest everything a member has.

create table public.vehicle_guest_passes (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  code text not null unique,
  -- "Ivan", or a rental booking reference. For the owner's own recognition;
  -- the holder never sees it.
  label text check (label is null or char_length(label) <= 80),
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  -- Null means usable the moment it is handed over. A rental booked for next
  -- Tuesday sets it.
  starts_at timestamptz,
  expires_at timestamptz not null,
  -- The owner changed their mind. Distinct from expiry so the record says
  -- which of the two happened.
  revoked_at timestamptz,
  redeemed_by uuid references auth.users (id),
  redeemed_at timestamptz,
  -- Independent switches rather than a role ladder: the interesting
  -- combinations are not ordered. A rental company wants fuel and trips but
  -- not service entries; somebody lending a car for a track day wants the
  -- opposite.
  can_log_fuel boolean not null default true,
  can_log_trips boolean not null default true,
  can_log_costs boolean not null default true,
  -- Off by default: a guest sees what they wrote and nothing earlier. The
  -- screen has to explain that, or an almost-empty fuel log reads as broken
  -- rather than as private.
  can_view_history boolean not null default false,
  constraint guest_pass_window check (
    starts_at is null or starts_at < expires_at
  ),
  constraint guest_pass_redeemed_together check (
    (redeemed_by is null) = (redeemed_at is null)
  )
);

create index vehicle_guest_passes_vehicle_idx
  on public.vehicle_guest_passes (vehicle_id, expires_at desc);

create index vehicle_guest_passes_redeemed_idx
  on public.vehicle_guest_passes (redeemed_by)
  where redeemed_by is not null;

-- The vehicles a guest may act on right now, for one permission.
--
-- Expiry needs no scheduled job: the clock is tested here, so a lapsed pass
-- simply stops granting anything. Nothing is deleted, which is what makes
-- "everything they logged stays" true by default rather than by effort.
create function public.guest_vehicle_ids(permission text)
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select vehicle_id from public.vehicle_guest_passes
  where redeemed_by = (select auth.uid())
    and revoked_at is null
    and now() < expires_at
    and (starts_at is null or now() >= starts_at)
    and case permission
      when 'fuel' then can_log_fuel
      when 'trips' then can_log_trips
      when 'costs' then can_log_costs
      when 'history' then can_view_history
      -- 'vehicle' is the bare fact of the car existing: a guest has to see the
      -- thing they are logging against whatever else the pass allows.
      when 'vehicle' then true
      else false
    end
$$;

revoke execute on function public.guest_vehicle_ids(text) from public;
grant execute on function public.guest_vehicle_ids(text) to authenticated;

alter table public.vehicle_guest_passes enable row level security;

-- The owner's side: members of the garage the car belongs to manage its passes.
create policy vehicle_guest_passes_select on public.vehicle_guest_passes
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy vehicle_guest_passes_update on public.vehicle_guest_passes
  for update to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()))
  with check (vehicle_id in (select public.user_vehicle_ids()));

create policy vehicle_guest_passes_delete on public.vehicle_guest_passes
  for delete to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

-- No insert policy on purpose. A pass is minted through `create_guest_pass`,
-- which allocates the code; an insert that chose its own code could pick one
-- somebody is already holding.

-- The holder's side: a guest may read the pass they themselves redeemed, so the
-- app can show what it allows and when it runs out.
create policy vehicle_guest_passes_select_own on public.vehicle_guest_passes
  for select to authenticated
  using (redeemed_by = (select auth.uid()));

create function public.create_guest_pass(
  target_vehicle uuid,
  valid_days int default 7,
  pass_label text default null,
  starts_on timestamptz default null,
  allow_fuel boolean default true,
  allow_trips boolean default true,
  allow_costs boolean default true,
  allow_history boolean default false
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
  attempts int := 0;
begin
  if target_vehicle not in (select public.user_vehicle_ids()) then
    raise exception 'not a member of the garage this vehicle belongs to';
  end if;

  if valid_days < 1 or valid_days > 365 then
    raise exception 'a pass lasts between a day and a year';
  end if;

  loop
    new_code := public.generate_invite_code();
    exit when not exists (
      select 1 from public.vehicle_guest_passes where code = new_code
    );
    attempts := attempts + 1;
    if attempts > 10 then
      raise exception 'could not allocate a guest code';
    end if;
  end loop;

  insert into public.vehicle_guest_passes (
    vehicle_id, code, label, created_by, starts_at, expires_at,
    can_log_fuel, can_log_trips, can_log_costs, can_view_history
  )
  values (
    target_vehicle,
    new_code,
    nullif(trim(pass_label), ''),
    (select auth.uid()),
    starts_on,
    coalesce(starts_on, now()) + make_interval(days => valid_days),
    allow_fuel, allow_trips, allow_costs, allow_history
  );

  return new_code;
end;
$$;

revoke execute on function public.create_guest_pass(
  uuid, int, text, timestamptz, boolean, boolean, boolean, boolean
) from public;
grant execute on function public.create_guest_pass(
  uuid, int, text, timestamptz, boolean, boolean, boolean, boolean
) to authenticated;

-- Claiming a pass. Returns the vehicle it opens.
create function public.redeem_guest_pass(pass_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  pass public.vehicle_guest_passes;
begin
  select * into pass from public.vehicle_guest_passes
  where code = upper(trim(pass_code));

  if pass.id is null then
    raise exception 'no such code';
  end if;
  if pass.revoked_at is not null then
    raise exception 'that code has been withdrawn';
  end if;
  if now() >= pass.expires_at then
    raise exception 'that code has expired';
  end if;
  -- Re-redeeming your own pass is how the app recovers after a reinstall, and
  -- must not be an error. Somebody else's redeemed pass is refused: a pass is
  -- for one holder, unlike a household invite.
  if pass.redeemed_by is not null and pass.redeemed_by <> (select auth.uid())
  then
    raise exception 'that code is already in use';
  end if;

  -- A member of the garage gains nothing from a pass and would end up with two
  -- overlapping grants on the same car, which is a question nobody should have
  -- to answer later.
  if pass.vehicle_id in (select public.user_vehicle_ids()) then
    raise exception 'you are already in the garage this vehicle belongs to';
  end if;

  update public.vehicle_guest_passes
  set redeemed_by = (select auth.uid()), redeemed_at = coalesce(redeemed_at, now())
  where id = pass.id;

  return pass.vehicle_id;
end;
$$;

revoke execute on function public.redeem_guest_pass(text) from public;
grant execute on function public.redeem_guest_pass(text) to authenticated;

-- The car itself. A guest has to see what they are logging against.
create policy vehicles_select_guest on public.vehicles
  for select to authenticated
  using (id in (select public.guest_vehicle_ids('vehicle')));

-- Logging. Insert is gated on the permission; select, update and delete are
-- additionally gated on authorship, so a guest never reads or edits a row
-- somebody else wrote unless the pass says they may see history.
create policy fuel_entries_insert_guest on public.fuel_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.guest_vehicle_ids('fuel'))
    and created_by = (select auth.uid())
  );

create policy fuel_entries_select_guest on public.fuel_entries
  for select to authenticated
  using (
    (vehicle_id in (select public.guest_vehicle_ids('fuel'))
      and created_by = (select auth.uid()))
    or vehicle_id in (select public.guest_vehicle_ids('history'))
  );

create policy fuel_entries_update_guest on public.fuel_entries
  for update to authenticated
  using (
    vehicle_id in (select public.guest_vehicle_ids('fuel'))
    and created_by = (select auth.uid())
  )
  with check (
    vehicle_id in (select public.guest_vehicle_ids('fuel'))
    and created_by = (select auth.uid())
  );

create policy fuel_entries_delete_guest on public.fuel_entries
  for delete to authenticated
  using (
    vehicle_id in (select public.guest_vehicle_ids('fuel'))
    and created_by = (select auth.uid())
  );

create policy trip_entries_insert_guest on public.trip_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.guest_vehicle_ids('trips'))
    and created_by = (select auth.uid())
  );

create policy trip_entries_select_guest on public.trip_entries
  for select to authenticated
  using (
    (vehicle_id in (select public.guest_vehicle_ids('trips'))
      and created_by = (select auth.uid()))
    or vehicle_id in (select public.guest_vehicle_ids('history'))
  );

create policy trip_entries_update_guest on public.trip_entries
  for update to authenticated
  using (
    vehicle_id in (select public.guest_vehicle_ids('trips'))
    and created_by = (select auth.uid())
  )
  with check (
    vehicle_id in (select public.guest_vehicle_ids('trips'))
    and created_by = (select auth.uid())
  );

create policy trip_entries_delete_guest on public.trip_entries
  for delete to authenticated
  using (
    vehicle_id in (select public.guest_vehicle_ids('trips'))
    and created_by = (select auth.uid())
  );

create policy cost_entries_insert_guest on public.cost_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.guest_vehicle_ids('costs'))
    and created_by = (select auth.uid())
  );

create policy cost_entries_select_guest on public.cost_entries
  for select to authenticated
  using (
    (vehicle_id in (select public.guest_vehicle_ids('costs'))
      and created_by = (select auth.uid()))
    or vehicle_id in (select public.guest_vehicle_ids('history'))
  );

create policy cost_entries_update_guest on public.cost_entries
  for update to authenticated
  using (
    vehicle_id in (select public.guest_vehicle_ids('costs'))
    and created_by = (select auth.uid())
  )
  with check (
    vehicle_id in (select public.guest_vehicle_ids('costs'))
    and created_by = (select auth.uid())
  );

create policy cost_entries_delete_guest on public.cost_entries
  for delete to authenticated
  using (
    vehicle_id in (select public.guest_vehicle_ids('costs'))
    and created_by = (select auth.uid())
  );

create policy service_entries_insert_guest on public.service_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.guest_vehicle_ids('costs'))
    and created_by = (select auth.uid())
  );

create policy service_entries_select_guest on public.service_entries
  for select to authenticated
  using (
    (vehicle_id in (select public.guest_vehicle_ids('costs'))
      and created_by = (select auth.uid()))
    or vehicle_id in (select public.guest_vehicle_ids('history'))
  );
