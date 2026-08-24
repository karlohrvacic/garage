-- Rubber perishes on a schedule of its own. A set can be legal on tread and
-- long past it on age, and nothing in the app could say so because nothing
-- recorded when the tyres were made.
--
-- Stored as a date rather than the raw DOT code. The code on the sidewall is
-- four digits — `3419` is week 34 of 2019 — which is an input format, not a
-- storage one: a date sorts, subtracts and serialises like every other date in
-- this schema, and the week is recoverable from it. Parsed at the edge, kept
-- canonical here, the same rule the units follow.
--
-- Nullable, and expected to stay null for most sets: it means "nobody has read
-- the sidewall", not "new". The app falls back to `fitted_at` and says the age
-- is an estimate, because a set fitted in 2020 may well have been made in 2016
-- and the fallback errs in the direction that keeps quiet.
alter table public.tyre_sets
  add column if not exists manufactured_on date;

comment on column public.tyre_sets.manufactured_on is
  'From the DOT code on the sidewall: the Monday of that week. Null means '
  'unread, not new.';
