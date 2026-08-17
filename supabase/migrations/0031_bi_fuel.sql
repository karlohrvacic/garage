-- A car that runs on two fuels.
--
-- Until now `FuelEconomy.compute` treated every fill as the same fuel, so a
-- car alternating petrol and LPG averaged the two together into a figure that
-- was neither. Recorded as a known bug since the first release.
--
-- Two columns close it. A vehicle may name a second fuel it takes, and a
-- fill-up may name which of them went in. Both are nullable, and null keeps
-- meaning exactly what it meant before: one fuel, no question to ask.

alter table public.vehicles
  add column secondary_fuel_type_key text
    check (secondary_fuel_type_key is null
           or secondary_fuel_type_key ~ '^[a-z0-9_]+$');

-- A second fuel that is the same as the first is not a second fuel.
alter table public.vehicles
  add constraint vehicles_second_fuel_differs
    check (secondary_fuel_type_key is null
           or secondary_fuel_type_key <> fuel_type_key);

alter table public.fuel_entries
  add column fuel_type_key text
    check (fuel_type_key is null or fuel_type_key ~ '^[a-z0-9_]+$');

-- Read on every economy computation for a bi-fuel car, alongside the odometer
-- ordering the existing index already covers.
create index fuel_entries_vehicle_fuel_idx
  on public.fuel_entries (vehicle_id, fuel_type_key)
  where fuel_type_key is not null;
