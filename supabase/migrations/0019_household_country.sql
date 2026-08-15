-- Which country's statutory items a household should be offered.
--
-- The service_types table has carried a country_code since the maintenance
-- schema landed; this is the other half of it. Croatia is the default because
-- it is the market the statutory rows are verified for — a household anywhere
-- else sets its own country and simply sees no statutory presets until rows
-- for that country exist, which is honest rather than wrong.
alter table public.households
  add column country_code text not null default 'HR'
    check (char_length(country_code) = 2);

comment on column public.households.country_code is
  'ISO 3166-1 alpha-2. Selects which statutory service types are offered.';
