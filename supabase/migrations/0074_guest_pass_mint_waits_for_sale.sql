-- A pass minted while its car is being sold waits for the sale.
--
-- 0070 makes a sale withdraw every loan of the car. Minting a pass checked the
-- caller's membership and inserted, and the insert's foreign-key check takes a
-- key-share lock on the vehicle, which does not conflict with the sale's
-- update of the same row. So a member of the selling garage could mint a pass
-- in the instant between the sale moving the car and the sale withdrawing its
-- passes, and the pass outlived the sale in the buyer's garage. Two real
-- sessions showed it in both orders: a mint started during the sale succeeded
-- at once, and a sale started during a mint withdrew nothing.
--
-- A share lock on the vehicle conflicts with the sale's update. If the sale
-- came first, the mint waits for it to commit and its membership check then
-- reads a car that is no longer the seller's, and refuses. If the mint came
-- first, the sale waits, and its withdrawal then sees the committed pass.
--
-- Both functions are otherwise 0064's, word for word.

create or replace function public.create_guest_pass_between(
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
  -- Waits for a sale of this car that is under way, so the check below reads
  -- where the car is now. See the header.
  perform 1 from public.vehicles where id = target_vehicle for share;

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
  -- Waits for a sale of this car that is under way, so the check below reads
  -- where the car is now. See the header.
  perform 1 from public.vehicles where id = target_vehicle for share;

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

revoke execute on function public.create_guest_pass(
  uuid, int, text, timestamptz, boolean, boolean, boolean, boolean
) from public;
grant execute on function public.create_guest_pass(
  uuid, int, text, timestamptz, boolean, boolean, boolean, boolean
) to authenticated;
