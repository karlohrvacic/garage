-- Realtime only broadcasts tables in this publication. RLS still applies to
-- the stream, so a member never receives another household's changes.
alter publication supabase_realtime add table public.vehicles;
alter publication supabase_realtime add table public.fuel_entries;
alter publication supabase_realtime add table public.service_entries;
alter publication supabase_realtime add table public.reminder_rules;
