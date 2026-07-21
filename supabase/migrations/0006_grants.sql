-- Table-level privileges for the `authenticated` role.
--
-- RLS decides *which rows* a signed-in user may touch; a GRANT decides whether
-- the role may touch the table at all. Both are required — RLS on a table the
-- role has no privilege on just yields "permission denied" before any policy is
-- evaluated. Supabase's default privileges are meant to grant these
-- automatically to objects the `postgres` role creates in `public`, but relying
-- on that timing is fragile (and did not hold on a fresh local reset), so we
-- state the grants explicitly. `anon` is intentionally granted nothing: every
-- policy in this schema is `to authenticated`.
grant select, insert, update, delete on public.households to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.household_members to authenticated;
grant select, insert, update, delete on public.invites to authenticated;
grant select, insert, update, delete on public.vehicles to authenticated;
grant select, insert, update, delete on public.fuel_entries to authenticated;
grant select, insert, update, delete on public.service_types to authenticated;
grant select, insert, update, delete on public.reminder_rules to authenticated;
grant select, insert, update, delete on public.service_entries to authenticated;
