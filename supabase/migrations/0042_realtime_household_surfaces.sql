-- Two things, both about the realtime stream telling a second device the
-- truth.

-- 1. Revoking reaches the other device.
--
-- A code revoked on a laptop still read as live on a phone until that screen
-- was revisited by hand, which for an invite is exactly backwards: revoking is
-- the urgent half of issuing, and the reason to do it is usually that the code
-- got somewhere it should not have. The same for an API key.
--
-- RLS still applies to the stream, so a member never receives another
-- household's rows.
alter publication supabase_realtime add table public.invites;
alter publication supabase_realtime add table public.api_keys;
alter publication supabase_realtime add table public.webhooks;

-- Revocation is what these three are subscribed for, and a revoke is a DELETE
-- on `invites` and an UPDATE on the other two. Without FULL the old tuple of a
-- delete carries only the primary key, and the client cannot tell which
-- household it belonged to.
alter table public.invites replica identity full;
alter table public.api_keys replica identity full;
alter table public.webhooks replica identity full;

-- 2. The delete half of four entry kinds never worked.
--
-- `0007` set FULL replica identity on the three tables in the publication at
-- the time, and said why: a DELETE's old row otherwise carries only the
-- primary key, so the client cannot read `vehicle_id` to know which provider
-- to refresh. Four more entry kinds were added to the publication afterwards —
-- `cost_entries` in `0012`, `odometer_entries` in `0028`, `trip_entries` and
-- `income_entries` in `0029` — and none of them repeated it.
--
-- `_vehicleIdFrom` (`lib/core/sync/realtime_sync.dart`) falls back to
-- `oldRecord['vehicle_id']` for exactly this case and was getting null, so the
-- callback returned without invalidating anything: deleting a cost, a trip, an
-- income entry or a bare reading on one device left it on screen on every
-- other device until that list was reloaded by hand. Inserts and updates were
-- fine throughout, which is what made it look like realtime worked.
--
-- Silent in the same way the doc warns about: nothing errors, the row simply
-- stays.
alter table public.cost_entries replica identity full;
alter table public.odometer_entries replica identity full;
alter table public.trip_entries replica identity full;
alter table public.income_entries replica identity full;

-- Already in the publication and deliberately left alone: `vehicles`, whose
-- primary key *is* the id the client refreshes on, and `attachments` and
-- `tyre_sets`, which nothing subscribes to yet.
