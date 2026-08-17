-- The entry kinds added in August fire webhooks like the three before them.
--
-- Left out of their own migrations by oversight, which is exactly the failure
-- mode a per-table trigger invites: a receiver subscribed to "new entries"
-- would have silently stopped hearing about a third of them. The same applies
-- to realtime, which those migrations did remember.
--
-- Deletes and edits stay out, as before: a receiver that missed one can read
-- the current state from the API, and every extra event is another URL call
-- per user action.

create trigger dispatch_webhook_on_insert
  after insert on public.odometer_entries
  for each row execute function public.dispatch_entry_webhook();

create trigger dispatch_webhook_on_insert
  after insert on public.trip_entries
  for each row execute function public.dispatch_entry_webhook();

create trigger dispatch_webhook_on_insert
  after insert on public.income_entries
  for each row execute function public.dispatch_entry_webhook();
