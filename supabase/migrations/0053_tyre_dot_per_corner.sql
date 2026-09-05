-- A set of four tyres has four DOT codes, and often four different ones.
--
-- `0043` added one `manufactured_on` for the whole set, which is right for a
-- set bought together and wrong for most sets that are not: a pair replaced
-- after a kerb, a spare rotated in, or four bought from a dealer's shelf in
-- whatever order they had been sitting there. Reported from the field by a
-- household whose four codes are all different.
--
-- Per corner, matching `tyre_readings`, which has measured tread per corner
-- since `0023`. A motorcycle uses the two left columns, the same convention
-- decision 88 set for its tread.
alter table public.tyre_sets
  add column manufactured_front_left date,
  add column manufactured_front_right date,
  add column manufactured_rear_left date,
  add column manufactured_rear_right date;

-- What the household already told us, applied where they meant it.
--
-- The old field asked one question about the whole set, so its answer is an
-- answer about the whole set: a household that typed 2019 there was saying
-- these tyres were made in 2019, not that the front-left one was.
update public.tyre_sets
set manufactured_front_left = manufactured_on,
    manufactured_front_right = manufactured_on,
    manufactured_rear_left = manufactured_on,
    manufactured_rear_right = manufactured_on
where manufactured_on is not null;

-- `manufactured_on` is deliberately **not** dropped.
--
-- Migrations apply on a push to `main`; a household on last week's APK does
-- not. Dropping the column would make that build's `updateSet` fail against a
-- column PostgREST no longer knows, so editing a tyre set would break for
-- everyone who had not updated — and silently, since the app would report
-- only a generic write failure.
--
-- It stays as the compatibility field: new builds keep it in step with the
-- corners (set to the *oldest* of them, which is the figure an older build
-- should be showing anyway, since a set is as old as its oldest tyre) and
-- read it only when no corner is known.
comment on column public.tyre_sets.manufactured_on is
  'Legacy set-wide DOT date. Kept in step with the oldest of the four '
  'manufactured_* columns for builds that predate 0053; new code reads the '
  'corners.';
