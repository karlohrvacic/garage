-- A pass revoked on one device should stop reading as live on another.
--
-- `invites` was published for exactly this reason (0042): "a code revoked on a
-- laptop still read as live on a phone until that screen was reopened, which is
-- backwards for the half of issuing you do because the code reached somebody it
-- should not have." A guest pass is the same object with a car attached, and
-- was classified as not-live on the reasoning that the *holder* is not in the
-- household to be told — which is true, and beside the point: the screen that
-- lists passes belongs to the owner, and a garage can have two admins.
alter publication supabase_realtime add table public.vehicle_guest_passes;

-- Full replica identity, so a revocation that deletes rather than updates
-- still carries the vehicle it belonged to. See 0007_realtime.sql.
alter table public.vehicle_guest_passes replica identity full;
