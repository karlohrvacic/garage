-- The date a one-time reminder's cycle actually started, as opposed to
-- `created_at`, which is only when the row was written. Those two are the
-- same moment only when a payment is logged the day it happened; a
-- backdated entry (last month's premium, typed in today) made a one-time
-- reminder read as barely begun instead of most of the way through its
-- year, because the projector had no real anchor to fall back to and used
-- the row's insert time instead.
alter table public.reminder_rules
  add column issued_date date;
