-- Moving a car, and its whole history, to somebody else's garage.
--
-- Drivvo sends the buyer a *copy* of the history. A copy is the wrong shape:
-- the seller keeps a car they no longer own, and two records of the same
-- vehicle drift apart the moment either is edited. Here the vehicle row's
-- household_id changes, so every fill-up, service, cost, reading, trip, income
-- entry and attachment moves with it — they all hang off vehicle_id — and the
-- seller stops seeing it because RLS is scoped to the household.
--
-- What does not move: the vehicle photo. Objects in the `vehicle-photos`
-- bucket are keyed <household_id>/<vehicle_id>, and SQL cannot move a storage
-- object. The path is cleared instead, which is also the more honest outcome:
-- a photo of somebody's driveway is theirs, not the car's.

create table public.vehicle_transfers (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  -- Kept so a transfer offered by a household that no longer owns the vehicle
  -- can be recognised as stale rather than silently moving it back.
  from_household_id uuid not null references public.households (id) on delete cascade,
  code text not null unique check (char_length(code) = 8),
  expires_at timestamptz not null,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  redeemed_at timestamptz,
  redeemed_by uuid references auth.users (id)
);

create index vehicle_transfers_vehicle_idx
  on public.vehicle_transfers (vehicle_id);

alter table public.vehicle_transfers enable row level security;

-- Only the household offering the transfer can see or withdraw its own codes.
-- The redeemer never selects the row; they go through the definer function,
-- so codes cannot be enumerated.
create policy vehicle_transfers_select on public.vehicle_transfers
  for select to authenticated
  using (from_household_id in (select public.user_household_ids()));

create policy vehicle_transfers_delete on public.vehicle_transfers
  for delete to authenticated
  using (from_household_id in (select public.user_household_ids()));

grant select, delete on public.vehicle_transfers to authenticated;

-- Offers a vehicle for transfer and returns the code to hand to the buyer.
--
-- Reuses an outstanding code rather than minting another, the same way invites
-- do: a seller who taps twice should hand out one code, not accumulate live
-- ones they cannot see.
create function public.create_vehicle_transfer(target_vehicle uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
  attempts int := 0;
  owner_household uuid;
begin
  select household_id into owner_household
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
        vehicle_id, from_household_id, code, expires_at, created_by
      )
      values (
        target_vehicle,
        owner_household,
        new_code,
        now() + interval '14 days',
        (select auth.uid())
      );
      return new_code;
    exception when unique_violation then
      if attempts >= 10 then
        raise exception 'could not generate a unique transfer code';
      end if;
    end;
  end loop;
end;
$$;

revoke execute on function public.create_vehicle_transfer(uuid) from public;
grant execute on function public.create_vehicle_transfer(uuid) to authenticated;

-- Redeems a code, moving the vehicle into a household the caller belongs to.
--
-- The destination is passed in rather than guessed: the caller may belong to
-- several, and putting somebody's newly bought car in the wrong one is not
-- recoverable from the app.
create function public.redeem_vehicle_transfer(
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
    raise exception 'authentication required';
  end if;

  if target_household not in (select public.user_household_ids()) then
    raise exception 'not a member of this household';
  end if;

  select * into transfer
  from public.vehicle_transfers
  where code = upper(trim(transfer_code))
  for update;

  if transfer.id is null then
    raise exception 'unknown transfer code';
  end if;

  if transfer.redeemed_at is not null then
    raise exception 'transfer code already used';
  end if;

  if transfer.expires_at <= now() then
    raise exception 'transfer code expired';
  end if;

  -- A code that outlived its own premise: the vehicle has already moved on, or
  -- back. Moving it again from a household that no longer owns it would let an
  -- old code claim a car twice.
  if not exists (
    select 1 from public.vehicles
    where id = transfer.vehicle_id
      and household_id = transfer.from_household_id
  ) then
    raise exception 'transfer code is no longer valid';
  end if;

  if target_household = transfer.from_household_id then
    raise exception 'the vehicle is already in this household';
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
