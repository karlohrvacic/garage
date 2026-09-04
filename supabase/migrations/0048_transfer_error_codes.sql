-- Distinct error codes for redeeming a vehicle transfer.
--
-- Every refusal was a bare `raise exception`, which Postgres reports as
-- P0001, so the app could only say "something went wrong" — and once it
-- started naming that one code, a valid code redeemed into the garage that
-- already owns the car was reported as an invalid code, which is a retry
-- loop that cannot succeed. The vocabulary matches join_household_with_code:
-- P0002 unknown, P0003 expired, P0004 already used, plus P0005 for "already
-- here" and the standard 28000/42501 for auth and membership.

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
