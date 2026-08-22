-- Provenance hardening, part two.
--
-- 0008 pinned `created_by` against a crafted UPDATE on the three tables that
-- existed at the time — an RLS `with check` cannot see the old row, so
-- nothing else stopped a household member rewriting who an entry is
-- attributed to. Every table added since that carries a `created_by` column
-- (costs, tyres, trips, income, odometer readings, API keys, webhooks) has
-- the same update-scoped-by-something-else policy shape, and never got the
-- same trigger. `reminder_rules` has no `created_by` column, so it is not
-- in this list — there is nothing on it to forge. `pin_created_by()` is
-- generic — reused as-is, not redefined.
create trigger cost_entries_pin_created_by
  before update on public.cost_entries
  for each row execute function public.pin_created_by();

create trigger tyre_sets_pin_created_by
  before update on public.tyre_sets
  for each row execute function public.pin_created_by();

create trigger trip_entries_pin_created_by
  before update on public.trip_entries
  for each row execute function public.pin_created_by();

create trigger income_entries_pin_created_by
  before update on public.income_entries
  for each row execute function public.pin_created_by();

create trigger odometer_entries_pin_created_by
  before update on public.odometer_entries
  for each row execute function public.pin_created_by();

create trigger api_keys_pin_created_by
  before update on public.api_keys
  for each row execute function public.pin_created_by();

create trigger webhooks_pin_created_by
  before update on public.webhooks
  for each row execute function public.pin_created_by();
