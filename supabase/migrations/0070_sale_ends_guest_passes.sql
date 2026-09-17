-- A sale ends every loan of the car.
--
-- A guest pass is keyed to the vehicle, and `guest_vehicle_ids` looks at
-- nothing but the pass row. `redeem_vehicle_transfer` was written before passes
-- existed (0030, redefined in 0048) and changes the vehicle's garage and
-- nothing else. So whoever the seller had lent the car to went on holding it in
-- the buyer's garage: they kept the briefing, could log against the car, and
-- with history switched on read everything the buyer logged, until the buyer
-- happened to open Lending and withdraw a pass they had never issued. One
-- garage's data reachable by somebody that garage never let in.
--
-- Fixed here rather than by a trigger on `vehicles.household_id`, because a
-- merge changes that column too and keeps its passes on purpose (0057): the
-- people who issued them arrive with the car. A sale is the opposite case, and
-- this function is the only thing that performs one. Anything that ever moves
-- a vehicle between garages for another reason has to answer the same
-- question for itself.
--
-- Every pass still able to grant anything is withdrawn, claimed or not: a code
-- handed out and never redeemed would otherwise open the buyer's car the day
-- somebody typed it in. `revoked_at` rather than a delete, for the reason
-- expiry deletes nothing (0055): what a borrower logged stays in the car's
-- history, and the buyer can see that a loan existed and that it is over.
--
-- The function is otherwise 0048's, word for word.

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

  -- A code that outlived its own premise: the vehicle has already moved on, or
  -- back. Moving it again from a household that no longer owns it would let an
  -- old code claim a car twice.
  if not exists (
    select 1 from public.vehicles
    where id = transfer.vehicle_id
      and household_id = transfer.from_household_id
  ) then
    raise exception 'transfer code is no longer valid' using errcode = 'P0002';
  end if;

  if target_household = transfer.from_household_id then
    raise exception 'the vehicle is already in this household' using errcode = 'P0005';
  end if;

  update public.vehicles
  set household_id = target_household,
      -- The photo lives under the old household's storage prefix and cannot
      -- follow. Left behind rather than pointing at a file the new owner
      -- cannot read.
      photo_path = null,
      archived = false
  where id = transfer.vehicle_id;

  -- The seller's loans end with the seller's ownership. Passes already over
  -- are left as they are, so the record still says how each one ended.
  update public.vehicle_guest_passes
  set revoked_at = now()
  where vehicle_id = transfer.vehicle_id
    and revoked_at is null
    and returned_at is null
    and expires_at > now();

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

revoke execute on function public.redeem_vehicle_transfer(text, uuid) from public;
grant execute on function public.redeem_vehicle_transfer(text, uuid) to authenticated;
