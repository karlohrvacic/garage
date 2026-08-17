-- A vehicle that changes hands vanishes from the seller's app only when they
-- next reload it by hand. Everything else in a garage updates live.
--
-- The cause is RLS doing exactly what it should. `vehicles` is already in the
-- publication, but redeeming a transfer *moves* the row to the buyer's
-- household: by the time the UPDATE is evaluated against the seller's policy
-- it belongs to somebody else, so the seller is not told. You are never
-- notified about a row leaving your scope — you simply stop hearing about it,
-- which is indistinguishable from nothing having happened.
--
-- `vehicle_transfers` is the signal that does survive. Its select policy is
-- `from_household_id in user_household_ids()`
-- (`0030_vehicle_transfer.sql:37`), and redeeming sets `redeemed_at` on that
-- row without moving it — so the seller keeps read access to the one record
-- that says their car is gone, and the app can listen for it.
alter publication supabase_realtime add table public.vehicle_transfers;

-- Needed for the UPDATE payload to carry the row the seller is allowed to see.
-- Without it Postgres sends only the primary key for the old tuple, and the
-- policy cannot be evaluated against a row it does not have.
alter table public.vehicle_transfers replica identity full;

-- The seller cannot read the vehicle after it moves — that is the whole point
-- of the transfer — so telling them *which* car has gone means keeping its
-- name here, captured when the code is offered. Without it the only honest
-- notice is "a vehicle you transferred", which for a garage of four is not
-- much of a notice.
alter table public.vehicle_transfers
  add column if not exists vehicle_nickname text;

-- Backfills what is still readable. Rows whose vehicle has already moved keep
-- a null name and read as the generic case, which is the correct outcome for
-- history that was never captured.
update public.vehicle_transfers t
set vehicle_nickname = v.nickname
from public.vehicles v
where v.id = t.vehicle_id
  and t.vehicle_nickname is null;

-- Recreated only to record the name alongside the code. Everything else is
-- unchanged from `0030`, including reusing an outstanding code rather than
-- minting a second one.
create or replace function public.create_vehicle_transfer(target_vehicle uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
  attempts int := 0;
  owner_household uuid;
  owner_nickname text;
begin
  select household_id, nickname into owner_household, owner_nickname
  from public.vehicles
  where id = target_vehicle;

  if owner_household is null
     or owner_household not in (select public.user_household_ids()) then
    raise exception 'not your vehicle';
  end if;

  select code into new_code
  from public.vehicle_transfers
  where vehicle_id = target_vehicle
    and redeemed_at is null
    and expires_at > now()
    and from_household_id = owner_household
  order by created_at desc
  limit 1;

  if new_code is not null then
    return new_code;
  end if;

  loop
    new_code := public.generate_invite_code();
    attempts := attempts + 1;
    begin
      insert into public.vehicle_transfers (
        vehicle_id, from_household_id, code, expires_at, created_by,
        vehicle_nickname
      )
      values (
        target_vehicle,
        owner_household,
        new_code,
        now() + interval '14 days',
        (select auth.uid()),
        owner_nickname
      );
      return new_code;
    exception when unique_violation then
      if attempts >= 10 then
        raise exception 'could not allocate a transfer code';
      end if;
    end;
  end loop;
end;
$$;

revoke execute on function public.create_vehicle_transfer(uuid) from public;
grant execute on function public.create_vehicle_transfer(uuid) to authenticated;
