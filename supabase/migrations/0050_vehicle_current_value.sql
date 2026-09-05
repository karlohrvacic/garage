-- What the car is worth now, and when somebody last said so.
--
-- Depreciation is the largest cost of owning a car and was absent from every
-- figure this app printed. "€0.31/km to run" is true and incomplete: the same
-- car is nearer €0.44/km to *own*, and that is the number people actually
-- decide on — keep it or sell it, repair it or replace it.
--
-- Hand-entered on purpose. The obvious Croatian signal is Njuškalo listings,
-- and scraping them is fragile, legally awkward, and would put a number the
-- app invented next to numbers the household typed. A figure somebody wrote
-- down themselves is one they already believe, and it gets most of the value
-- with none of that.
--
-- `valued_on` is what keeps it honest: a valuation from three years ago is
-- not today's, and the screen says how old it is rather than quoting it as
-- current.
alter table public.vehicles
  add column current_value numeric(12, 2) check (current_value >= 0),
  add column valued_on date;
