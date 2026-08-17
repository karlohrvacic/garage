# 07. Integrations, import, and export

Everything that crosses the boundary of the system: data coming in from third
parties, and data going out. Siblings:
[06-security-and-tenancy.md](06-security-and-tenancy.md) for how the outward
surfaces are authenticated, [public-api.md](../public-api.md) for the API
contract itself (not restated here).

> Jump to [Sharp edges](#sharp-edges): two of these send a request to a US
> service, webhook delivery is single-attempt on purpose, and the Fuelio importer
> guesses nothing.

## Why this exists, and why it is built this way

Three different pressures:

- **Getting in.** The target user already keeps this data somewhere, usually
  Fuelio. An importer is the difference between trying the app and adopting it.
- **Getting out.** The app promises no lock-in, and CSV export is what makes that
  claim true rather than marketing. It doubles as the GDPR portability mechanism
  (`lib/core/export/csv_export.dart:8`).
- **Being useful to a household's own tools.** A read-only API and webhooks let
  someone put their fuel spend on a home dashboard without the app growing a
  dashboard feature.

## Inbound: third-party data

| Source | Used for | Code | Authentication |
|---|---|---|---|
| MINGOR / mzoe-gor.hr | Croatian fuel prices and the national average series | `lib/features/stations/data/stations_repository.dart:22` | None, open data |
| NHTSA vPIC | VIN decode to make, model, year | `lib/features/vehicles/data/vin_decoder.dart:26` | None |
| NHTSA recalls | Open safety recalls by make, model, year | `lib/features/vehicles/data/recall_lookup.dart` | None |

The NHTSA services are **US-oriented**, which the code says plainly
(`lib/features/vehicles/data/vin_decoder.dart:7`): a European VIN often decodes to
the make and little else. Every field a decode fills stays editable, so it is a
starting point for the form and never the last word. The same caveat is shown to
the user for recalls rather than buried here.

Both are user-initiated, one request per press, and neither is stored beyond what
the user keeps. That distinction is what keeps them out of the Play Data safety
form as collected data, and it is disclosed in [`PRIVACY.md`](../../PRIVACY.md) as
a transfer outside the EU.

## Inbound: Fuelio import

`parseFuelioBackup` (`lib/domain/import/fuelio_backup.dart:228`) reads Fuelio's
section-based CSV export. It is pure domain code, so the whole parser is tested
against a trimmed real export
(`test/domain/import/fuelio_backup_test.dart:7`).

Two things make it more than a CSV reader:

**Columns are resolved by header name, not position**
(`lib/domain/import/fuelio_backup.dart:217`). Fuelio has renamed and added columns
across versions (`Data`/`Date`, `Odo (km)`/`Odo`), so a positional reader breaks on
half the exports in the wild.

**Fuelio's Costs section is triple-booked.** The same table holds real expenses,
past services, and recurring reminders. The importer splits them three ways
(`lib/domain/import/fuelio_backup.dart:223`): a repeat interval makes it a
reminder, a title or category that reads as service work makes it a service, and
what is left is a cost. Title matching covers Croatian and English
(`lib/domain/import/fuelio_backup.dart:168`).

The `## Vehicle` section becomes the car itself
(`vehicleFromFuelio`), which is what lets someone import before they own anything
in the app. Tracking starts at the oldest reading in the file, because a later
baseline would place the imported history before the vehicle existed.

Fuel type is **asked, not guessed**: the backup does not record it in a form worth
trusting, and a wrong fuel type silently distorts every consumption figure.

Re-running an import is safe: rows already present are matched on their natural
keys and skipped, and reminder rules upsert per service type
(`lib/features/settings/data/fuelio_import.dart:31`).

## Inbound: any CSV, with the columns mapped

`CsvSchema` and `CsvImport` (`lib/domain/import/csv_import.dart:38`) read a table
from anywhere — Drivvo, another app, a spreadsheet somebody kept by hand — with
the user saying which column is which. This is the answer to "import from
Drivvo" and deliberately not a Drivvo parser: that export is behind a paywall,
so its column names, date format and decimal separator were all unknown, and
guessing at them produces an importer that silently mangles a whole history.

Six things it has to get right, and does:

| Problem | What it does |
|---|---|
| Delimiter | Tries each and keeps the one that splits the header widest, so a comma inside a quoted field cannot beat the real semicolon |
| Decimal separator | Whichever of `.` and `,` comes **last** is the decimal point (`csv_table.dart:83`), which reads `1,234.56` and `1.234,56` |
| Ambiguous dates | 03/09 is a **question**, not a guess — day-first is a switch the user sets |
| Impossible dates | 31 February is refused, not rolled forward into March (`csv_table.dart:157`) |
| Units | Miles and gallons are converted on the way in, asked rather than assumed |
| Bad rows | Reported with their line number **before** anything is written |

Column guessing (`csv_import.dart:220`) matches on a normalised header, so
`Odo (km)` and `odometer_km` both find the odometer; a field it cannot place is
left empty rather than mapped wrongly, because a wrong mapping that looks right
is worse than none.

Like the Fuelio importer, it is re-runnable: each kind is matched against what is
stored by the natural key a human would use, so importing twice leaves one copy.

## Outbound: export, and backup

| Format | Code | Purpose |
|---|---|---|
| CSV | `lib/core/export/csv_export.dart:6` | Portability, GDPR, spreadsheets |
| JSON | `lib/domain/export/garage_backup.dart:66` | A backup that can be **restored** |
| PDF | `lib/features/reports/` | Seller's report, maintenance history, annual summary |

CSV is written in **canonical units with language-neutral keys**
(`lib/core/export/csv_export.dart:6`). A file whose column headers change with the
app's language is not portable, and one whose numbers change with a display
preference is worse.

**The JSON backup is a different thing from the CSV export**, and both exist. The
CSV answers portability and cannot come back: it loses which service types one
visit covered and whether a tank was full, which are what the economy and
projection algorithms run on. The backup carries the shape, is versioned, and is
refused outright by a build older than the one that wrote it.

Restoring is **additive**: nothing is deleted, and an entry already present is
skipped. Restoring is what people do when they are already worried about their
data. Vehicles are matched by nickname rather than id, because a backup restored
into a different household carries ids that mean nothing there.

The backup carries the six entry kinds, the vehicles, the **reminder rules**,
and the **tyre sets with their tread history**
(`lib/features/settings/data/backup_action.dart:21`). The last two are there
because their loss is the kind a restore cannot show: the log comes back and
the notifications never do, and a tread reading cannot be measured again after
the fact. Photo attachments are the one omission — files in storage, not rows.

Tyres restore in two passes, because a set has no id until it is created: add
the missing sets, read back the ids, then fill in readings. Fitting and
retiring apply only to sets the restore created, since a household that has
swapped tyres since the backup knows better than the file does.

A gallon in an imported file is the household's own gallon
(`lib/features/settings/data/csv_import_action.dart:26`), and the price per
gallon converts with the volume — dividing where the volume multiplies. Doing
one and not the other stored an entry that contradicted itself and put every
price-per-litre figure out by nearly four times.

## Outbound: API and webhooks

The read-only JSON API is an edge function, `supabase/functions/public-api/`,
authenticated by the hashed key described in
[06-security-and-tenancy.md](06-security-and-tenancy.md). The endpoint contract
lives in [public-api.md](../public-api.md).

Webhooks are fired **from the database**, not from the app. Migration
`supabase/migrations/0024_webhook_dispatch.sql:1` adds an `after insert` trigger
on every entry table — the three of the day, and the odometer, trip and income
tables added by `supabase/migrations/0032_webhooks_for_new_kinds.sql:12` — that
posts the row to the `dispatch-webhooks` function
through `pg_net`. The payload is the same shape Supabase's own Database Webhooks
send, so either wiring works.

Two properties are worth knowing:

- **Delivery cannot break a write.** `pg_net` queues the request and returns, and
  the trigger swallows anything it still manages to raise
  (`supabase/migrations/0025_webhook_dispatch_config.sql:56`). A household logging
  fuel in a tunnel must not fail because a home-automation box is unreachable.
- **It is dormant until configured.** No row in `webhook_dispatch_config` means no
  dispatch, which is what local development and CI want.

Delivery is best-effort and single-attempt, by decision rather than omission: a
receiver that missed a ping can read the same data from the API, and retry storms
are worse than a missed notification
(`supabase/functions/dispatch-webhooks/handler.ts:11`).

## Testing them

The four edge functions are Deno and invisible to the Flutter suite, so they get
their own, run from `supabase/functions/` and wired into the `functions` job in
`.github/workflows/ci.yml`:

```bash
cd supabase/functions
deno test --allow-env    # no Docker, no network
```

Each is a three-line `index.ts` over a `handler.ts`. That shape exists for one
reason: `Deno.serve` at the top level of a module starts a server in anything
that imports it, so a single-file function cannot be imported by a test at all.
`makeHandler(deps)` takes the Supabase client, `fetch`, the clock and the FCM
token exchange; `_test/fake_supabase.ts` stands in for the query builder and
records what was asked, which is how a test asserts that a query was scoped to
one household without a database.

`deno check` earns its place in that job separately from the tests: nothing else
type-checks these files, so before it an error in one reached production and
appeared as a 500 when the scheduler fired.

**What the tests cannot tell you** is whether a function still deploys. The
fakes do not care about bundling or imports, and deployment is by hand. Serve
them (`supabase functions serve`) and call them over HTTP before deploying.

## Sharp edges

- **Two integrations leave the EU.** VIN decode and recalls both call NHTSA in the
  US. That is disclosed, and it is the reason the privacy policy has a transfer
  section at all.
- **The price dataset is Croatia-only.** The Stations feature is meaningful in one
  country. The list says so when the nearest station is beyond the covered
  radius, and the picks and area-average cards hide themselves in that case —
  from outside Croatia the whole country is "nearby", and a pick naming a station
  a continent away is worse than no pick.
- **There is no map and no stations-on-route, on purpose.** Both need a third
  party in the data path — a tile server, a routing API — receiving the user's
  position on every pan. The app claims in [`PRIVACY.md`](../../PRIVACY.md) and on
  the Play Data safety form that nothing is sent anywhere, and the pump autofill
  is built to match a position against prices *already on the phone* precisely to
  keep that true. Adding either would make the claim false and change what has to
  be declared. That is a product decision about the app's central promise, not an
  implementation detail.
- **Import needs a `.csv`, not Fuelio's Drive `.zip`.** The parser takes CSV text.
  The picker asks for MIME types as well as extensions
  (`lib/core/files/file_picker.dart`), because Android providers report CSV
  inconsistently and an extension-only filter greys out the very file the user
  wants.
- **Webhook secrets are per household and stored in plain text** in the
  `webhooks` table, since they must be replayable to sign each delivery. The table
  is readable only by that household under RLS.
- **The API is read-only.** There is no write path, deliberately. A key that leaks
  exposes history; it cannot corrupt it.
