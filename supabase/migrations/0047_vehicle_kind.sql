-- What kind of vehicle this is, and for a motorcycle, how the rear wheel is
-- driven.
--
-- Nothing broke for a motorcycle before this: it was a vehicle with an
-- odometer. But the app had no idea what it was holding, so it offered a
-- cabin filter, defaulted the oil interval from a car schedule under the same
-- badge, and had no word for a chain. `kind` is what the service-type list
-- and the interval defaults key on; `final_drive` decides whether there is a
-- chain to lubricate. Existing rows are cars, which is what they were.
alter table public.vehicles
  add column kind text not null default 'car'
    check (kind in ('car', 'motorcycle', 'van')),
  add column final_drive text
    check (final_drive is null or final_drive in ('chain', 'belt', 'shaft'));

-- The service items a motorcycle has and a car does not. Intervals are the
-- same kind of generic starting point as every other preset: chain
-- lubrication is a habit measured in hundreds of kilometres, a chain and
-- sprocket set lasts tens of thousands, fork oil and valve clearance are the
-- two-year items most manuals put around 20,000 km. The app offers these only
-- to a vehicle whose kind is motorcycle.
insert into public.service_types
  (household_id, key, default_interval_km, default_interval_months, is_statutory, country_code)
values
  (null, 'service_chain_lube',       1000,  1,    false, null),
  (null, 'service_chain_sprockets',  25000, null, false, null),
  (null, 'service_fork_oil',         20000, 24,   false, null),
  (null, 'service_valve_clearance',  24000, 24,   false, null)
on conflict do nothing;
