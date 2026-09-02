-- What drives the camshaft and what kind of gearbox the car has.
--
-- Neither is knowable from the make: one make sells chains, dry belts and
-- belts-in-oil in the same model year, and the interval for each is
-- different by a factor of "never" to 100,000 km. The reminder sheet uses
-- these to pick a default; nothing else reads them. Null means nobody has
-- said, which is every car that exists today.
alter table public.vehicles
  add column timing_drive text
    check (timing_drive is null or timing_drive in ('belt', 'chain', 'wet_belt')),
  add column transmission text
    check (
      transmission is null
      or transmission in ('manual', 'automatic', 'dct_dry', 'dct_wet', 'cvt')
    );
