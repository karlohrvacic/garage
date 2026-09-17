-- A borrower is told about the car, not handed its row.
--
-- 0055 let a pass holder select the lent vehicle's row, because a guest has
-- to see what they are logging against. A policy grants rows, never columns,
-- and the row already carried what the owner paid for the car (0039) and
-- what they think it is worth (0050), so a borrower could read both from the
-- day lending shipped. The app never shows either to a borrower; a
-- borrower's own token asked PostgREST for `vehicles?select=*` and read both.
--
-- So the table is closed to borrowers and this function answers instead,
-- with the columns a borrower's app needs and nothing else. The list is an
-- allowlist on purpose: a column added later is withheld until somebody
-- decides otherwise, and `test/ci/guest_vehicle_columns_test.dart` fails the
-- build until they do.
--
-- Withheld, and why:
--   purchase_price, current_value, valued_on — the owner's money.
--   photo_path — the photo sits under the owner's storage prefix, which a
--     borrower cannot read (0003), so the path would only be a broken image.
--   created_by — who in the garage added the car is the garage's business.
--
-- A car the caller can already see as a member is left out: it is theirs, and
-- the app reads it from the table like any other.
--
-- An app build older than this reads borrowed cars from the table and finds
-- none, so a borrower on it sees no borrowed car until they update. Nothing
-- they logged is affected.

drop policy vehicles_select_guest on public.vehicles;

create function public.guest_vehicles()
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', v.id,
    'household_id', v.household_id,
    'nickname', v.nickname,
    'kind', v.kind,
    'make', v.make,
    'model', v.model,
    'year', v.year,
    'trim', v.trim,
    'vin', v.vin,
    'plate', v.plate,
    'fuel_type_key', v.fuel_type_key,
    'secondary_fuel_type_key', v.secondary_fuel_type_key,
    'tank_capacity_l', v.tank_capacity_l,
    'timing_drive', v.timing_drive,
    'transmission', v.transmission,
    'final_drive', v.final_drive,
    'baseline_odometer_km', v.baseline_odometer_km,
    'baseline_date', v.baseline_date,
    'archived', v.archived,
    'created_at', v.created_at
  )
  from public.vehicles v
  where v.id in (select public.guest_vehicle_ids('vehicle'))
    and v.household_id not in (select public.user_household_ids())
  order by v.nickname
$$;

revoke execute on function public.guest_vehicles() from public;
grant execute on function public.guest_vehicles() to authenticated;
