-- Which forecourt a fill-up was at, as the price dataset knows it.
--
-- The fill-up sheet now writes the brand into `station` — "INA", "Petrol",
-- "Shell" — because that is what a driver calls the place and what the log
-- reads best as. A brand is not an address: INA runs 389 forecourts, and a
-- name that answers to all of them cannot anchor the cheapest-nearby snapshot
-- (0045) at all, nor be priced unless every one of them charges the same.
--
-- So the sheet also keeps the ministry dataset's own id for the station, when
-- it recognised the forecourt and only then. A station somebody typed has no
-- id, and a station retyped after the sheet filled it in loses the one it had:
-- the id describes the text the sheet wrote, not whatever the text became.
--
-- The dataset's ids are its own, and a forecourt the ministry renumbers or
-- drops leaves a stale one behind. Nothing here can check them, so the app
-- trusts an id only while that station still answers to the entry's text, and
-- falls back to the name as it did before.
--
-- Null on every entry written before this migration and by any build older
-- than it. Row-level policies are unaffected: they grant rows, and a nullable
-- column changes no row a member or a guest could already reach.

alter table public.fuel_entries
  add column station_ref integer check (station_ref > 0);
