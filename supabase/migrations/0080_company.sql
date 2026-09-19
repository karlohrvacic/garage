-- 0080: the company module, stage 1.
--
-- The app keeps everything per car for a household of equals. A company is
-- the layer above the car: who is responsible for it, who may see it, what
-- the administrator does on somebody's behalf, and what leaves for the
-- accountant. This migration adds the role, the plan, the assignment log,
-- incidents, the payment method, and a queue for "remind the driver".
--
-- **Every driver policy below is additive**, as every guest policy in 0055
-- is. Postgres OR-combines permissive policies, so a new policy can only
-- widen access for the rows it names. What changes for members is one
-- function, `user_household_ids()`, which now leaves out a membership whose
-- role is `driver`: every member policy reads it, directly or through
-- `user_vehicle_ids()`, and narrowing it removes rows and never adds them.
-- Teaching it about assignments instead would have handed every driver
-- everything a member has. See decision 184.

create extension if not exists btree_gist with schema extensions;

-- Roles ----------------------------------------------------------------------

-- The check constraint was written inline in 0001 and got the name Postgres
-- gives one.
alter table public.household_members
  drop constraint household_members_role_check;
alter table public.household_members
  add constraint household_members_role_check
  check (role in ('admin', 'member', 'driver'));

-- The plan -------------------------------------------------------------------

alter table public.households
  add column plan text not null default 'free'
    check (plan in ('free', 'company')),
  add column plan_until timestamptz,
  add column company_name text
    check (company_name is null or char_length(company_name) <= 120),
  add column company_oib text
    check (company_oib is null or company_oib ~ '^[0-9]{11}$'),
  add column company_address text
    check (company_address is null or char_length(company_address) <= 200);

comment on column public.households.plan_until is
  'Null on the company plan means no end. Past means lapsed: every row and '
  'every screen stays, and only adding a car above the free cap, making a '
  'driver and assigning wait for the plan.';

-- Nobody puts their own garage on the plan through the API. A column
-- privilege rather than a trigger, so that the service role — which is what
-- billing will use — keeps its table-level update: a trigger would have to
-- tell the two apart by role name, and a column list does not. Revoking a
-- column from a role that holds the table-level privilege does nothing, so
-- the table-level grant goes and the columns settings may change come back.
revoke update on public.households from authenticated;
grant update (
  name, currency_code, distance_unit, volume_unit, bundling_window_days,
  bundling_window_km, tracking_level, country_code, settlement_enabled,
  company_name, company_oib, company_address
) on public.households to authenticated;

-- The letterhead is the garage's identity the way its name is (0036): what
-- the accountant pack prints in its header is not one member's preference.
-- The same trigger, three more columns, and the same shape of check — a
-- member's update that carries the letterhead unchanged still lands, since
-- the settings row always carries every column.
create or replace function public.enforce_household_rename_is_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (
    new.name is distinct from old.name
    or new.company_name is distinct from old.company_name
    or new.company_oib is distinct from old.company_oib
    or new.company_address is distinct from old.company_address
  ) and not public.is_household_admin(old.id) then
    raise exception 'only an admin may rename a garage or its letterhead'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke execute on function public.enforce_household_rename_is_admin()
  from public, anon, authenticated;

-- How many cars a free garage holds. A function rather than a constant in
-- three policies, and immutable so a policy may call it.
create function public.free_vehicle_limit()
returns int
language sql
immutable
set search_path = public
as $$
  select 5
$$;

revoke execute on function public.free_vehicle_limit() from public;
grant execute on function public.free_vehicle_limit() to authenticated;

-- Definer, so a policy can ask about a garage whose row the caller may not
-- read: a driver's policies never need this, but a member's insert on
-- vehicles is evaluated before any row exists to read.
create function public.company_enabled(target_household uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.households
    where id = target_household
      and plan = 'company'
      and (plan_until is null or plan_until > now())
  )
$$;

revoke execute on function public.company_enabled(uuid) from public;
grant execute on function public.company_enabled(uuid) to authenticated;

