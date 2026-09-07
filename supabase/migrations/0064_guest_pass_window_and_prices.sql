-- Lending, three things learned the moment somebody used it.
--
-- 1. A loan is a *window*, not a length. "Four days from now" cannot say
--    "the car is his from Friday to Sunday", and a pass booked ahead is the
--    ordinary case, not the exotic one.
-- 2. A loan gets extended. "He rang and needs it one more day" was, until
--    now, revoke and mint a new code — a different code, for the same car,
--    to the same person, losing the connection to what they had already
--    logged.
-- 3. A mechanic should be able to read what was done to the car without
--    reading what it cost. Those are two different questions and the owner
--    is entitled to answer only the first.
--
-- (3) is the one that cannot be done in the app. Postgres has no column
-- masking, so "history without prices" cannot be a narrower row grant: a row
-- a guest may select is a row whose `cost` they may select. The grant is
-- therefore taken away and given back through a function that decides, per
-- column, what the pass allows.

alter table public.vehicle_guest_passes
  add column can_view_prices boolean not null default false;

-- Prices are a detail *of* the history; they are not a second kind of access.
-- Without this a pass could say "no history, but prices", which the UI would
-- have to invent a meaning for.
alter table public.vehicle_guest_passes
  add constraint guest_pass_prices_need_history
    check (not can_view_prices or can_view_history);

-- `history` now means "the whole row, prices and all", because that is what a
-- row grant actually gives. A pass that hides prices grants no rows at all and
-- is served by `guest_service_history` below.
create or replace function public.guest_vehicle_ids(permission text)
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
      -- Reading somebody else's rows in full. Hiding a column is not
      -- something a row policy can do, so a pass that hides prices does not
      -- get here.
      when 'history' then can_view_history and can_view_prices
      -- The same access with the money left out, which only the masking
      -- function below acts on.
      when 'history_masked' then can_view_history and not can_view_prices
      -- 'vehicle' is the bare fact of the car existing: a guest has to see the
      -- thing they are logging against whatever else the pass allows.
      when 'vehicle' then true
      else false
    end
$$;

-- What was done to this car, for whoever is holding it.
--
-- Security definer, so it can read rows the caller's policies would refuse,
-- and it returns `cost` as null unless the pass says otherwise. A member of
-- the garage gets the same list with the prices they can already see, so one
-- screen serves both and there is no "guest version" of a screen to keep in
-- step.
create function public.guest_service_history(target_vehicle uuid)
returns table (
  id uuid,
  entry_date date,
  odometer_km int,
  service_type_keys text[],
  shop text,
  notes text,
  cost numeric(12, 2)
)
language sql
security definer
stable
set search_path = public
as $$
  select s.id, s.entry_date, s.odometer_km, s.service_type_keys, s.shop,
         s.notes,
         case
           when target_vehicle in (select public.user_vehicle_ids()) then s.cost
           when target_vehicle in (select public.guest_vehicle_ids('history'))
             then s.cost
           else null
         end
  from public.service_entries s
  where s.vehicle_id = target_vehicle
    and (
      target_vehicle in (select public.user_vehicle_ids())
      or target_vehicle in (select public.guest_vehicle_ids('history'))
      or target_vehicle in (select public.guest_vehicle_ids('history_masked'))
    )
  order by s.entry_date desc, s.odometer_km desc
$$;

revoke execute on function public.guest_service_history(uuid) from public;
grant execute on function public.guest_service_history(uuid) to authenticated;

-- Minting a pass over a window rather than for a number of days.
--
-- `create_guest_pass` stays: it is what the shipped app calls, and a function
-- signature is an API. This one is what the app calls now.
create function public.create_guest_pass_between(
  target_vehicle uuid,
  ends_on timestamptz,
  starts_on timestamptz default null,
  pass_label text default null,
  allow_fuel boolean default true,
  allow_trips boolean default true,
  allow_costs boolean default true,
  allow_history boolean default false,
  allow_prices boolean default false
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
  attempts int := 0;
  opens_at timestamptz := coalesce(starts_on, now());
begin
  if target_vehicle not in (select public.user_vehicle_ids()) then
    raise exception 'not a member of the garage this vehicle belongs to';
  end if;

  if ends_on <= opens_at then
    raise exception 'a pass has to end after it starts';
  end if;
  if ends_on > opens_at + interval '1 year' then
    raise exception 'a pass lasts at most a year';
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
    can_log_fuel, can_log_trips, can_log_costs, can_view_history,
    can_view_prices
  )
  values (
    target_vehicle,
    new_code,
    nullif(trim(pass_label), ''),
    (select auth.uid()),
    starts_on,
    ends_on,
    allow_fuel, allow_trips, allow_costs, allow_history,
    -- Belt and braces with the check constraint: a caller that asks for
    -- prices without history gets prices dropped rather than an error.
    allow_history and allow_prices
  );

  return new_code;
end;
$$;

revoke execute on function public.create_guest_pass_between(
  uuid, timestamptz, timestamptz, text, boolean, boolean, boolean, boolean,
  boolean
) from public;
grant execute on function public.create_guest_pass_between(
  uuid, timestamptz, timestamptz, text, boolean, boolean, boolean, boolean,
  boolean
) to authenticated;

-- The older mint keeps the meaning it shipped with.
--
-- `allow_history` meant "sees the history, all of it" before prices were a
-- separate question, and a pass minted through it must still mean that —
-- otherwise this migration would silently narrow what an existing caller
-- grants, which is the one thing a redefinition must never do.
create or replace function public.create_guest_pass(
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
    can_log_fuel, can_log_trips, can_log_costs, can_view_history,
    can_view_prices
  )
  values (
    target_vehicle,
    new_code,
    nullif(trim(pass_label), ''),
    (select auth.uid()),
    starts_on,
    coalesce(starts_on, now()) + make_interval(days => valid_days),
    allow_fuel, allow_trips, allow_costs, allow_history,
    allow_history
  );

  return new_code;
end;
$$;
