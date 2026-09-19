# 05. Data access, state, and sync

How a screen gets data, how two phones stay in agreement, and where units are
converted. Siblings: [01-system-overview.md](01-system-overview.md) for the
layers, [09-errors-and-diagnostics.md](09-errors-and-diagnostics.md) for what
happens when a call fails.

> Jump to [Sharp edges](#sharp-edges): realtime now covers every table a second
> member can change — and the ones it deliberately skips are written down —
> invalidation needs `replica identity full` to work on deletes, and a
> provider that reaches for Supabase directly will break every widget test.

## Why this exists, and why it is built this way

Two constraints drove the shape:

**Tests must not touch a network.** Widget tests run in seconds because every
screen depends on a repository *interface*, and the test hands it a fake. Nothing
in `lib/features/*/screens/` knows Supabase exists.

**Two people share one car.** A fill-up logged on one phone has to appear on the
other without a pull-to-refresh, or the app is just a diary that happens to sync.

## The seam

Every feature repeats the same four-part structure. Using fuel as the example:

| File | Role |
|---|---|
| `lib/features/fuel/data/fuel_repository.dart` | The interface. Domain types in, domain types out |
| `lib/features/fuel/data/supabase_fuel_repository.dart` | The only file that knows about tables and columns |
| `lib/features/fuel/providers/fuel_providers.dart` | Providers, including derived state such as economy |
| `lib/features/fuel/screens/`, `widgets/` | Read providers; never a client |

There are 24 files under `lib/features/*/data/`, which is the interface plus
implementation for roughly a dozen repositories.

Platform capabilities follow the same rule. A widget that needs to open a URL, pick
a file, or upload a photo goes through a provider seam in `lib/core/`
(`lib/core/links/url_opener.dart:14`, `lib/core/files/file_picker.dart:9`), so the
test substitutes a recorder for the browser or the picker. Adding a plugin call
directly inside a widget is the one pattern that reliably makes a screen
untestable.

Row mapping stays in the data layer as free functions, for example
`inviteFromRow` and `householdMemberFromRow` in
`lib/features/household/data/supabase_household_repository.dart`. They are plain
functions over a map, so the mapping is unit-tested without a database.

## Sync

`realtimeSyncProvider` (`lib/core/sync/realtime_sync.dart:17`) opens one Supabase
channel and, on any change, **invalidates the affected provider** rather than
merging the payload into local state.

That choice is deliberate and documented at `lib/core/sync/realtime_sync.dart:12`:
refetching is cheap at household data volumes and cannot drift out of step with
what the server actually holds, whereas a local merge is a second copy of the
truth that can disagree with the first. Last write wins, which suits a household
where two people rarely edit the same row in the same second.

Subscribed tables, from `supabase/migrations/0007_realtime.sql:3` and the
migrations that have added to the publication since:

| Table | Invalidates |
|---|---|
| `vehicles` | `garageBootstrapProvider` |
| `fuel_entries` | `rawFuelEntriesProvider(vehicleId)` |
| `service_entries` | `serviceEntriesProvider(vehicleId)` |
| `cost_entries` | `costEntriesProvider(vehicleId)` |
| `reminder_rules` | maintenance providers |
| `vehicle_documents` | `vehicleDocumentsProvider(vehicleId)` |
| `odometer_entries`, `trip_entries`, `income_entries` | the provider for each kind |
| `observations` | `observationsProvider(vehicleId)` |
| `routes` | `routesProvider` (household-wide, like invites and API keys) |
| `invites`, `api_keys`, `webhooks`, `vehicle_transfers` | their own providers |
| `vehicle_guest_passes` | `vehicleGuestPassesProvider(vehicleId)`, and the holder's own list |

**Every table in the schema is now either subscribed or listed as deliberately
not**, in `test/ci/realtime_replica_identity_test.dart` with a reason beside
each. That list exists because observations and routes shipped without realtime
and nothing said so: a note recorded on one phone did not reach the other until
the app was reopened, while every other card on the same screen was live
(migration `0062_realtime_observations_routes.sql:11`).

RLS still applies to the stream (`supabase/migrations/0007_realtime.sql:1`), so a
member never receives another household's changes. Realtime is not a hole in the
tenancy model.

## Writing without a signal

Every write used to go straight to Supabase, and a fill-up is typed at a pump —
which is exactly where a phone has one bar and a canopy overhead. A failed
write showed a message and kept the sheet open; nothing was kept.

`QueueingFuelRepository` and `QueueingOdometerRepository`
(`lib/core/sync/queueing_repositories.dart`) wrap the Supabase repositories.
**Nothing above the data layer knows.** Screens already read providers over a
repository *interface*, so the sheets did not change: the entry saves, the
sheet closes, and it is right to.

**Only two failures queue** (`lib/core/sync/pending_write.dart:164`): `network`
and `timeout`. Everything else is the server answering — a refusal, a bad
value — and queueing those would turn a message somebody could act on into an
entry that never arrives. `timeout` queues even though the write may have
landed, which is safe for the same reason the whole design is: the entry
carries its own id, minted by the sheet, so a replay is the same row.

**What comes back off the queue** (`:178`):

| Result | Meaning |
|---|---|
| `network`, `timeout` | Still nothing to send to. Keep it. |
| `conflict` | It landed after the app stopped waiting. The row exists, once. |
| `permission`, `auth`, `notFound`, `invalid` | It can never succeed — the car moved garages, the session is gone. Drop it and say so. |

That last row is what stops a queue becoming a bug that grinds a battery flat
on a write nothing will ever accept.

**Replay** (`lib/core/sync/replay.dart:40`) runs at launch, on app resume, and
from a button — no timer and no background isolate. It sends oldest first and
**stops at the first connection failure**: there is one network, and if the
first write cannot reach the server neither can the next twenty. It also holds
its own guard against overlapping runs, because the triggers overlap by design.

**Reads are cached, since September 2026.** `ReadCache`
(`lib/core/sync/read_cache.dart`) sits inside each Supabase repository's list
read: a successful query's rows are kept as JSON in the device's preferences,
keyed by user and by list (`fuel/<vehicle>`, `members/<household>`), and the
next query that fails with `network` or `timeout` — the same two kinds the
write queue keeps — gets the copy back and marks the key stale. Parsing stays
in the one `fromRow` per table, as the startup cache required (decision 126).
Any other failure is the server answering and is thrown as before, copy or
no copy. `test/ci/read_cache_coverage_test.dart` fails a Supabase list read
that does not go through it, unless it is named there with a reason. Each
query handed in ends with `.retry(enabled: false)`, which
`test/ci/read_cache_no_retry_test.dart` requires: the client's own three
retries with backoff would otherwise hold the copy back seven seconds with no
signal, and online the next read or the banner's Retry is the retry.

A copy never expires; it is labelled instead. `StaleReadsBanner`
(`lib/core/widgets/stale_reads_banner.dart`) sits at the top of both
scaffolds, with Retry. Retry, resume and a replay clear every mark and
refetch every covered list (`invalidateReads`,
`lib/core/sync/invalidate_reads.dart`); a list still served from a copy marks
itself again, so the banner names the oldest copy of what is being shown.
What a queued entry gets is still a **merge into the read**, deduped on its
own id — a cached read now as much as a fresh one, since the queue decorator
wraps the repository the cache lives in. Sign-out and account deletion clear
the copies with the startup cache. Decision 182 records what this reverses of
decision 115.

**Photos** are kept in the app's own directory and uploaded after their entry.
`QueuedFileStore` is a seam (`lib/core/sync/queued_files.dart`) with a
conditional import, the pattern `backup_folder.dart` established: `dart:io`
must never reach the web compiler, and only `flutter build web` catches it when
it does. On the web there is nowhere private to keep a file, so the photo is
refused with the original failure while the entry still queues.

### The delete detail

Every table the client subscribes to is set to `replica identity full`
(`supabase/migrations/0007_realtime.sql:11` for the first three,
`supabase/migrations/0042_realtime_household_surfaces.sql` for the rest).
Without it a DELETE event carries only the primary key, so the client cannot
read `vehicle_id` to know which provider to invalidate, and a deletion on one
phone leaves a ghost row on the other.

**This was got wrong for four entry kinds and stayed wrong for a long time.**
`0007` set it on the three tables published at the time; costs, readings, trips
and income were published later and none repeated it. Inserts and updates
worked throughout — their payload carries the new row — so realtime looked
healthy while only the delete half was broken, and the symptom was a row that
was still there.

`test/ci/realtime_replica_identity_test.dart` now reads the subscribed tables
out of `realtime_sync.dart` and asserts each is published and carries FULL.
`vehicles` is the one exemption: a delete there sends the primary key, and the
primary key is the id the client refreshes on.

## Units

Storage is canonical: **kilometres, litres, and the household's currency**.
`lib/core/format/unit_format.dart:20` converts at the presentation boundary and
nowhere else.

| Preference | Values |
|---|---|
| `DistanceUnit` | `km`, `mi` |
| `VolumeUnit` | `liter`, `usGallon`, `ukGallon` |
| Currency | ISO code on the household |

Economy conversion uses the constants at `lib/core/format/unit_format.dart:14`:
divide 235.214583 by l/100km for US mpg, 282.480936 for imperial. The two are
different numbers and mixing them is a silent 20 percent error.

Storing a converted value is the mistake this design exists to prevent: a
household that switches units would otherwise reinterpret its own history.

## A row that leaves your scope is never announced

Realtime is filtered by the same RLS policies as a query, which has a
consequence worth stating plainly: **you are told when a row you can see
changes, and never when a change takes it away from you.** Redeeming a vehicle
transfer moves the vehicle to the buyer's household, so the seller's policy
rejects the very update that would have told them — the car simply stopped
appearing on their device, eventually, with no explanation.

The fix is not to widen the policy but to find a row that *stays*.
`vehicle_transfers` keeps `from_household_id` on the seller's side and is
readable by them after redemption, so migration `0034` puts it in the
publication and the app listens there instead. Anything that moves a row
between households needs the same treatment.

## Automatic backups

Off by default. With a folder chosen (Android only), the dashboard's vehicle
listener calls `runAutoBackupIfDue`
(`lib/features/settings/providers/auto_backup_providers.dart:74`) and a backup
is written at most once a day.

The decision half is pure and lives in `AutoBackupSchedule`
(`lib/domain/export/auto_backup_schedule.dart:13`) — including the case worth
knowing about: a `lastBackupAt` in the **future** counts as due, because a
device whose clock was wrong and then corrected would otherwise never back up
again, silently and permanently.

The platform half is three providers in `lib/core/files/backup_folder.dart`,
so the whole feature is testable without a device. See decision 60 for why it
is foreground-triggered, why failures are reported rather than swallowed, and
the dependency risk that shaped both.

## Sharp edges

- **Realtime does not cover everything.** Invites, api keys and webhooks joined
  the publication in `0042`, because revocation is the case where a stale second
  device is actively wrong, and `webhook_deliveries` in `0079`, so a hook's
  screen fills in while a test is out. Attachments and tyre sets are published but nothing
  subscribes to them, and `tyre_readings` is not published at all — so a tread
  measurement taken on one phone needs a screen revisit on the other. Fine
  today, a surprise if you assume the whole schema streams.
- **Invalidation is keyed by vehicle.** A payload without a readable `vehicle_id`
  is dropped silently (`lib/core/sync/realtime_sync.dart:32`). That is the correct
  conservative behaviour, and also means a schema change that renames the column
  would fail quietly rather than loudly.
- **`ref.invalidate` refetches on next read, not immediately.** A screen that is
  not currently mounted will not fetch until it is looked at again.
- **Providers that reach for `Supabase.instance` directly are a trap.** They throw
  in tests, which have no initialized client. Everything must go through
  `supabaseClientProvider` (`lib/core/supabase/supabase_client_provider.dart:5`)
  so it can be overridden. `accountIdentityProvider` is the cautionary tale: it
  reads `currentUserProvider` and had to be added to the shared test harness
  defaults (`test/support/pump_screen.dart`) before unrelated screen tests would
  pass again.
