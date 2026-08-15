-- Optional depth on a service record, and the household switch that decides
-- how much of it the app asks for.
--
-- Deliberately not a second schema: a beginner and an enthusiast log the same
-- service_entries row, one with more of its columns filled in. The tracking
-- level changes which fields the sheet shows, never where the data lives.
alter table public.households
  add column tracking_level text not null default 'beginner'
    check (tracking_level in ('beginner', 'intermediate', 'advanced'));

alter table public.service_entries
  -- Did the household do it themselves? Splits the cost into what the parts
  -- cost and what the labour did, which is the comparison people want.
  add column diy boolean not null default false,
  add column parts_cost numeric(12, 2) check (parts_cost >= 0),
  add column labor_cost numeric(12, 2) check (labor_cost >= 0),
  -- "Castrol 5W-30, filter W712/95" — what to buy again next time.
  add column parts_detail text,
  add column warranty_until date,
  -- Readings taken during the visit, as {key: number}: brake pad thickness,
  -- tread depth per corner, battery voltage, an oil analysis number. A map
  -- rather than columns, because the useful set differs per household and
  -- adding one should not be a migration.
  add column measurements jsonb;

comment on column public.service_entries.measurements is
  'Numeric readings keyed by measurement id, e.g. {"brake_pad_front_mm": 6.5}';
