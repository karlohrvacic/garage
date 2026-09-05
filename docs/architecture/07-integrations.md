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

The recalls card is also **folded away by default**
(`lib/features/vehicles/screens/vehicle_detail_screen.dart:880`). For a European
car this is an optional check against a US register that usually finds nothing,
and it was spending a heading, a paragraph of caveat and a button on saying so
permanently, on a screen whose subject is what the car needs next. Open, it says
everything it did; a recall that is actually found opens it by itself, because
that is the one case worth the room.

**One thing about that dataset is now kept.** Every fill-up created since
migration `0045` records the cheapest station within 5 km of the one it names,
how far away that was, and the day the prices were read
(`lib/domain/stations/cheapest_nearby.dart:44`). It is the first denormalised
snapshot of external data on an entry row in this schema, and it exists because
the alternative is permanent: the feed is fetched live and stored nowhere, so
the moment a fill-up saves, the surrounding prices are gone and "did I pay over
the odds?" becomes unanswerable about that day forever.

Anchored on the **station name**, not the phone's position — the name is
already on the entry, it needs no permission, and it asks the right question
(what was cheap near that pump, not near the sofa the entry was typed on). It
refuses when a chain name points at forecourts more than the radius apart. The
four columns are constrained to arrive together, because a price with no date it
was read on is a number nobody can interpret later. Written on create only.

**The station dataset is read twice, from two different distances.** Standing on
a forecourt, `StationAtThePump.match` (`lib/domain/stations/station_at_the_pump.dart:55`)
offers the posted price of a station within 200 m. That only helps someone
logging the fill-up at the pump; most are logged later, at home, where the sheet
used to fall back to the price of the *previous* fill-up — a number that can be
weeks stale, and the reason a driver saw 1.54 in August for a pump charging
1.66. `postedPriceAt` (`lib/domain/stations/posted_price.dart:14`) closes that
gap without a position: the station *name* the last fill-up recorded is enough
to look today's price up in the same dataset. It refuses to answer when a name
appears twice with different prices, because a chain repeats its name across
forecourts that charge differently.

Both are offers over a value the sheet itself guessed, never over something
typed, and both run only for a **new** entry — `initState` calls neither when
`existing != null` (`lib/features/fuel/widgets/fuel_entry_sheet.dart:128`).
Moving the amount on a saved fill-up to today's price would rewrite what was
actually paid.

**The trend series is noisier than the thing it measures, and the noise has a
shape.** `fetchTrend` returns a rolling window — 254 rows over 59 dates when
measured on 31 August 2026, about ten weeks, with ten calendar days missing.
Within it the national petrol average moves a **median of 5 cents a day** and
once jumped 43. That is not the market. Two facts establish it:

- **The big moves come in spike-and-return pairs.** 30 July read 2.20 and 31
  July 1.89, either side of a week sitting at 1.88; 13 August read 2.15 and 14
  August 1.83. A price does not do that. A sample does.
- **Coverage varies by weekday.** Thursdays carry one to three fuel types where
  Mondays carry five and Tuesdays five or six — and every one of those spikes
  falls on a Thursday, Friday or Sunday. The spike is a thin day being averaged.

Corroborating this, as of August 2026 Croatia sets fuel prices under a **cap
revised weekly**, so the underlying figure genuinely is close to flat between
revisions — which is exactly what LPG, the one grade reporting consistently,
shows: a median daily move of one cent against petrol's five. The volatility is
the feed's, not the market's.

**The cap is government policy and will not last forever.** Note what does and
does not rest on it: the spike-and-return pairs and the weekday coverage gaps
are properties of *how MINGOR collects and publishes*, not of what the market
does, so the median and the seven-day window stay correct after the cap ends.
What changes is the signal underneath — real daily movement returns — and the
two-cent "steady" floor is then worth re-measuring against fresh data rather
than assumed. If prices are decontrolled, re-run the day-to-day spread by
weekday before trusting any threshold here.

