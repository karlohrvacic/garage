-- What the vehicle cost to buy, kept apart from running cost: fuel, service
-- and other spending answer "what does this car cost to run", and folding a
-- one-time capital cost into that would answer a different question under
-- the same name. Nullable, since most households importing history will not
-- know or care to enter it.
alter table public.vehicles
  add column purchase_price numeric(12, 2) check (purchase_price >= 0);
