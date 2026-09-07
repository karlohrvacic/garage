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
| `guest_vehicle_ids(permission)` | `supabase/migrations/0055_guest_passes.sql:67` | Vehicle ids a **guest pass** currently opens, for one permission |

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

## Guest passes: the second tenancy model

Membership is not the only way to reach a vehicle. A **guest pass**
(`supabase/migrations/0055_guest_passes.sql`) gives somebody scoped, expiring
access to *one* car without joining the garage — lending a friend your Golf, or
renting a car to a customer.

`guest_vehicle_ids(permission)` is the parallel to `user_vehicle_ids()`. It
returns the vehicles the caller may act on right now, for one named permission
(`fuel`, `trips`, `costs`, `history`, or the unconditional `vehicle`), and it
tests the clock itself:

```sql
where redeemed_by = (select auth.uid())
  and revoked_at is null
  and now() < expires_at
  and (starts_at is null or now() >= starts_at)
```

**Expiry therefore needs no scheduled job.** A lapsed pass simply stops granting
anything, and nothing is deleted — which is what makes "what a guest logged
stays with the car" true by construction.

**Every guest policy is additive.** They are new policies added alongside the
member ones, never edits to them. Postgres OR-combines permissive policies, so
an additive policy can only widen access for the rows it names. Teaching
`user_vehicle_ids()` about guests instead would have been three lines and would
have handed every guest everything a member has, including the other cars in the
garage. If you add a table a guest should reach, add a policy; do not touch the
resolver.

The guest policies pair the permission with authorship, so a guest reads and
edits only their own rows:

```sql
using (
  vehicle_id in (select public.guest_vehicle_ids('fuel'))
  and created_by = (select auth.uid())
)
```

The exception is `history`, which is a separate switch on the pass and defaults
to **off**.

**Prices are a second switch, and the reason a function exists.** A pass may
open the history *without* what any of it cost (`can_view_prices`, September
2026, decision 140). Postgres has no column masking, so this cannot be a
narrower row grant: a row a guest may select is a row whose `cost` they may
select. `guest_vehicle_ids('history')` therefore requires prices as well — a
pass that hides them reads **no** entry rows at all — and the history is served
instead by `guest_service_history`
(`supabase/migrations/0064_guest_pass_window_and_prices.sql:70`), a security
definer function that returns the cost as null unless the pass carries it. The
owner calls the same function and sees every figure, so one screen serves both
and there is no guest-only copy to keep in step.

**A pass covers a window.** `starts_at` was nullable from the beginning;
`create_guest_pass_between` is what lets the app say both ends of it. Extending
one is a plain update of `expires_at` under the owner's existing policy — the
holder cannot do it, which the RLS suite checks in both directions.

**Minting and redeeming are RPCs**, not inserts. `create_guest_pass` allocates a
code against every code already outstanding, and refuses a vehicle the caller is
not a member of. `redeem_guest_pass` refuses an unknown, expired, withdrawn or
already-claimed code, and refuses a member of the garage the car belongs to —
who would otherwise end up with two overlapping grants on the same vehicle.
Re-redeeming your *own* pass succeeds, which is how a holder recovers after a
reinstall.

**A pass is never a route to membership.** Redeeming one writes no
`household_members` row, and a guest cannot mint a pass of their own, so a
borrowed car cannot be lent onward.

**Anonymous holders.** Supabase anonymous sign-in produces a real `auth.uid()`,
so an anonymous guest is an ordinary principal here and needs no separate model.
The flag is off (`supabase/config.toml:178`); turning it on is an operational
decision about rate limiting and about accounts nobody can ever sign in as
again, not an architectural one.

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

### A garage is never left without an admin

Creating a garage makes you its admin, and until migration 0056 that was the
only route to the role. So an admin leaving — or deleting their account, which
removes their membership — left the garage intact and **adminless**: cars and
history all present, and nobody who could rename it, remove a member or delete
it. There was no way back, because the only person who could promote the
survivor was the one who had gone.

`ensure_household_has_admin` (`supabase/migrations/0056_admin_succession.sql`)
promotes the **longest-standing remaining member** — earliest `joined_at`, with
`user_id` breaking a tie so the outcome is deterministic. Two triggers call it:
`household_members_succession` after a delete, and
`household_members_succession_on_demote` after a role update, since the grants
let the only admin demote themselves without any new UI.

Two details that matter:

- **It does nothing to an emptied household.** `household_members_cleanup`
  deletes a household whose last member left, and the succession trigger is
  named to sort after it so the cleanup has its say first; the function also
  returns early when no members remain. Promoting somebody in a household
  being torn down would resurrect a row the previous trigger just deleted.
- **The migration backfills.** Households stranded before this shipped cannot
  recover on their own — no future event fires for them — so the migration
  promotes an admin in each one as it applies.

Not automatic: making a *second* admin. That stays a deliberate act, and the
succession only ever fires when the count would otherwise be zero.

### Roles, and merging two garages

Roles are `admin` and `member`, and until migration 0058 the role could never
change: there was no update policy on `household_members`, so the creator was
the permanent sole admin. `members_update_by_admin` now lets an admin promote
and demote, which is what makes two parents plus a member-only teenager
possible. A demotion that would empty the garage of admins is caught by the
succession rule (decision 112), which excludes whoever just stepped down.

`merge_households` (`supabase/migrations/0057_merge_households.sql`) empties one
garage into another and deletes it, in one transaction, for a caller who is an
admin of **both**. It refuses a currency mismatch outright: amounts are bare
numbers and the currency lives on the garage, so merging across them would
reinterpret every figure in the absorbed garage's history.

Order inside it is load-bearing. Vehicles move first, carrying everything keyed
to a vehicle. Members are copied next, keeping their roles, or the history
arrives with its authorship unreadable. Custom service types follow, minus key
collisions. Only then is the absorbed garage deleted, and the cascade takes its
invites, transfer offers, API keys and webhooks with it — keys are revoked
rather than moved on purpose, because a key minted for one garage must not come
to read the combined one.

Vehicle photos cannot be handled in SQL: they live under the garage's storage
prefix. The app copies them into the survivor's prefix **before** calling the
RPC, while it is still a member of both. See decision 114.

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
both come from it — but cannot change it. Your own is yours to change
(`profiles_update` is `user_id = auth.uid()`), and doing so writes **twice**:
the auth user's metadata, which is where a device reads its own name from, and
the `profiles` row, which is what everyone else sees against the entries you
logged (`lib/features/auth/data/supabase_auth_repository.dart:109`). Writing one
and not the other leaves a garage where you are called two different things, so
the metadata goes first and a failure there stops before the two can disagree. `webhook_dispatch_config` has no test
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
