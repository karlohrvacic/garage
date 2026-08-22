# 05. Data access, state, and sync

How a screen gets data, how two phones stay in agreement, and where units are
converted. Siblings: [01-system-overview.md](01-system-overview.md) for the
layers, [09-errors-and-diagnostics.md](09-errors-and-diagnostics.md) for what
happens when a call fails.

> Jump to [Sharp edges](#sharp-edges): realtime covers four tables and not the
> rest, invalidation needs `replica identity full` to work on deletes, and a
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

Subscribed tables, from `supabase/migrations/0007_realtime.sql:3`:

| Table | Invalidates |
|---|---|
| `vehicles` | `allVehiclesProvider` |
| `fuel_entries` | `rawFuelEntriesProvider(vehicleId)` |
| `service_entries` | `serviceEntriesProvider(vehicleId)` |
| `cost_entries` | `costEntriesProvider(vehicleId)` |
| `reminder_rules` | maintenance providers |

RLS still applies to the stream (`supabase/migrations/0007_realtime.sql:1`), so a
member never receives another household's changes. Realtime is not a hole in the
tenancy model.

### The delete detail

`fuel_entries` is set to `replica identity full`
(`supabase/migrations/0007_realtime.sql:11`). Without it a DELETE event carries
only the primary key, so the client cannot read `vehicle_id` to know which
provider to invalidate, and a deletion on one phone leaves a ghost row on the
other. Any new table added to the publication that needs per-vehicle invalidation
needs the same treatment.

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

- **Realtime does not cover everything.** Attachments, tyre sets, invites, api
  keys, and webhooks are not in the publication, so changes there need a manual
  refresh or a screen revisit. This is fine today because those are rarely edited
  concurrently, but it is a surprise if you assume the whole schema streams.
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
