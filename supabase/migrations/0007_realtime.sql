-- Realtime only broadcasts tables in this publication. RLS still applies to
-- the stream, so a member never receives another household's changes.
alter publication supabase_realtime add table public.vehicles;
alter publication supabase_realtime add table public.fuel_entries;
alter publication supabase_realtime add table public.service_entries;
alter publication supabase_realtime add table public.reminder_rules;

-- A DELETE event's old row otherwise carries only the primary key, so the
-- client could not read `vehicle_id` to know which provider to refresh. FULL
-- replica identity includes every column in the old row, so a delete on another
-- device invalidates the right data here.
alter table public.fuel_entries replica identity full;
alter table public.service_entries replica identity full;
alter table public.reminder_rules replica identity full;