-- Archived cars do not count: a family that sold two cars and archived them
-- has three in the garage, not five, and their history is the reason they
-- were archived rather than deleted.
create function public.can_add_vehicle(target_household uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.company_enabled(target_household)
    or (
      select count(*) from public.vehicles
      where household_id = target_household and not archived
    ) < public.free_vehicle_limit()
$$;

revoke execute on function public.can_add_vehicle(uuid) from public;
grant execute on function public.can_add_vehicle(uuid) to authenticated;

drop policy vehicles_insert on public.vehicles;

create policy vehicles_insert on public.vehicles
  for insert to authenticated
  with check (
    household_id in (select public.user_household_ids())
    and created_by = (select auth.uid())
    and public.can_add_vehicle(household_id)
  );

-- The cap gates every way a car becomes active, not only the insert: an
-- archived car coming back, a car sold into the garage, and a merge. This
-- one is a trigger rather than a clause on the update policy because a
-- policy's `with check` sees only the new row: "archived went from true to
-- false" needs both, and a check on the new row alone would refuse every
-- edit of an active car in a garage already over the cap, which a lapsed
-- garage with twelve cars is and must keep editing.
create function public.guard_vehicle_unarchive()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.archived and not new.archived
     and not public.can_add_vehicle(new.household_id) then
    raise exception 'the garage has reached its free limit'
      using errcode = 'P0008';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_vehicle_unarchive()
  from public, anon, authenticated;

create trigger vehicles_guard_unarchive
  before update of archived on public.vehicles
  for each row execute function public.guard_vehicle_unarchive();

-- The insert says the cap by name too. The policy clause above still refuses
-- a sixth car, but a policy can only answer 42501, and the app has paths that
-- never ask `can_add_vehicle` first — a restore, a Fuelio import, the new-car
-- form reached by URL — where "you do not have access" is the wrong sentence.
-- A BEFORE trigger runs ahead of the policy's `with check`, so every path
-- gets P0008 and the app's own words for it.
create function public.guard_vehicle_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.can_add_vehicle(new.household_id) then
    raise exception 'the garage has reached its free limit'
      using errcode = 'P0008';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_vehicle_insert()
  from public, anon, authenticated;

create trigger vehicles_guard_insert
  before insert on public.vehicles
  for each row execute function public.guard_vehicle_insert();

-- A sale into a free garage that is full waits at the door. The body is
-- 0079's, word for word, with one check added after the ones that name the
-- code and the car: a refused sale must leave the offer where it was.
create or replace function public.redeem_vehicle_transfer(
  transfer_code text,
  target_household uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  transfer public.vehicle_transfers;
  caller uuid := (select auth.uid());
  car public.vehicles;
begin
  if caller is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  if target_household not in (select public.user_household_ids()) then
    raise exception 'not a member of this household' using errcode = '42501';
  end if;

  select * into transfer
  from public.vehicle_transfers
  where code = upper(trim(transfer_code))
  for update;

  if transfer.id is null then
    raise exception 'unknown transfer code' using errcode = 'P0002';
  end if;

  if transfer.redeemed_at is not null then
    raise exception 'transfer code already used' using errcode = 'P0004';
  end if;

  if transfer.expires_at <= now() then
    raise exception 'transfer code expired' using errcode = 'P0003';
  end if;

  -- The car is locked here rather than by the update that moves it, because
  -- the passes are now withdrawn before the move. 0074's guarantee is that a
  -- mint under way holds a share lock on the car and the sale waits for it,
  -- so that the withdrawal sees the pass; with the withdrawal first, a lock
  -- taken only by the move would let a pass minted during the sale outlive
  -- it again. No key update, the lock an update takes, so an entry's
  -- foreign-key check on the car does not queue behind a sale.
  select * into car
  from public.vehicles
  where id = transfer.vehicle_id
    and household_id = transfer.from_household_id
  for no key update;
  if car.id is null then
    raise exception 'transfer code is no longer valid' using errcode = 'P0002';
  end if;

  if target_household = transfer.from_household_id then
    raise exception 'the vehicle is already in this household' using errcode = 'P0005';
  end if;

  -- The car arrives active, whatever it was before, so it counts against the
  -- buyer's cap. Refused before anything is withdrawn or announced.
  if not public.can_add_vehicle(target_household) then
    raise exception 'the garage has reached its free limit'
      using errcode = 'P0008';
  end if;

  -- The seller's loans end with the seller's ownership. Passes already over
  -- are left as they are, so the record still says how each one ended.
  -- Withdrawn before the car moves: the pass trigger announces each one as
  -- vehicle.returned to the garage the car is in at that moment, and that
  -- has to be the seller's, whose hooks knew the loan.
  update public.vehicle_guest_passes
  set revoked_at = now()
  where vehicle_id = transfer.vehicle_id
    and revoked_at is null
    and returned_at is null
    and expires_at > now();

  -- So does the seller's driver. Every window that still reaches today,
  -- open or closed, is cut on the day before the sale, the way a handover
  -- closes one, so driver_on() never names the seller's driver to the
  -- buyer; a window that opens today or later never covered a day and is
  -- deleted rather than closed on a day before it began. The delete goes
  -- first: the car is not locked against a handover, and a backdated one
  -- committing between the two statements has to be closed, not lost.
  delete from public.vehicle_assignments
  where vehicle_id = transfer.vehicle_id
    and from_date >= current_date;
  update public.vehicle_assignments
  set to_date = current_date - 1
  where vehicle_id = transfer.vehicle_id
    and from_date < current_date
    and (to_date is null or to_date >= current_date);

  -- Announced after the loans end and before the car moves, so the seller's
  -- receiver reads the sale in the order it happened: returned, then handed
  -- over. `car` is the row as it was before the move, which is the car the
  -- seller's hooks knew.
  perform public.enqueue_webhook_event(
    transfer.from_household_id,
    'vehicle.handed_over',
    jsonb_build_object(
      'vehicle_id', car.id,
      'record', to_jsonb(car),
      'to_household_id', target_household
    )
  );

  update public.vehicles
  set household_id = target_household,
      -- The photo lives under the old household's storage prefix and cannot
      -- follow. Left behind rather than pointing at a file the new owner
      -- cannot read.
      photo_path = null,
      archived = false
  where id = transfer.vehicle_id;

  update public.vehicle_transfers
  set redeemed_at = now(), redeemed_by = caller
  where id = transfer.id;

  -- Any other outstanding offer for this vehicle is now meaningless.
  delete from public.vehicle_transfers
  where vehicle_id = transfer.vehicle_id
    and id <> transfer.id
    and redeemed_at is null;

  return transfer.vehicle_id;
end;
$$;

revoke execute on function public.redeem_vehicle_transfer(text, uuid) from public, anon;
grant execute on function public.redeem_vehicle_transfer(text, uuid) to authenticated;

-- A merge whose survivor is free and would end up over the cap is refused,
-- like a merge across currencies. The body is 0071's, word for word, with
-- that one check added beside the currency check.
create or replace function public.merge_households(
  absorbed_household uuid,
  surviving_household uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := (select auth.uid());
  absorbed public.households;
  surviving public.households;
  vehicles_moved int;
  members_moved int;
  keys_revoked int;
begin
  if caller is null then
    raise exception 'authentication required';
  end if;

  if absorbed_household = surviving_household then
    raise exception 'a garage cannot be merged into itself';
  end if;

  -- Admin of both. The strictest rule that still lets the case happen, and the
  -- easiest to explain: a merge is irreversible and takes every vehicle and
  -- every entry with it, so being merely a member of the garage being
  -- dissolved is not enough.
  if not public.is_household_admin(absorbed_household)
    or not public.is_household_admin(surviving_household) then
    raise exception 'you must be an admin of both garages';
  end if;

  select * into absorbed from public.households
  where id = absorbed_household for update;
  select * into surviving from public.households
  where id = surviving_household for update;

  if absorbed.id is null or surviving.id is null then
    raise exception 'no such garage';
  end if;

  -- Money is stored as a bare number; the currency lives on the garage. Merging
  -- across currencies would silently reinterpret every amount in the absorbed
  -- garage's history — a 12,000 HRK repair reading as €12,000. Distances and
  -- volumes are safe, because those are stored canonical.
  --
  -- Refused rather than converted: one rate applied across years of history is
  -- wrong in a quieter way than refusing is.
  if absorbed.currency_code <> surviving.currency_code then
    raise exception 'the two garages keep their money in different currencies (% and %)',
      absorbed.currency_code, surviving.currency_code;
  end if;

  -- Every active car of both garages ends up in the survivor, so that is the
  -- number the free cap is held against. Archived ones do not count, as they
  -- do not for an insert.
  if not public.company_enabled(surviving_household) and (
    select count(*) from public.vehicles
    where household_id in (absorbed_household, surviving_household)
      and not archived
  ) > public.free_vehicle_limit() then
    raise exception 'the garage has reached its free limit'
      using errcode = 'P0008';
  end if;

  -- Vehicles first, and everything keyed to a vehicle comes with them: fuel,
  -- services, costs, income, trips, odometer readings, tyre sets, documents,
  -- reminder rules, attachments and any guest pass already handed out.
  update public.vehicles
  set household_id = surviving_household
  where household_id = absorbed_household;
  get diagnostics vehicles_moved = row_count;

  -- The people, keeping the role they had. Without this their names stop
  -- resolving on entries they wrote — a profile is only visible to fellow
  -- members — so the history would survive with its authorship unreadable.
  insert into public.household_members (household_id, user_id, role, joined_at)
  select surviving_household, m.user_id, m.role, m.joined_at
  from public.household_members m
  where m.household_id = absorbed_household
  on conflict (household_id, user_id) do nothing;
  get diagnostics members_moved = row_count;

  -- Custom service types, minus any the surviving garage already defines under
  -- the same key. Both garages having their own `service_cambelt` is ordinary.
  update public.service_types s
  set household_id = surviving_household
  where s.household_id = absorbed_household
    and not exists (
      select 1 from public.service_types existing
      where existing.household_id = surviving_household
        and existing.key = s.key
    );

  -- Named routes belong to the garage, not to a car, so moving the vehicles
  -- does not move them. Where the surviving garage already has a route of the
  -- same name the absorbed one folds into it: `routes_unique_name` allows one
  -- per garage whatever the case, and two garages that both named "Home to
  -- work" meant the same drive. Its journeys are repointed first, because the
  -- folded route is about to be deleted with its garage and `route_id` is
  -- `on delete set null`.
  update public.trip_entries t
  set route_id = kept.id
  from public.routes folded
  join public.routes kept
    on kept.household_id = surviving_household
   and lower(kept.name) = lower(folded.name)
  where folded.household_id = absorbed_household
    and t.route_id = folded.id;

  update public.routes r
  set household_id = surviving_household
  where r.household_id = absorbed_household
    and not exists (
      select 1 from public.routes existing
      where existing.household_id = surviving_household
        and lower(existing.name) = lower(r.name)
    );

  select count(*) into keys_revoked from public.api_keys
  where household_id = absorbed_household;

  -- Everything still pointing at the absorbed garage goes with it, by cascade:
  -- its membership rows (already copied), its outstanding invites and vehicle
  -- transfer offers (which would otherwise admit somebody to, or offer a car
  -- from, a garage that no longer exists), its remaining duplicate service
  -- types and routes, and its API keys and webhooks.
  --
  -- Keys are revoked rather than moved on purpose. A key minted to read one
  -- garage would, after the merge, read every car in the combined one — a
  -- widening of a live credential that nobody asked for. Breaking a script
  -- loudly beats broadening it quietly.
  delete from public.households where id = absorbed_household;

  return jsonb_build_object(
    'vehicles_moved', vehicles_moved,
    'members_moved', members_moved,
    'keys_revoked', keys_revoked
  );
end;
$$;

revoke execute on function public.merge_households(uuid, uuid) from public;
grant execute on function public.merge_households(uuid, uuid) to authenticated;

-- A member is not a driver ---------------------------------------------------

-- The one edit to the member side. `user_vehicle_ids()` (0003) reads this
-- and narrows with it, so every policy keyed on either now excludes a
-- driver, and a driver reaches a row only through a policy that names them.
create or replace function public.user_household_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select household_id
  from public.household_members
  where user_id = (select auth.uid())
    and role <> 'driver'
$$;

create function public.driver_household_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select household_id
  from public.household_members
  where user_id = (select auth.uid())
    and role = 'driver'
$$;

revoke execute on function public.driver_household_ids() from public;
grant execute on function public.driver_household_ids() to authenticated;

-- The garage a car belongs to, readable whoever asks. A policy on a table
-- keyed by vehicle needs it to ask about the plan, and a subselect on
-- `vehicles` inside a policy would answer through the caller's own policies.
create function public.vehicle_household(target_vehicle uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select household_id from public.vehicles where id = target_vehicle
$$;

revoke execute on function public.vehicle_household(uuid) from public;
grant execute on function public.vehicle_household(uuid) to authenticated;

create function public.is_vehicle_admin(target_vehicle uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    public.is_household_admin(public.vehicle_household(target_vehicle)),
    false
  )
$$;

revoke execute on function public.is_vehicle_admin(uuid) from public;
grant execute on function public.is_vehicle_admin(uuid) to authenticated;

-- Making somebody a driver is a company feature. The role stays on a lapsed
-- garage — its drivers keep their cars — and a new one waits for the plan.
drop policy members_update_by_admin on public.household_members;

create policy members_update_by_admin on public.household_members
  for update to authenticated
  using (public.is_household_admin(household_id))
  with check (
    public.is_household_admin(household_id)
    and (role <> 'driver' or public.company_enabled(household_id))
  );

-- Succession never crowns a driver. The rule from 0056 and 0058 promotes the
-- longest-standing member when the last admin steps down or leaves; a
-- driver sees one car and must not inherit the console. When only drivers
-- would remain, a demotion keeps the role where it was (the 0058 branch),
-- and a leave is refused by the trigger below. The function is otherwise
-- 0058's.
create or replace function public.ensure_household_has_admin(
  target_household uuid,
  stepping_down uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.household_members
    where household_id = target_household and role = 'admin'
  ) or not exists (
    select 1 from public.household_members
    where household_id = target_household
  ) then
    return;
  end if;

  update public.household_members
  set role = 'admin'
  where (household_id, user_id) = (
    select household_id, user_id from public.household_members
    where household_id = target_household
      and role <> 'driver'
      and (stepping_down is null or user_id <> stepping_down)
    order by joined_at, user_id
    limit 1
  );

  -- Nobody but the person stepping down: they keep it rather than the garage
  -- losing its last admin.
  if not found and stepping_down is not null then
    update public.household_members
    set role = 'admin'
    where household_id = target_household and user_id = stepping_down;
  end if;
end;
$$;

revoke execute on function public.ensure_household_has_admin(uuid, uuid)
  from public, anon, authenticated;

-- An admin's leave that would leave only drivers behind is refused: the
-- trigger raises, the delete rolls back, and the admin names a successor
-- first. Only a leave, which is the caller's own row going, and only an
-- admin's: a driver leaving a garage never needs refusing. An account
-- deletion cascades here from auth.users with no auth.uid() to compare, and
-- it proceeds: the garage is left with its drivers and no admin, which is
-- recorded rather than refused, since erasure has to be real (0033).
create or replace function public.promote_after_member_left()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Nobody is stepping down here: the row is gone, so it cannot inherit.
  perform public.ensure_household_has_admin(old.household_id, null);
  if old.role = 'admin'
     and (select auth.uid()) = old.user_id
     and exists (
       select 1 from public.household_members
       where household_id = old.household_id
     )
     and not exists (
       select 1 from public.household_members
       where household_id = old.household_id and role = 'admin'
     ) then
    raise exception 'a garage of drivers needs an admin' using errcode = 'P0007';
  end if;
  return old;
end;
$$;

revoke execute on function public.promote_after_member_left()
  from public, anon, authenticated;

-- Assignments ----------------------------------------------------------------

-- A log, not a field: "who had the car on 3 May" is what a fine, a scratch
-- or a speeding ticket asks, and a field only ever knows who has it now.
create table public.vehicle_assignments (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  -- Set null rather than cascade: the window stays in the log when the
  -- account behind it is deleted, like every entry keeps its place when its
  -- author goes (0033). Nothing resolves to a null driver.
  user_id uuid references auth.users (id) on delete set null,
  from_date date not null,
  -- Null: open. The last day the driver had it, inclusive.
  to_date date,
  handover_odometer_km int check (handover_odometer_km >= 0),
  return_odometer_km int check (return_odometer_km >= 0),
  note text check (note is null or char_length(note) <= 500),
  -- The driver's sign-off from the phone: what the paper putni blok had.
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users (id) on delete set null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint vehicle_assignments_window
    check (to_date is null or to_date >= from_date),
  -- One driver per car at a time. A null upper bound is an unbounded range,
  -- which is what an open assignment is.
  constraint vehicle_assignments_one_driver_at_a_time
    exclude using gist (
      vehicle_id with =,
      daterange(from_date, to_date, '[]') with &&
    )
);

create index vehicle_assignments_vehicle_idx
  on public.vehicle_assignments (vehicle_id, from_date desc);

create index vehicle_assignments_user_idx
  on public.vehicle_assignments (user_id);

create trigger vehicle_assignments_pin_created_by
  before update on public.vehicle_assignments
  for each row execute function public.pin_created_by();

-- The cars a driver has today. Membership is required as well as the row:
-- an assignment outlives a membership, and a person removed from the garage
-- must not keep the car through the log of having had it.
--
-- `current_date` is the server's day, which on Supabase is UTC: a handover
-- dated today reaches the driver's phone once it is today in UTC.
create function public.driver_vehicle_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select a.vehicle_id
  from public.vehicle_assignments a
  join public.vehicles v on v.id = a.vehicle_id
  join public.household_members m
    on m.household_id = v.household_id and m.user_id = a.user_id
  where a.user_id = (select auth.uid())
    and m.role = 'driver'
    and a.from_date <= current_date
    and (a.to_date is null or a.to_date >= current_date)
$$;

revoke execute on function public.driver_vehicle_ids() from public;
grant execute on function public.driver_vehicle_ids() to authenticated;

alter table public.vehicle_assignments enable row level security;

create policy vehicle_assignments_select on public.vehicle_assignments
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

-- Their own windows, while they are still a driver in the car's garage: the
-- log outlives a membership so that nothing resolves to a stranger, but a
-- driver who was removed reads none of it, notes and readings included —
-- the same clause `driver_vehicle_ids()` applies to the cars themselves.
create policy vehicle_assignments_select_driver on public.vehicle_assignments
  for select to authenticated
  using (
    user_id = (select auth.uid())
    and public.vehicle_household(vehicle_id)
      in (select public.driver_household_ids())
  );

create policy vehicle_assignments_insert on public.vehicle_assignments
  for insert to authenticated
  with check (
    public.is_vehicle_admin(vehicle_id)
    and public.company_enabled(public.vehicle_household(vehicle_id))
    and created_by = (select auth.uid())
  );

create policy vehicle_assignments_update on public.vehicle_assignments
  for update to authenticated
  using (public.is_vehicle_admin(vehicle_id))
  with check (public.is_vehicle_admin(vehicle_id));

create policy vehicle_assignments_delete on public.vehicle_assignments
  for delete to authenticated
  using (public.is_vehicle_admin(vehicle_id));

-- The schema's default privileges hand anon and authenticated everything on
-- a new table (0079), so the grants are spelled out.
revoke all on public.vehicle_assignments from anon, authenticated;
grant select, insert, update, delete on public.vehicle_assignments
  to authenticated;

alter publication supabase_realtime add table public.vehicle_assignments;
alter table public.vehicle_assignments replica identity full;

-- Who had a car on a day. The same rule as `AssignmentResolution.driverOn`
-- in Dart, held to the same fixture (test/fixtures/assignment_resolution.json)
-- from both sides. Invoker rights on purpose: a member sees the garage's
-- log, a driver their own rows, and the daily push run reads it as the
-- service role.
create function public.driver_on(target_vehicle uuid, on_date date)
returns uuid
language sql
stable
set search_path = public
as $$
  select user_id
  from public.vehicle_assignments
  where vehicle_id = target_vehicle
    and from_date <= on_date
    and (to_date is null or to_date >= on_date)
  limit 1
$$;

revoke execute on function public.driver_on(uuid, date) from public;
grant execute on function public.driver_on(uuid, date) to authenticated;

-- A handover in one call: the open assignment is closed on the day before,
-- the reading is written as an odometer entry, and the next assignment is
-- opened — or not, when the car comes back to nobody. One transaction, so
-- the odometer series and the log cannot disagree. Returns the new
-- assignment's id, or null when the car was only taken back.
--
-- A second handover on the same day is refused (P0006): under one driver
-- per day there is no room for it, and the admin deletes the wrong row and
-- hands over again.
create function public.hand_over_vehicle(
  target_vehicle uuid,
  on_date date,
  odometer_km int default null,
  to_user uuid default null,
  handover_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := (select auth.uid());
  owner_household uuid := public.vehicle_household(target_vehicle);
  open_from date;
  next_id uuid;
begin
  if caller is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if owner_household is null or not public.is_vehicle_admin(target_vehicle)
  then
    raise exception 'only an admin hands a car over' using errcode = '42501';
  end if;
  if to_user is not null and not exists (
    select 1 from public.household_members
    where household_id = owner_household and user_id = to_user
  ) then
    raise exception 'not a member of this garage' using errcode = '42501';
  end if;
  -- Taking a car back is allowed on a lapsed plan; handing it on is not.
  if to_user is not null and not public.company_enabled(owner_household) then
    raise exception 'the garage is not on the company plan'
      using errcode = '42501';
  end if;

  select from_date into open_from
  from public.vehicle_assignments
  where vehicle_id = target_vehicle and to_date is null
  for update;

  if open_from is not null then
    if open_from >= on_date then
      raise exception 'the car was already handed over on that date'
        using errcode = 'P0006';
    end if;
    update public.vehicle_assignments
    set to_date = on_date - 1,
        return_odometer_km = coalesce(odometer_km, return_odometer_km)
    where vehicle_id = target_vehicle and to_date is null;
  end if;

  if odometer_km is not null then
    insert into public.odometer_entries (
      vehicle_id, entry_date, odometer_km, created_by
    )
    values (target_vehicle, on_date, odometer_km, caller);
  end if;

  if to_user is not null then
    begin
      insert into public.vehicle_assignments (
        vehicle_id, user_id, from_date, handover_odometer_km, note, created_by
      )
      values (
        target_vehicle, to_user, on_date, odometer_km,
        nullif(trim(handover_note), ''), caller
      )
      returning id into next_id;
    exception
      -- A closed window already covers the day: the same answer as an open
      -- one that started on it, rather than the constraint's own.
      when exclusion_violation then
        raise exception 'the car was already handed over on that date'
          using errcode = 'P0006';
    end;
  end if;

  return next_id;
end;
$$;

revoke execute on function public.hand_over_vehicle(uuid, date, int, uuid, text)
  from public;
grant execute on function public.hand_over_vehicle(uuid, date, int, uuid, text)
  to authenticated;

-- The driver's sign-off. A function rather than an update policy: the only
-- thing a driver may change on the row is that they confirm it.
create function public.confirm_vehicle_assignment(assignment_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := (select auth.uid());
begin
  update public.vehicle_assignments
  set confirmed_at = now(), confirmed_by = caller
  where id = assignment_id
    and user_id = caller
    and confirmed_at is null;
  if not found then
    raise exception 'no assignment of yours to confirm' using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.confirm_vehicle_assignment(uuid) from public;
grant execute on function public.confirm_vehicle_assignment(uuid)
  to authenticated;

-- And theirs alone. What a sign-off guarantees: it carries the driver's own
-- id and was written by them, through the function above, and the window
-- it is on still names them. A window is created unsigned, whoever creates
-- it, and the one change let through afterwards is the driver of the row
-- signing it once; a signed window is evidence for a fine and cannot be
-- re-pointed at another member. An admin owns the log and may delete a
-- window and create it again, so a sign-off can be lost; it cannot be
-- forged or edited. The other updates that touch these columns are a
-- deleted account's `on delete set null`, let through the way
-- pin_created_by does (0033), or the deletion would be refused by a
-- trigger and report success.
create function public.guard_assignment_confirmation()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if tg_op = 'INSERT' then
    if new.confirmed_at is not null or new.confirmed_by is not null then
      raise exception 'a window is created unsigned'
        using errcode = '42501';
    end if;
    return new;
  end if;
  if old.confirmed_at is not null
     and new.user_id is not null
     and new.user_id is distinct from old.user_id then
    raise exception 'a signed window keeps its driver'
      using errcode = '42501';
  end if;
  if new.confirmed_at is not distinct from old.confirmed_at
     and new.confirmed_by is not distinct from old.confirmed_by then
    return new;
  end if;
  if old.confirmed_at is null
     and new.confirmed_at is not null
     and new.user_id = (select auth.uid())
     and new.confirmed_by = (select auth.uid()) then
    return new;
  end if;
  if new.confirmed_by is null
     and old.confirmed_by is not null
     and new.confirmed_at is not distinct from old.confirmed_at
     and not exists (select 1 from auth.users where id = old.confirmed_by) then
    return new;
  end if;
  raise exception 'the sign-off is the driver''s to give'
    using errcode = '42501';
end;
$$;

revoke execute on function public.guard_assignment_confirmation()
  from public, anon, authenticated;

create trigger vehicle_assignments_guard_confirmation
  before insert or update on public.vehicle_assignments
  for each row execute function public.guard_assignment_confirmation();

-- Incidents ------------------------------------------------------------------

create table public.incidents (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  kind text not null check (kind in ('damage', 'fault', 'fine', 'accident')),
  happened_on date not null,
  odometer_km int check (odometer_km is null or odometer_km >= 0),
  description text not null
    check (char_length(description) between 1 and 2000),
  -- The fine, the excess, the repair.
  amount numeric(12, 2) check (amount is null or amount >= 0),
  status text not null default 'open'
    check (status in ('open', 'at_insurer', 'repaired', 'paid', 'closed')),
  resolved_on date,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint incidents_resolved_after_happened
    check (resolved_on is null or resolved_on >= happened_on)
);

create index incidents_vehicle_idx
  on public.incidents (vehicle_id, happened_on desc);

create trigger incidents_pin_created_by
  before update on public.incidents
  for each row execute function public.pin_created_by();

alter table public.incidents enable row level security;

create policy incidents_select on public.incidents
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy incidents_insert on public.incidents
  for insert to authenticated
  with check (
    vehicle_id in (select public.user_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy incidents_update on public.incidents
  for update to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()))
  with check (vehicle_id in (select public.user_vehicle_ids()));

create policy incidents_delete on public.incidents
  for delete to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

revoke all on public.incidents from anon, authenticated;
grant select, insert, update, delete on public.incidents to authenticated;

alter publication supabase_realtime add table public.incidents;
alter table public.incidents replica identity full;

alter table public.attachments
  drop constraint attachments_entry_kind_check;
alter table public.attachments
  add constraint attachments_entry_kind_check
  check (entry_kind in (
    'fuel', 'service', 'cost', 'document', 'observation', 'incident'
  ));

-- Payment method -------------------------------------------------------------

-- Null is the household default and stays null for a private garage.
alter table public.fuel_entries
  add column paid_with text
    check (paid_with is null
      or paid_with in ('company_card', 'company_cash', 'own_money')),
  add column reimbursed_at timestamptz;

alter table public.service_entries
  add column paid_with text
    check (paid_with is null
      or paid_with in ('company_card', 'company_cash', 'own_money')),
  add column reimbursed_at timestamptz;

alter table public.cost_entries
  add column paid_with text
    check (paid_with is null
      or paid_with in ('company_card', 'company_cash', 'own_money')),
  add column reimbursed_at timestamptz;

-- A driver edits their own entries, and "paid back" is the company's word,
-- not theirs. The same shape as the rename guard (0036).
create function public.guard_reimbursed_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.reimbursed_at is distinct from old.reimbursed_at
     and not public.is_vehicle_admin(new.vehicle_id) then
    raise exception 'only an admin marks an entry reimbursed'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_reimbursed_at()
  from public, anon, authenticated;

create trigger fuel_entries_guard_reimbursed
  before update on public.fuel_entries
  for each row execute function public.guard_reimbursed_at();

create trigger service_entries_guard_reimbursed
  before update on public.service_entries
  for each row execute function public.guard_reimbursed_at();

create trigger cost_entries_guard_reimbursed
  before update on public.cost_entries
  for each row execute function public.guard_reimbursed_at();

-- Receipt reminders ----------------------------------------------------------

-- "Remind the driver" on the console, delivered by the same daily push
-- function that sends due reminders (push-due-reminders), which drains this
-- table when poked. A row per request rather than a push from the app: the
-- app holds nothing that may send a push, and must not.
create table public.receipt_reminders (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  entry_kind text not null check (entry_kind in ('fuel', 'service', 'cost')),
  entry_id uuid not null,
  entry_date date not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  requested_by uuid references auth.users (id) on delete set null,
  requested_at timestamptz not null default now(),
  sent_at timestamptz
);

create index receipt_reminders_pending_idx
  on public.receipt_reminders (requested_at)
  where sent_at is null;

alter table public.receipt_reminders enable row level security;

create policy receipt_reminders_select on public.receipt_reminders
  for select to authenticated
  using (public.is_vehicle_admin(vehicle_id));

revoke all on public.receipt_reminders from anon, authenticated;
grant select on public.receipt_reminders to authenticated;

-- The poke, with a body that tells the function to send only these. The
-- daily run posts `{}` and computes what is due; a run for a receipt must
-- not repeat the day's due reminders to every webhook. Silent, like
-- run_due_reminders_push (0076), wherever the Vault holds no endpoint: that
-- is every stack but production, and the RLS suite among them.
create function public.run_receipt_reminders_push()
returns void
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  endpoint text;
  auth_token text;
begin
  select decrypted_secret into endpoint
  from vault.decrypted_secrets where name = 'push_endpoint';

  select decrypted_secret into auth_token
  from vault.decrypted_secrets where name = 'push_service_role_key';

  if endpoint is null or auth_token is null then
    return;
  end if;

  perform net.http_post(
    url := endpoint,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || auth_token
    ),
    body := '{"only": "receipts"}'::jsonb,
    timeout_milliseconds := 60000
  );
end;
$$;

revoke execute on function public.run_receipt_reminders_push()
  from public, anon, authenticated;

create function public.request_receipt_reminder(
  target_vehicle uuid,
  kind text,
  entry uuid,
  driver uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := (select auth.uid());
  owner_household uuid := public.vehicle_household(target_vehicle);
  on_date date;
  reminder_id uuid;
begin
  if owner_household is null or not public.is_vehicle_admin(target_vehicle)
  then
    raise exception 'only an admin reminds a driver' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.household_members
    where household_id = owner_household and user_id = driver
  ) then
    raise exception 'not a member of this garage' using errcode = '42501';
  end if;

  -- The entry has to exist on this car, whichever table holds it.
  on_date := case kind
    when 'fuel' then (
      select entry_date from public.fuel_entries
      where id = entry and vehicle_id = target_vehicle
    )
    when 'service' then (
      select entry_date from public.service_entries
      where id = entry and vehicle_id = target_vehicle
    )
    when 'cost' then (
      select entry_date from public.cost_entries
      where id = entry and vehicle_id = target_vehicle
    )
  end;
  if on_date is null then
    raise exception 'no such entry on this car' using errcode = 'P0002';
  end if;

  insert into public.receipt_reminders (
    vehicle_id, entry_kind, entry_id, entry_date, user_id, requested_by
  )
  values (target_vehicle, kind, entry, on_date, driver, caller)
  returning id into reminder_id;

  perform public.run_receipt_reminders_push();
  return reminder_id;
end;
$$;

revoke execute on function public.request_receipt_reminder(uuid, text, uuid, uuid)
  from public;
grant execute on function public.request_receipt_reminder(uuid, text, uuid, uuid)
  to authenticated;

-- What a driver may reach -----------------------------------------------------
--
-- Additive, one table at a time, the way 0055 did it for guests. Reading is
-- the assigned car and everything on it; writing is the entry tables, and
-- editing or deleting is the driver's own rows only.

create policy vehicles_select_driver on public.vehicles
  for select to authenticated
  using (id in (select public.driver_vehicle_ids()));

create policy fuel_entries_select_driver on public.fuel_entries
  for select to authenticated
  using (vehicle_id in (select public.driver_vehicle_ids()));

create policy fuel_entries_insert_driver on public.fuel_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy fuel_entries_update_driver on public.fuel_entries
  for update to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  )
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy fuel_entries_delete_driver on public.fuel_entries
  for delete to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy service_entries_select_driver on public.service_entries
  for select to authenticated
  using (vehicle_id in (select public.driver_vehicle_ids()));

create policy service_entries_insert_driver on public.service_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy service_entries_update_driver on public.service_entries
  for update to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  )
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy service_entries_delete_driver on public.service_entries
  for delete to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy cost_entries_select_driver on public.cost_entries
  for select to authenticated
  using (vehicle_id in (select public.driver_vehicle_ids()));

create policy cost_entries_insert_driver on public.cost_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy cost_entries_update_driver on public.cost_entries
  for update to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  )
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy cost_entries_delete_driver on public.cost_entries
  for delete to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy odometer_entries_select_driver on public.odometer_entries
  for select to authenticated
  using (vehicle_id in (select public.driver_vehicle_ids()));

create policy odometer_entries_insert_driver on public.odometer_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy odometer_entries_update_driver on public.odometer_entries
  for update to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  )
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy odometer_entries_delete_driver on public.odometer_entries
  for delete to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy trip_entries_select_driver on public.trip_entries
  for select to authenticated
  using (vehicle_id in (select public.driver_vehicle_ids()));

create policy trip_entries_insert_driver on public.trip_entries
  for insert to authenticated
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy trip_entries_update_driver on public.trip_entries
  for update to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  )
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy trip_entries_delete_driver on public.trip_entries
  for delete to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy observations_select_driver on public.observations
  for select to authenticated
  using (vehicle_id in (select public.driver_vehicle_ids()));

