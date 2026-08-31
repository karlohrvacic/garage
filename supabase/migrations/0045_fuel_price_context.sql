-- What the market looked like on the day of a fill-up.
--
-- The MINGOR dataset is fetched live and kept nowhere, so the moment a
-- fill-up is saved the surrounding prices are gone for good. That makes
-- "did I pay over the odds?" unanswerable retrospectively, however long the
-- app has been in use. These columns close that door before more history
-- accumulates behind it.
--
-- Written once, when the entry is created, and never on an edit: re-reading
-- today's market onto an old fill-up would overwrite what was true then.
-- Null on every entry written before this migration, and on any entry whose
-- station name the dataset does not carry, which stays the ordinary case
-- outside Croatia.

alter table public.fuel_entries
  add column cheapest_nearby_price numeric(10, 4)
    check (cheapest_nearby_price is null or cheapest_nearby_price > 0);

alter table public.fuel_entries
  add column cheapest_nearby_km numeric(6, 2)
    check (cheapest_nearby_km is null or cheapest_nearby_km >= 0);

alter table public.fuel_entries
  add column cheapest_nearby_station text;

-- The feed carries no timestamp of its own, so without recording when the
-- prices were read there is no way to tell a same-day snapshot from one taken
-- a week after the fill-up it describes.
alter table public.fuel_entries
  add column prices_seen_on date;

-- All four arrive together or not at all: a price with no date it was seen on
-- is a number nobody can interpret later.
alter table public.fuel_entries
  add constraint fuel_entries_price_context_complete
    check (
      (cheapest_nearby_price is null
       and cheapest_nearby_km is null
       and cheapest_nearby_station is null
       and prices_seen_on is null)
      or
      (cheapest_nearby_price is not null
       and cheapest_nearby_km is not null
       and cheapest_nearby_station is not null
       and prices_seen_on is not null)
    );
