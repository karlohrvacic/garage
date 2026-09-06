-- Two tables shipped without realtime, and nothing said so.
--
-- `realtime_sync.dart` carries a comment predicting exactly this: "the
-- repetition was what made three entry kinds get added without anyone noticing
-- this file". Observations and routes were the eighth and ninth.
--
-- What it looked like: one member records "rattles at the front when cold" and
-- the other's vehicle page does not show it until they reopen the app. In a
-- garage shared between two people that is the feature not working, and it
-- fails silently — everything else on the screen is live.
alter publication supabase_realtime add table public.observations;
alter publication supabase_realtime add table public.routes;

-- Full replica identity, for the reason `0007_realtime.sql` gives: without it
-- a DELETE's old tuple carries only the primary key, so the callback cannot
-- read `vehicle_id` (or `household_id`) and returns without invalidating
-- anything. Inserts and updates work regardless, which is what lets the gap
-- survive — realtime looks like it works right up until somebody deletes
-- something.
alter table public.observations replica identity full;
alter table public.routes replica identity full;