create policy observations_insert_driver on public.observations
  for insert to authenticated
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy observations_update_driver on public.observations
  for update to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  )
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy observations_delete_driver on public.observations
  for delete to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy incidents_select_driver on public.incidents
  for select to authenticated
  using (vehicle_id in (select public.driver_vehicle_ids()));

create policy incidents_insert_driver on public.incidents
  for insert to authenticated
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy incidents_update_driver on public.incidents
  for update to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  )
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy incidents_delete_driver on public.incidents
  for delete to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

-- Attachments: a driver's own, on an assigned car. Insert is not tied to the
-- entry's author because a receipt is attached before the entry exists
-- (decision 90), so there is no row to check; delete is tied to the
-- uploader, which is what lets an abandoned sheet take its photo down.
create policy attachments_select_driver on public.attachments
  for select to authenticated
  using (vehicle_id in (select public.driver_vehicle_ids()));

create policy attachments_insert_driver on public.attachments
  for insert to authenticated
  with check (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy attachments_delete_driver on public.attachments
  for delete to authenticated
  using (
    vehicle_id in (select public.driver_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy attachments_object_select_driver on storage.objects
  for select to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] in (
      select vehicle_id::text from public.driver_vehicle_ids() as vehicle_id
    )
  );

create policy attachments_object_insert_driver on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] in (
      select vehicle_id::text from public.driver_vehicle_ids() as vehicle_id
    )
  );