Three consequences, all in `lib/domain/stations/price_trend.dart`:

- The chart is drawn from a **7-day trailing median**, never the raw series.
- **Median, not mean.** A mean does not reject a thin day, it spreads it: a 30
  cent spike over a seven day window is still four cents of apparent movement,
  which is *twice* the two-cent floor below which the screen says "steady". The
  first cut of this used a mean and would have announced price movements that
  never happened.
- **The window is seven days and cannot sensibly be anything else.** Since
  coverage varies by weekday, any window that is not a whole number of weeks
  over-samples some weekdays; a week contains each exactly once, on both sides
  of a comparison.

The screen's existing national-average figure took `series.last` off whatever
order the feed arrived in — unsorted, and a single day that might well have been
one of the thin ones. It now reads the smoothed series.

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
backup carries the shape, is versioned, and is refused outright by a build older
than the one that wrote it; it is the only artifact a restore can rebuild a
garage from.

The CSV now covers every kind the importer can read. `fuelEntriesToCsv`,
`serviceEntriesToCsv`, `costEntriesToCsv`, `incomeEntriesToCsv`,
`tripEntriesToCsv` and `odometerEntriesToCsv`
(`lib/core/export/csv_export.dart:6`) match `CsvEntryKind`
(`lib/domain/import/csv_import.dart:30`) one for one, and `DataScreen._csv`
(`lib/features/settings/screens/data_screen.dart:44`) writes a section per kind
per vehicle, each with its own header row — one union table would be mostly
blank and readable by nothing.

Only fuel and services were written for a long time, which made a household able
to bring its costs and trips in and unable to take them back out.

Two things are exported that cannot be *imported*, because they are the two
whose loss cannot be undone by typing harder: **tyre sets** with their tread
series (added by decision 91 — the tread history is the one series nobody can
measure again after the fact) and **documents** with their expiry dates, which
are read off a piece of paper in a glovebox. Both are written one table per
vehicle by `DataScreen._csv`, alongside `vehicles.csv`. Neither is a
`CsvEntryKind`, so the importer does not offer them; the JSON backup is what
restores them.

It does *not* drop `service_types` or `full_tank`, which this document once
claimed — both are columns and always were.

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

Carrying the right *kinds* is not the same as carrying the right *fields*, and
that distinction cost real data. `_service` and `_cost` stopped being updated
as their entities grew, so a restore silently gave back a visit with no
measurements, warranty, fault codes, DIY flag or parts detail, and a vignette
with no idea which country or period it bought. Both serializers now write
everything the repository persists, and `fullyPopulated()`
(`test/domain/export/garage_backup_test.dart`) exists to keep them honest: it
sets every optional field on both kinds, and the round-trip tests assert each
one survives. A field added to either entity belongs in that fixture.

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

### Chat services are not generic receivers

A webhook pointed at Discord, Slack or Telegram gets that service's own body
instead of the signed JSON (`supabase/functions/dispatch-webhooks/chat_targets.ts`).
Discord answers **400** to any payload without `content`, `embeds` or `file`
however well-formed the rest is, so every delivery to one failed while the
dispatcher correctly reported having posted — the failure was the shape, not
the send.

The target is detected from the URL's host, never asked for: the URL already
says which service it is, and a picker that could disagree with it is a way to
get it wrong. An unrecognised host keeps the generic contract, which is also
what an unparseable URL gets — delivery then fails on the fetch rather than on
the body.

Telegram takes its `chat_id` from the query string the household pasted
(`…/bot<token>/sendMessage?chat_id=<id>`), so only the text is ours to send. A
URL naming no chat gets a 400 from Telegram, which is the honest outcome.

**What this costs.** The summary is plain English, because the edge function
has no access to the household's locale or the app's ARB files and a
half-translated notification reads worse than a consistent one. And the
signature, while still sent, means nothing to a chat service — it is verifiable
only by the generic receivers it was built for, which is the trade for the
feature working at all against services that were never going to verify it.

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
