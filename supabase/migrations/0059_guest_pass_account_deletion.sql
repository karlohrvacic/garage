-- Deleting an account failed again, for anyone who had lent or borrowed a car.
--
-- `0033` removed exactly this refusal from every table that existed then:
-- a `created_by` referencing `auth.users` with the default `no action` means
-- Postgres will not delete a user while any row still points at them, and
-- in-app deletion is a Play requirement. `vehicle_guest_passes` (migration
-- 0055) was written afterwards with `created_by uuid not null references
-- auth.users (id)` and a `redeemed_by` with the same default, and so put the
-- bug straight back.
--
-- Confirmed against a local Postgres before this was written: deleting an
-- owner who had minted a pass, and a guest who had redeemed one, both failed
-- with "Database error deleting user". Two tests in `test_rls/rls_test.dart`
-- now cover both sides, alongside the ones `0033` left behind.
--
-- `set null` rather than `cascade`, for the reason `0033` gives at length: the
-- pass belongs to the *vehicle*, not to the person who issued it. Cascading
-- would delete a live pass out from under the person currently driving the
-- car, because the owner closed their account.
--
-- `created_by` becomes nullable to allow it, which no insert notices: the RPC
-- sets it from `auth.uid()`, and a null would fail that check exactly as a
-- wrong id would.

alter table public.vehicle_guest_passes
  drop constraint vehicle_guest_passes_created_by_fkey;

alter table public.vehicle_guest_passes
  alter column created_by drop not null;

alter table public.vehicle_guest_passes
  add constraint vehicle_guest_passes_created_by_fkey
  foreign key (created_by) references auth.users (id) on delete set null;

alter table public.vehicle_guest_passes
  drop constraint vehicle_guest_passes_redeemed_by_fkey;

alter table public.vehicle_guest_passes
  add constraint vehicle_guest_passes_redeemed_by_fkey
  foreign key (redeemed_by) references auth.users (id) on delete set null;

-- A pass whose holder deleted their account is nobody's pass. Leaving
-- `redeemed_at` set while `redeemed_by` is null would read as "somebody has
-- this code" for ever, and `guest_vehicle_ids` matches on `redeemed_by`, so
-- the grant is gone either way — this only stops the owner's list lying about
-- it. The constraint added in 0055 requires the two to move together.
create function public.clear_guest_pass_redemption()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.redeemed_by is null and old.redeemed_by is not null then
    new.redeemed_at := null;
  end if;
  return new;
end;
$$;

create trigger vehicle_guest_passes_clear_redemption
  before update of redeemed_by on public.vehicle_guest_passes
  for each row execute function public.clear_guest_pass_redemption();

-- Authorship cannot be forged on this table either. The update policy lets any
-- member of the garage edit a pass, which is right for revoking one and wrong
-- for rewriting who issued it. `pin_created_by` already allows the single
-- exception `0033` identified: the null that arrives when the user it pointed
-- at has been deleted.
create trigger vehicle_guest_passes_pin_created_by
  before update on public.vehicle_guest_passes
  for each row execute function public.pin_created_by();
