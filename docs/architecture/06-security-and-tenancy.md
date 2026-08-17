# 06. Security and tenancy

How one household is kept out of another's data, and what "admin" means.
Siblings: [02-domain-model.md](02-domain-model.md) for the tables,
[05-data-access-and-sync.md](05-data-access-and-sync.md) for the client side,
[07-integrations.md](07-integrations.md) for the outward-facing surfaces.

> Jump to [Sharp edges](#sharp-edges): the RLS suite cannot run in CI, a deny
> test passes even when the policy denies everyone, and storage tenancy is a
> string prefix.

## Why this exists, and why it is built this way

The client is not trusted. A Flutter app ships to a device, its anon key is
public, and anyone can call the REST endpoint directly. So the sharing rule is
enforced in Postgres, where it cannot be bypassed by a modified client, a curl
command, or a bug in a screen.

Every table has row-level security on, and almost every policy reduces to the same
question: *does this row belong to a household I am a member of?*

## The two functions everything leans on

| Function | Defined at | Returns |
|---|---|---|
| `user_household_ids()` | `supabase/migrations/0001_households.sql:42` | Household ids the caller belongs to |
| `user_vehicle_ids()` | `supabase/migrations/0003_vehicles.sql:23` | Vehicle ids in those households |

Both are `security definer` and both are revoked from `public` and granted only to
`authenticated` (`supabase/migrations/0003_vehicles.sql:34`). Definer is required
because the policy on `household_members` would otherwise recurse into itself
while trying to answer whether you may read `household_members`.

A typical policy is then a one-liner
(`supabase/migrations/0003_vehicles.sql:41`):

```sql
using (household_id in (select public.user_household_ids()))
```

Entry tables key on the vehicle instead
(`supabase/migrations/0004_fuel.sql:39`), which chains to the same place.

## Roles and admin actions

`household_members.role` is `admin` or `member`. The creator of a household is its
admin; anyone joining by code is a member, and the RLS suite asserts that an
invite never confers admin.

`is_household_admin()` (`supabase/migrations/0020_admin_actions.sql:11`) gates the
destructive actions:

| Action | Who |
|---|---|
| Delete a vehicle, and its history by cascade | Admin only (`0020_admin_actions.sql:28`) |
| Remove another member | Admin only |
| Leave the household yourself | Anyone, for their own row |
| Everything else | Any member |

## Invites

Codes are 8 characters from an alphabet that excludes visually ambiguous
characters (`supabase/migrations/0002_invites.sql:34`), because they get read
aloud and typed by hand.

A joiner never selects from `invites`. They call
`join_household_with_code`, a definer function, so codes cannot be enumerated by
querying the table. The household that issued a code can list and delete its own
(`supabase/migrations/0002_invites.sql:20` and `:24`), which is what the invite
management UI uses.

A code is consumed **only by a join that actually adds a member**
(`supabase/migrations/0010_join_keeps_unused_invites.sql:1`). Re-entering your own
code no-ops instead of burning an invite the household meant for someone else.

## Belonging to several garages

`household_members` has always been keyed on `(household_id, user_id)`, so
several memberships were always legal. What was missing was a client that could
show more than one. `selectedHouseholdIdProvider`
(`lib/features/household/providers/current_household.dart:15`) holds which one
this **device** is showing — a device property, not an account one, so switching
on a laptop does not yank the phone in somebody's pocket to a different garage.

Nothing about tenancy changed: every policy still asks whether the caller is a
member of the row's household, and the app showing one garage at a time is a
presentation choice on top of that.

## Vehicle transfer

`redeem_vehicle_transfer` (`supabase/migrations/0030_vehicle_transfer.sql:118`)
moves a vehicle to another garage by changing one column. Everything else —
fill-ups, services, costs, readings, trips, income, attachments — hangs off
`vehicle_id` and follows without being touched, and the seller loses access
because RLS is scoped to the household.

The definer function does its own validating, and there are four checks rather
than one:

| Check | What it stops |
|---|---|
| destination is a household the caller belongs to | putting a car in a garage you are not in |
| code is unredeemed and unexpired | a code circulating forever |
| vehicle is *still* in the offering household | an old code claiming a car twice |
| destination is not the offering household | a no-op that looks like a transfer |

**The photo does not follow.** `vehicle-photos` objects are keyed
`<household_id>/<vehicle_id>` and SQL cannot move a storage object, so
`photo_path` is cleared. Attachments are keyed by `<vehicle_id>` alone
(`supabase/migrations/0016_attachments.sql:56`) and do follow — which is the
argument for that key, discovered the hard way here.

## API keys and webhooks

A key is shown once and stored as a SHA-256 hash
(`lib/domain/api/api_key.dart:32`), with a short preview kept for recognition
(`api_key.dart:36`). The database never holds anything that can be replayed.
Resolution happens server side in `household_for_api_key`
(`supabase/migrations/0017_public_api.sql:92`).

Webhook delivery is triggered from the database itself, see
[07-integrations.md](07-integrations.md). Its configuration table has RLS on with
**no policy at all** (`supabase/migrations/0025_webhook_dispatch_config.sql:30`),
so no signed-in user can read the token it holds: it is operator configuration,
not household data.

## Storage

Two private buckets, `attachments` and `vehicle-photos`. Every read goes through a
signed URL, so a file cannot be fetched by guessing its path
(`supabase/migrations/0016_attachments.sql:48`).

Tenancy is enforced on the **first path segment**: the policies compare
`(storage.foldername(name))[1]` against the caller's household ids
(`supabase/migrations/0008_harden.sql:39`,
`supabase/migrations/0016_attachments.sql:62`). That is why
`VehiclePhotos.pathFor` puts the household first
(`lib/features/vehicles/data/vehicle_photo_repository.dart:10`).

## Account deletion

The `delete-account` edge function removes the user and, when they were the last
member of a household, that household and everything cascading from it. It exists
because Play requires an in-app deletion path, and because GDPR erasure has to be
real rather than a support request.

**Entries survive their author.** Every `created_by` is `on delete set null`
(`supabase/migrations/0033_account_deletion_unblocked.sql:39`), not `cascade`:
the log belongs to the household, and a member leaving must not take half of it
with them. Attribution is what is lost, which is the part that stops being true
anyway.

This is also where the schema is at its most delicate, and it is worth knowing
why before touching either piece:

| Mechanism | What it does | Why the other one nearly broke it |
|---|---|---|
| `pin_created_by` (`0008`) | Reverts any update of `created_by`, so a crafted client cannot forge authorship | `on delete set null` **is** an update — the trigger reverted it, the delete reported success, and a dangling reference was left behind |
| `on delete set null` (`0033`) | Lets a user be deleted without destroying the household's history | Needed the trigger to permit exactly one case: nulling an author who no longer exists |

The trigger is `security definer` because it reads `auth.users`, which
`authenticated` cannot select from — without that, every ordinary edit of a
fill-up fails with "permission denied for table users". That was found by the
regression test, not by reading the code.

## Testing this

`test_rls/rls_test.dart` is the only thing that proves any of the above. It runs
against a real Postgres under `dart test`, not the Flutter test runner:

```bash
supabase start && supabase db reset
SUPABASE_URL=… SUPABASE_ANON_KEY=… dart test test_rls/rls_test.dart
```

CI runs it too, in the `rls` job of `.github/workflows/ci.yml`, which stands up a
throwaway stack with `supabase start`. `deploy-web.yml` calls that workflow and
waits on it, so garage.hrva.cc cannot go out over a tenancy regression. Running it
locally is still worth it before pushing a migration, because the CI job is where
you find out five minutes later.

Every table with policies has a case, and two are worth knowing because they run
in opposite directions. **`device_tokens` is scoped to a person, not a
household**: a fellow member who can see every car in the garage still cannot
read another member's push token, or a garage would be able to push to its
members' phones. **`profiles` is deliberately shared**: a member can read a
co-member's display name, because the member list and the author of every entry
both come from it — but cannot change it. `webhook_dispatch_config` has no test
and no policy on purpose; RLS is on, the grants are revoked, and only the
definer-context dispatcher reads it.

Three users exist for a reason recorded at `test_rls/rls_test.dart:9`: Alice owns
the household, Bob is the invitee who deliberately becomes a member, and **Carol
never joins anything**. Carol is the stranger every "cannot" is measured against.
Before she existed the suite used Bob throughout, and a mid-file test made him a
member, so every later isolation assertion was quietly measuring a member and
proving nothing.

## Sharp edges

- **A deny-only test proves nothing.** "Stranger sees no rows" also passes when a
  policy denies everyone, including members. Every table's tests therefore include
  a positive control (a member *can* read and write). Add one for any new table.
- **The suite must be re-runnable against a database it does not own.** It signs
  up fresh users each run, but anything inserted under a *natural* primary key
  collides with the row the last run left behind — and because that row belongs
  to a different user, RLS refuses the write and the failure reads like a policy
  bug. `device_tokens` is the case that caught this: its token is the key, so the
  test derives one from the user's id.
- **A table with policies and no test is the normal way this decays.** Policies
  are written with the migration and the test is a separate file, so the two
  drift silently. `service_entries`, `tyre_readings`, `device_tokens` and
  `profiles` all sat that way until August 2026.
- **Storage tenancy is a string prefix.** A path assembled without the household
  segment lands somewhere the policy will refuse, and the failure surfaces as a
  generic upload error rather than "you built the path wrong".
- **The anon key is public and that is fine.** It appears in the web bundle and in
  `env/*.json`. It grants nothing on its own; RLS does the work. The service role
  key is the one that must never leave the server.
- **Definer functions bypass RLS by design.** Anything marked `security definer`
  must validate its own inputs, which is why `create_invite` checks membership
  before minting (`supabase/migrations/0002_invites.sql:55`).
- **A trigger can silently defeat a referential action.** `on delete set null`
  is an UPDATE, so a `before update` trigger sees it and can overrule it — and
  the delete still reports success. If you add a trigger that rewrites a column,
  check what foreign keys do to that column.
- **A transfer is irreversible from the seller's side.** Once redeemed, only the
  new owner can send the car back. The UI confirms before minting a code, which
  is the last point at which anything can be stopped.