-- The uploader's own file, and only theirs: storage records who uploaded an
-- object in `owner_id`, so a driver taking down a receipt they abandoned
-- cannot take down the one the admin attached beside it.
create policy attachments_object_delete_driver on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'attachments'
    and owner_id = (select auth.uid())::text
    and (storage.foldername(name))[1] in (
      select vehicle_id::text from public.driver_vehicle_ids() as vehicle_id
    )
  );

-- A car's photo is keyed <household>/<vehicle>, so the car is the file name.
create policy vehicle_photos_select_driver on storage.objects
  for select to authenticated
  using (
    bucket_id = 'vehicle-photos'
    and storage.filename(name) in (
      select vehicle_id::text from public.driver_vehicle_ids() as vehicle_id
    )
  );

-- Read-only for a driver: the car's papers, tyres, parts, intervals, the
-- garage's named routes and its own service types.
create policy vehicle_documents_select_driver on public.vehicle_documents
  for select to authenticated
  using (vehicle_id in (select public.driver_vehicle_ids()));

create policy tyre_sets_select_driver on public.tyre_sets
  for select to authenticated
  using (vehicle_id in (select public.driver_vehicle_ids()));

create policy tyre_readings_select_driver on public.tyre_readings
  for select to authenticated
  using (
    tyre_set_id in (
      select id from public.tyre_sets
      where vehicle_id in (select public.driver_vehicle_ids())
    )
  );

create policy vehicle_parts_select_driver on public.vehicle_parts
  for select to authenticated
  using (vehicle_id in (select public.driver_vehicle_ids()));

create policy reminder_rules_select_driver on public.reminder_rules
  for select to authenticated
  using (vehicle_id in (select public.driver_vehicle_ids()));

create policy routes_select_driver on public.routes
  for select to authenticated
  using (household_id in (select public.driver_household_ids()));

create policy service_types_select_driver on public.service_types
  for select to authenticated
  using (household_id in (select public.driver_household_ids()));

-- The garage itself, and the people in it, for attribution by name.
create policy households_select_driver on public.households
  for select to authenticated
  using (id in (select public.driver_household_ids()));

create policy members_select_driver on public.household_members
  for select to authenticated
  using (household_id in (select public.driver_household_ids()));

create policy profiles_select_driver on public.profiles
  for select to authenticated
  using (
    exists (
      select 1 from public.household_members
      where user_id = profiles.user_id
        and household_id in (select public.driver_household_ids())
    )
  );

-- Two deadlines a fleet has and a household rarely does. The periodic
-- inspection is Croatia's six-monthly check on older and heavier vehicles;
-- the tachograph calibration is for the vans that carry one, so it is not
-- statutory for a car and an admin adds the rule where it applies.
insert into public.service_types
  (household_id, key, default_interval_km, default_interval_months,
   is_statutory, country_code)
values
  (null, 'service_periodic_inspection', null, 6, true, 'HR'),
  (null, 'service_tachograph_calibration', null, 24, false, null)
on conflict do nothing;
