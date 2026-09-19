# 07. Integrations, import, and export

Everything that crosses the boundary of the system: data coming in from third
parties, and data going out. Siblings:
[06-security-and-tenancy.md](06-security-and-tenancy.md) for how the outward
surfaces are authenticated, [public-api.md](../public-api.md) for the API
contract itself (not restated here).

> Jump to [Sharp edges](#sharp-edges): two of these send a request to a US
> service, a webhook is retried four times and then paused rather than
> forever, and the Fuelio importer guesses nothing.

## Car Scanner recordings

A Car Scanner export is telemetry, not a table: `SECONDS;PID;VALUE;UNITS;
LATITUDE;LONGTITUDE`, one row per sample per channel, 205,000 rows for a
half-hour drive and 80 MB for a long one. The CSV importer recognises the
header and switches from mapping columns to summarising the file, because the
whole file is one trip (`lib/domain/import/car_scanner.dart`, decision 148).

`CarScannerReading` is an accumulator: lines go in one at a time and four
running maxima come out, so an 80 MB file never exists in memory.
`readTextLines` (`lib/core/files/file_text.dart`) is the streaming half of
that, and the reason `readTextFile` is not used for this one path. Both
decode with `allowMalformed: true`, and that is not optional for the streamed
one: it runs over **every** picked file, recording or not, so decoding
strictly refuses a Latin-1 spreadsheet before the lenient reader that exists
for it is ever reached.

**Numbers are read in either convention.** Car Scanner writes them the way the
phone does, and a phone that writes `2,57` is why the export is semicolon-
delimited at all. The plain parse runs first; where both separators appear,
the later one is the decimal (decision 150).

**Two channels are deliberately not believed.** `Distance travelled (total)`
is Car Scanner's own running total since it was installed, not the car's
odometer. `Average fuel consumption` spikes into the hundreds whenever the car
idles; litres over distance is used instead.

**A recording that never moved is flagged, not refused.** Fourteen of the 53
real files are a scanner left running in a parked car; the household knows
which of those was an errand.

**What the file does not say is asked, not defaulted.** The day comes from the
file name and nowhere else, so a renamed file has no date and
`CarScannerDrive.startedAt` is null rather than today. A GPS-only recording
has no distance channel, so the card asks for one instead of importing zero.
The import is refused until both are known (decision 150). The trip's id is
minted when the file is read, not when the button is pressed, so a save that
timed out is retried as the same row (decision 78).

**No integration with drive.hrva.cc.** That app analyses the same files in the
browser and stores nothing — no account to link, no API to call — so anything
"between" the two apps could only be a file. Car Scanner's own file already is
that file.

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
(`lib/features/vehicles/screens/vehicle_detail_screen.dart:1694`). For a European
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

Anchored on the **forecourt the fill-up was recognised at**, its
`station_ref`, and otherwise on the station the field names, not the phone's
position: it asks what was cheap near that pump, not near the sofa the entry
was typed on. A name that points at forecourts more than the radius apart is
refused, which every brand does, so a chain fill-up logged from memory gets no
snapshot; an independent's name still anchors one (decision 170). The
four columns are constrained to arrive together, because a price with no date it
was read on is a number nobody can interpret later. Written on create only.

**The station dataset is read twice, from two different distances.** Standing on
a forecourt, `StationAtThePump.match` (`lib/domain/stations/station_at_the_pump.dart:62`)
offers the posted price of a station within 200 m that sells the fuel going
in, so a petrol car on autogas filling LPG is at an LPG-only forecourt, and
filling petrol is not (a charge keeps the forecourt the car's own fuel finds).
That only helps someone
logging the fill-up at the pump; most are logged later, at home, where the sheet
used to fall back to the price of the *previous* fill-up — a number that can be
weeks stale, and the reason a driver saw 1.54 in August for a pump charging
1.66. `postedPriceAt` (`lib/domain/stations/posted_price.dart:22`) closes that
gap without a position: the forecourt an earlier fill-up under the same name
was recognised at, or failing that the name itself, is enough to look today's
price up in the same dataset. A remembered forecourt is trusted only while it
still answers to that name. It refuses to answer when a name
appears twice with different prices, because a chain repeats its name across
forecourts that charge differently.

**The name the sheet writes down is the brand.** The ministry's dataset names a
forecourt by its place, often behind the word for one: "PM POREČ, ŽBANDAJ" for
all of Petrol's, "BP ..." and "BS ..." for Tifon, Lukoil, Adria Oil and AGS.
`FuelStation.displayName` (`lib/domain/stations/fuel_station.dart:81`) replaces
that opening with the operator's name, and is what the stations list shows. A
fill-up is logged under `brandName`
(`lib/domain/stations/fuel_station.dart:103`): for a chain, three or more
stations in the feed, the brand on the sign ("Shell" for Coral's forecourts);
for anyone else, `displayName`. Which forecourt it was goes into
`fuel_entries.station_ref`, the dataset's own id, only when the sheet
recognised it by position and the field still says what the sheet wrote.
`answersTo` accepts the raw name, `displayName` and the brand, so entries saved
under an older spelling still find today's price (decisions 124, 161 and 170).

Both are offers over a value the sheet itself guessed, never over something
typed, and both run only for a **new** entry — `initState` calls neither when
`existing != null` (`lib/features/fuel/widgets/fuel_entry_sheet.dart:190`).
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

`parseFuelioBackup` (`lib/domain/import/fuelio_backup.dart:368`) reads Fuelio's
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
| JSON | `lib/domain/export/garage_backup.dart:98` | A backup that can be **restored** |
| PDF | `lib/features/reports/` | Six kinds: seller's report, mechanic handover, maintenance history, annual summary, mileage logbook, service schedule |

Two of those are read by somebody outside the household, and both say so on the
page. The **seller's report** carries a mileage trail — one row per year, with
the reading it ended on, the distance, and how many records back it
(`lib/domain/reports/mileage_trail.dart:42`) — and a footer stating that it is
compiled from the owner's own records and is not an official mileage statement.
The **handover sheet** disclaims itself the same way. A year with no readings is
absent from the trail rather than shown as zero, because a car nobody logged did
not stand still.

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

Three things are exported that cannot be *imported*, because they are the ones
whose loss cannot be undone by typing harder: **tyre sets** with their tread
series (added by decision 91 — the tread history is the one series nobody can
measure again after the fact), **documents** with their expiry dates, which are
read off a piece of paper in a glovebox, and **observations**, which exist in
this app and nowhere else. All three are written one table per vehicle by
`DataScreen._csv`, alongside `vehicles.csv`. None is a `CsvEntryKind`, so the
importer does not offer them; the JSON backup is what restores them.

The observations file carries an empty `resolved_on` for anything still going
on, which makes "what is wrong with this car" answerable from the spreadsheet
without the app to interpret it.

**A trip row carries its route by name**, not by id: an id is a number nobody
outside this database can read, and the name is the column that makes two
journeys comparable. It carries `comparable` too, so a reader can leave the
detours out of its own average the way the app does.

The same reasoning put `route_id` and `comparable` on `/trips` in the read-only
API, and made `/observations` a resource of its own — `PRIVACY.md` offers that
API as giving "the same data" as the spreadsheets, and a table in one and not
the other made the sentence false.

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
(`lib/features/settings/data/csv_import_action.dart:27`), and the price per
gallon converts with the volume — dividing where the volume multiplies. Doing
one and not the other stored an entry that contradicted itself and put every
price-per-litre figure out by nearly four times.

## Outbound: API and webhooks

The read-only JSON API is an edge function, `supabase/functions/public-api/`,
authenticated by the hashed key described in
[06-security-and-tenancy.md](06-security-and-tenancy.md). The endpoint contract
lives in [public-api.md](../public-api.md).

Webhooks are fired **from the database**, not from the app, through an outbox
(`supabase/migrations/0079_webhook_outbox.sql:1`, decision 183). A trigger on
each entry table, on `vehicles`, on `vehicle_guest_passes` and on
`household_members` writes one `webhook_outbox` row per event — the garage,
the event's name and a payload of what the table holds
(`supabase/migrations/0079_webhook_outbox.sql:209`) — and then pokes the
`dispatch-webhooks` function through `pg_net` with an **empty body**. The poke
is a hint that there is work; a cron drains the outbox every five minutes
whether or not one arrived
(`supabase/migrations/0079_webhook_outbox.sql:580`). Until 0079 the trigger
posted the changed row itself and the function read it back, which could not
announce a delete — the row was gone — and allowed one attempt.

Three properties are worth knowing:

- **Delivery cannot break a write.** `enqueue_webhook_event` swallows anything
  the insert raises, and the poke sits in an exception block of its own inside
  it (`supabase/migrations/0079_webhook_outbox.sql:185`): a poke that fails —
  `pg_net` missing, its queue refusing — leaves the row for the cron rather
  than rolling it back with the event. A household logging fuel in a tunnel
  must not fail because a home-automation box is unreachable, and must not
  lose the event because the hint about it was.
- **It is dormant until configured.** No row in `webhook_dispatch_config` means
  no poke, which is what local development and CI want. The outbox still
  fills; the nightly prune keeps it to a month.
- **The row is the only thing believed.** Nothing in the poke is read; see
  [What the dispatcher believes](#what-the-dispatcher-believes).

**The drain** (`supabase/functions/_shared/outbox.ts:341`) is what every poke
and every cron tick runs, and what the daily reminder run runs in-process
after writing its own rows. Two passes, each bounded so that a poke storm from
somebody holding the anon key costs a fixed amount of work that was due anyway
(`supabase/functions/_shared/outbox.ts:59`):

1. **Queue** (`supabase/functions/_shared/outbox.ts:89`). Fifty unprocessed
   outbox rows, oldest first: a sale writes the car returned and then handed
   over in one transaction and the receiver hears them in that order, which is
   why both tables default `created_at` to `clock_timestamp()` rather than the
   transaction's `now()`. For each row the garage's hooks are read and
   filtered by `subscribed` (`supabase/functions/_shared/outbox.ts:62`): the
   hook is on, its `events` name the event, and its `vehicle_ids` is null,
   empty or contains the row's `vehicle_id` — or the row has none, which is
   how a hook narrowed to two cars still hears `member.joined` and
   `member.left`; `test.ping` passes before either check. Only if somebody is listening
   (`supabase/functions/_shared/outbox.ts:138`) does the event's builder
   (`supabase/functions/dispatch-webhooks/events.ts:478`) turn the row into
   the signed body, once, and the chat text, once per language among the
   listening hooks. One `webhook_deliveries` row per hook is then written with
   `upsert … ignoreDuplicates` on the unique pair `(outbox_id, webhook_id)`
   (`supabase/functions/_shared/outbox.ts:163`,
   `supabase/migrations/0079_webhook_outbox.sql:57`), so a poke and the cron
   draining the same row at once queue it once, and only then is the row
   marked processed. A hooks read that fails, a deliveries write that fails,
   or anything that throws while the row is queued — a builder's read, the
   text it writes — leaves the row unprocessed for the next drain rather than
   marking it and losing the event, logged once with the row's id, and the
   rows behind it, other households' among them, do not wait with it
   (`supabase/functions/_shared/outbox.ts:103`).
2. **Post** (`supabase/functions/_shared/outbox.ts:186`). A hundred due
   deliveries, oldest first, read through an inner join on the hook's `active`
   (`webhooks!inner(active)`, `supabase/functions/_shared/outbox.ts:192`), so
   a paused hook's open rows never hold the batch. Each row is **claimed
   before it is posted** by an optimistic update — `attempts + 1`, the next
   wait, and `given_up_at` on the fourth attempt — matched on the `attempts`
   the drain read (`supabase/functions/_shared/outbox.ts:235`). Two drains
   reading the same row cannot both win the claim, and a drain that dies
   mid-post has spent one attempt rather than none. The post itself is
   `postDelivery` (`supabase/functions/_shared/webhooks.ts:91`), one delivery
   at a time, each bounded by a ten-second timeout; every answer writes
   `last_status`, a 2xx also writes `delivered_at` and clears `given_up_at`,
   and the hook's `last_delivery_at` and `last_delivery_status` are written
   either way. A post that throws before the fetch — `sign` on a secret a
   member saved empty — is recorded as an attempt that did not get through,
   status 0, and the hooks behind it still get their turn
   (`supabase/functions/_shared/outbox.ts:253`).

**Retries, and what stops them.** The waits are one, ten and sixty minutes
(`supabase/functions/_shared/outbox.ts:41`): four attempts over about an
hour, enough for a home server that rebooted and little enough for one that is
gone. Every attempt of one delivery carries the same `X-Garage-Delivery` id,
and a retry sends the same bytes under the same signature, because the body is
stored on the delivery row. A hook whose last twenty deliveries were **all
given up on** is switched off with `paused_reason = 'failing'`
(`supabase/functions/_shared/outbox.ts:321`) — given up on, not merely failed,
so a receiver that is down for a minute while an import writes a hundred
entries is retried and never paused, while a URL that is gone stops costing
anything once twenty events have each run out of attempts. The app shows the
pause and offers Resume. Twenty queued events against a receiver that answers
4xx or 5xx pause the hook about seventy minutes after the first post; against
one that cannot be reached at all it takes about eighty drains, because of the
next rule.

**A dead receiver costs one timeout per drain, and holds nobody else up.** When
a post comes back unreachable (status 0), the hook's other due rows are skipped
for the rest of the pass and pushed back by the wait the failed row was just
given, in one update and without spending an attempt of theirs
(`supabase/functions/_shared/outbox.ts:303`). Left due, twenty rows to a
switched-off home server would hold one drain for two hundred seconds and sit
at the front of every batch until the hook was paused, with every other
garage's rows behind them. A flat minute would not do either: the cron runs
every five, so the backlog would be due again at each of its drains.

**Three writers, one drain.** The triggers write entries, cars, loans and
members; `push-due-reminders` writes `reminder.due`
(`supabase/functions/push-due-reminders/handler.ts:439`); the app writes
`test.ping` and nothing else. A receiver cannot tell which wrote what it
heard, and should not have to: the signature
(`supabase/functions/_shared/webhooks.ts:54`), the post and its headers
(`supabase/functions/_shared/webhooks.ts:91`), the shape each chat service
takes (`_shared/chat_targets.ts`), the words in each language
(`_shared/chat_i18n.ts`) and the pieces a chat message is written with
(`_shared/chat_text.ts`) are written once, in `supabase/functions/_shared/`. A
directory whose name starts with `_` is not a function: the platform does not
deploy it, `.github/workflows/deploy-functions.yml` deploys functions by name,
and `test/ci/deploy_workflow_test.dart` counts only directories with an
`index.ts`. Each function that imports it has it bundled in when it is
deployed, which is the part only a real deploy, or `supabase functions serve`,
can show. `push-due-reminders` also imports the builders from
`../dispatch-webhooks/events.ts`, a sibling function's directory, which
bundles the same way.

**Each hook chooses what it is sent, and how** (decisions 176 and 183). A hook
has a name, shown in the list instead of its host, capped at the keyboard at
the eighty characters the column takes
(`lib/domain/api/api_access.dart:183`); a car filter,
`vehicle_ids`, null for every car in the garage; a language for its chat text,
`en`, `hr` or `it`; and its `events`, which the app sets as five switches over
the twelve keys (`lib/domain/api/api_access.dart:42`). A group is on only when
every key in it is present, and saving writes all of a group's keys, so a hook
made by hand with half a group shows its keys instead and loses the odd ones
on the next save. The form refuses a hook with no events and, in a garage with
cars, one with no car — the drain reads an empty `vehicle_ids` as every car,
the opposite of what was chosen
(`lib/features/api/screens/api_access_screen.dart:263`). "Every car" is
stored as null and never as the full list, so a car added later is included
(`api_access_screen.dart:294`), and the hook's screen intersects a stored list
with the garage's cars before it counts or edits them, so a sold car's id
cannot make the hook read as narrowed to nothing
(`lib/features/api/screens/webhook_screen.dart:100`). The same screen holds
Resume for a paused hook; **Send a test**, disabled while paused, since the
drain sends a paused hook nothing (`webhook_screen.dart:372`); and the last
twenty deliveries with their event, time, outcome and attempt count, refreshed
through realtime while a test is out (`lib/core/sync/realtime_sync.dart:81`).
The app's "attempt 2 of 4" comes from a constant of its own, which
`test/ci/webhook_attempts_test.dart` holds to the dispatcher's. Any member may
change a hook, as any member may delete it: the update policy has always
allowed it (`supabase/migrations/0017_public_api.sql:78`), and the RLS suite
sets the new columns as the member who did not create the hook
(`test_rls/rls_test.dart:952`).

### What the dispatcher believes

Nothing in a request. The trigger pokes the function with the project's **anon
key** (`supabase/migrations/0025_webhook_dispatch_config.sql:12`), which ships
in every copy of the app. Until 0079 the payload named a row that the function
read back with the service role, believing the name and nothing else
(decision 163); that closed forgery and left a replay, since anybody who knew
a real row's id and its car's could have it announced again. Now the request
carries nothing and nothing in it is read
(`supabase/functions/dispatch-webhooks/handler.ts:8`). Every event the drain
sees is a `webhook_outbox` row, written as service role by a trigger or by the
reminder run from the table the change was made to, and the one row a member
may insert is `test.ping` (`supabase/migrations/0079_webhook_outbox.sql:102`),
through a grant on two columns, `household_id` and `event`
(`supabase/migrations/0079_webhook_outbox.sql:116`) — the policy constrains
values, not which columns a member may set, and a payload of any size or a
`created_at` from years ago would head every drain of the garage's queue —
and whose builder reads nothing from it anyway
(`supabase/functions/dispatch-webhooks/events.ts:471`). A poke from anybody
costs a bounded drain of work that was due anyway, and there is no replay
because there is nothing to replay.

### What a webhook says beyond the row

The row is canonical and terse — a vehicle id, litres, a category key — and the
two things a receiver most wants are not on it at all: which car that is, and
what the tank worked out to. So the generic body carries `vehicle_name`,
`currency` and, on a new fill-up only, `economy`
(`supabase/functions/dispatch-webhooks/events.ts:233`). They come **after** the
five keys that were always there, because JSON promises no order and people
parse it as if it did; `entry.updated` slots `previous` in before `at`, and is
a new event, so nobody parsed it positionally before. The body is built once,
as one string, and stored on the delivery row: that string is what
`X-Garage-Signature` is computed over, what a generic receiver is sent, and
what every retry sends again, so the three cannot drift. Its `at` is the
outbox row's `created_at`, the moment the event was written, not the moment
it was built (`supabase/functions/dispatch-webhooks/events.ts:132`): a lost
poke has the cron build the row five minutes later, and the fill-up did not
move.

**Nothing is looked up until somebody is listening.** Every insert into every
entry table of every household writes an outbox row, and most households have
no webhook. The drain reads the garage's hooks and stops there unless one is
subscribed (`supabase/functions/_shared/outbox.ts:138`). Only then does the
builder read the car, and after it the household's units and currency, the
display name behind `created_by`, and the fuel log, in parallel
(`supabase/functions/dispatch-webhooks/events.ts:221`). The car is required —
without it there is no name and no fuel to read the row by — and gone and
unreadable are different answers (`events.ts:83`): a car deleted before the
drain came round builds nothing and the row is marked processed, while a read
that fails throws, so the row waits for the next drain rather than losing the
event to a database that blinked. The other three are decoration on a
notification that used to arrive without them, so a lookup that fails or
throws leaves its part out: `currency` and `economy` go out as null and the
chat message loses its "by".

**Consumption is the app's own rule, written a second time.** `closingSpan`
(`supabase/functions/dispatch-webhooks/economy.ts:76`) is one span of
`FuelEconomy._computeChain` (`lib/domain/fuel/fuel_economy.dart:86`) — the one
that closes at the entry just logged, since a webhook is about one entry. Same
rule throughout: only a full tank closes a span; it opens at the previous full
tank of the same fuel; partial fills between add their volume; a `missed_fill`
anywhere after the opening tank, the closing entry included, means no figure;
the distance must be positive; and the chain is ordered by odometer, then date,
then full-before-partial (`supabase/functions/dispatch-webhooks/economy.ts:51`).
The volume is summed oldest-first, as the Dart sums it, so that the two can
agree exactly rather than to a tolerance. How far they do was measured rather
than argued: on 17 September 2026, 200,000 random logs — ties in reading and
date, two fuels, missed fills, rows in shuffled order — went through both, and
every answer matched, the 63,514 figures among them bit for bit. That is
evidence about those logs, not a proof, and the run is not in the repository;
what runs on every build is the fixture below.

Which chain an unnamed fill belongs to depends on what the caller says the
car's main fuel is, and the app says so only for a car that takes two
(`lib/features/fuel/providers/fuel_providers.dart:56`). The builder hands
`closingSpan` exactly the same thing
(`supabase/functions/dispatch-webhooks/events.ts:196`). "An entry's fuel is its
own or else the vehicle's" sounds equivalent and is not: on a car that *used*
to take two fuels it merges chains the app keeps apart.

The builder reads the history with the service-role client
(`supabase/functions/dispatch-webhooks/events.ts:173`): the same vehicle, not
the new row itself — the trigger fired after the insert, so it is already there
— nothing past the new reading, nearest first, sixty rows
(`supabase/functions/dispatch-webhooks/economy.ts:45`). The order is the
chain's own, reversed, down to a partial fill before a full one at the same
reading on the same day. That is what makes the limit safe: what it drops is
always the farthest row, so it can cost a very long span its opening tank,
which reads as no figure, and can never take a fill out of the middle of a span
and leave a flattering one. A fill-up that cannot close a span — a partial one,
or one flagged `missed_fill` — asks for no history at all, and an edit or a
delete never does: the figure is on `entry.created` alone, because an edit
changes the figure the app shows and the app is where the current figure is.

**Two copies of a rule are held together by a fixture, not by care.**
`test/fixtures/economy_spans.json` is a file of spans, and of figures as each
household would read them, whose answers were worked out by hand with the
working written beside each.
`test/domain/fuel/economy_fixture_test.dart` runs them through
`FuelEconomy.compute` and `UnitFormat.formatEconomy`;
`supabase/functions/dispatch-webhooks/economy_test.ts` and
`chat_message_test.ts` run the same file through the TypeScript. Neither side
can import the other, so a rule changed on one side fails the fixture on the
other — the arrangement `test/ci/winter_tyre_twin_test.dart` has for the
winter-tyre windows, for the same reason. The Deno side *imports* the JSON
rather than reading it, because a static import needs no `--allow-read` and the
suite is run as `deno test --allow-env`. Expected values must stay hand-made: a
fixture pasted from what an implementation printed can only ever agree with it.
There is one marked exception, the rounding cases described under the message
below.

### `reminder.due`: the event every hook was promised

Every webhook has carried `reminder.due` since the table was made — it is the
column's default (`supabase/migrations/0017_public_api.sql:55`), and a hook
the app creates starts on every group of events
(`lib/features/api/screens/api_access_screen.dart:134`) — and until September
2026 nothing sent it. It is written by the daily reminder run rather than by a
trigger, because that run is what knows something is due and has already
worked out the visits the phones are told about. A hook hears about exactly
those: on the same two days, `REMINDER_LEAD_DAYS`, and one event per vehicle
per due day (`supabase/functions/push-due-reminders/handler.ts:439`).

- **Only the garage that owns the car, and only when it listens.** Hooks are
  asked for by the households of the vehicles with something due, live ones
  only, and each visit is matched to its own vehicle's household through the
  drain's own `subscribed` — its events and its car filter — because one run
  covers every garage at once. A visit nobody listens for writes no row at
  all. A guest pass gives a person a car, not a garage a hook; the borrower's
  own garage hears nothing.
- **One outbox row per visit, drained on the spot.** The row's payload is the
  `ReminderDue` the run worked out, with `vehicle_id` beside it because the
  drain's car filter reads that key off every row
  (`supabase/functions/push-due-reminders/handler.ts:488`). The run then calls
  `drain` itself (`supabase/functions/push-due-reminders/handler.ts:503`), so the hooks hear it
  now rather than at the cron's next pass; an insert that fails is logged and
  answered as `delivered: 0`, and the phones are still told. `delivered` in
  the run's answer is the drain's count, which is these reminders and whatever
  else was due at that moment.
- **Keys, as the push has them.** The generic body
  (`supabase/functions/_shared/reminder_event.ts:47`) is the push's payload in
  JSON's own types — the service type keys as a list, `days_until_due` as a
  number, `swap_direction` only where the push has one, and last. It is signed
  and sent exactly as `entry.created` is, and its `at` is the row's time.
- **Two lines for a chat service**
  (`supabase/functions/_shared/reminder_event.ts:66`), written with an entry's
  pieces and in the hook's language: `nameOf` for the work, the app's own name
  for each service type through `names.json`, `oneLine` for the car's name and
  the list, and a date from `calendarDay`
  (`supabase/functions/_shared/chat_text.ts:93`) — "4 Nov 2026", or "4. stu
  2026." to a Croatian channel, in the locale the figures use, and read in
  UTC, because a stored day is midnight in UTC and in any zone west of it that
  is still the evening before.
- **Before the pushes, and without Firebase.** The hooks are told first, and
  only then is the FCM secret needed; a project without it still tells them
  and skips the pushes. See [08](08-reminders-and-notifications.md).

The chat line names the seasonal swap as the app names the service type,
"Seasonal tire swap", with the direction left to the date beside it: "Fit
winter tyres" is the push's own wording for a direction, not a service type's
name, and the line has no place for one.

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
one household without a database. That fake answers every query on a table
with the same rows, which cannot tell one outbox row from the next or a hook
that is on from one that is off, so a test that runs the drain end to end
gives it tables from `_test/tables.ts` instead
(`supabase/functions/_test/tables.ts:25`): they honour `eq`, `is`, `in` and
`lte`, remember a write, refuse a row a unique index would, and resolve a
`table.column` filter through a join. Both handler tests and the drain's own
share that one fake. What the functions share has its tests beside it in
`_shared/`, and the same command runs them.

**The chat text's names are generated, and a test keeps them honest.**
`_shared/names.json` holds the app's own name for every service type, cost
and income category and trip purpose in each language, generated from the ARB
files by `test/ci/chat_names_test.dart` and never edited by hand. Deno cannot
read the ARBs, so the test is what holds the two together: it fails when they
drift, and `CHAT_NAMES_WRITE=1 flutter test test/ci/chat_names_test.dart`
regenerates the file. Rewording a service or a category in an ARB therefore
fails CI until the file is regenerated, which is the guard working.

`deno check` earns its place in that job separately from the tests: nothing else
type-checks these files, so before it an error in one reached production and
appeared as a 500 when the scheduler fired.

**What the tests cannot tell you** is whether a function still deploys. The
fakes do not care about bundling or imports, and the deploy itself is
unattended: a push to `main` that touches `supabase/functions/**` runs
`.github/workflows/deploy-functions.yml`, which skips with a notice — a green
run — until the repository has its two Supabase secrets. Serve them
(`supabase functions serve`) and call them over HTTP before pushing.

### Chat services are not generic receivers

A webhook pointed at Discord, Slack or Telegram gets that service's own body
instead of the signed JSON (`supabase/functions/_shared/chat_targets.ts`).
Discord answers **400** to any payload without `content`, `embeds` or `file`
however well-formed the rest is, so every delivery to one failed while the
dispatcher correctly reported having posted — the failure was the shape, not
the send.

The target is read from the URL's host unless the household says otherwise.
The URL of a hosted service already says which one it is, so `auto` is the
default and is right for all of them; what it cannot know is a receiver the
household runs itself — an ntfy, a Gotify, a Mattermost on a domain of the
owner's own — so the webhook carries a `format`
(`supabase/migrations/0044_webhook_format.sql:14`, widened to twelve values by
`supabase/migrations/0079_webhook_outbox.sql:75`), the **Format** field when a
webhook is added, and an explicit choice wins over the host
(`supabase/functions/_shared/chat_targets.ts:38`). An unrecognised host on
`auto` keeps the generic contract, which is also what an unparseable URL gets
— delivery then fails on the fetch rather than on the body.

Telegram takes its `chat_id` from the query string the household pasted
(`…/bot<token>/sendMessage?chat_id=<id>`), so only the text is ours to send. A
URL naming no chat gets a 400 from Telegram, which is the honest outcome.

**Four targets arrived with the outbox**, each a different kind of receiver:

- **Teams** is recognised from either of its Workflows webhook hosts,
  `*.logic.azure.com` and `*.webhook.office.com`, matched on the dotted suffix
  so a look-alike host does not pass
  (`supabase/functions/_shared/chat_targets.ts:76`). It refuses a bare `text`
  and wants an Adaptive Card, so it is sent one card with one wrapped
  `TextBlock` (`chat_targets.ts:174`). A TextBlock breaks a line on `\n` only
  inside a list and takes `\n\n` everywhere else, so every line break is
  doubled; and it renders Markdown, so every `](` in the text becomes `] (`
  first (`chat_targets.ts:314`), which leaves bold and italic alone and breaks
  the one thing that matters, a note's `[the invoice](https://evil.example)`
  arriving as a link wearing other words.
- **`text`** is never detected, only chosen: `{ "text": … }` for
  Rocket.Chat, Matrix through hookshot, Mattermost and anything else that
  reads that key and decodes no entities (`chat_targets.ts:195`). Slack's
  escaping would show up on those as a literal `&amp;`, which is why it is
  its own target rather than an alias; what it gets instead is a note's group
  mentions and links defused (`chat_targets.ts:276`), since a Mattermost or a
  Rocket.Chat reads `@channel` and `[words](url)` out of plain text: a
  zero-width space after the `@` of `@channel`, `@all` and `@here`
  (`chat_targets.ts:288`), so the word still reads as written and the service
  finds no mention, and the link broken the way it is for Teams.
- **Pushover** has no per-channel address, so the pasted URL carries the
  application token and the user key in its query. Both are lifted into the
  body, everything else pasted — `priority`, `device`, `sound`, `title` — is
  forwarded as a body field too, "Garage" is only the default title so a
  pasted one wins, the message is written last so nothing pasted replaces it,
  and the call goes to the URL without its query (`chat_targets.ts:204`).
- **Pushbullet** lifts its `token` into an `Access-Token` header the same way
  (`chat_targets.ts:222`). For both, the query is copied before the URL is
  stripped of it (`chat_targets.ts:243`): `searchParams` is a live view of
  the URL, and clearing `search` empties it too, which the plan's first
  version of the helper found out. The app refuses a Pushover or Pushbullet
  URL without its token before the hook is saved
  (`lib/domain/api/api_access.dart:165`), since every delivery would be
  refused and the log would say so only after the first event.

**The message is a few lines, not a row.** `chatMessage`
(`supabase/functions/dispatch-webhooks/chat_message.ts:422`) writes what was
logged, on which vehicle and by whom; then the figures that kind of entry has;
then the note, in quotes. Whatever is missing is left out rather than left
blank, down to the whole line:

```
⛽ Fill-up · Clio · by Ana
42.8 l at INA Zagreb · €60.21 (€1.407/l)
6.1 l/100km over 702 km · 49,680 km
"Motorway all the way"
```

Unlike the JSON beside it, the message is **in the household's units**. The
conversion is `unit_format.dart`'s, constant for constant
(`supabase/functions/dispatch-webhooks/chat_message.ts:95`), and
`economyText`
(`supabase/functions/dispatch-webhooks/chat_message.ts:230`) is
`formatEconomy` (`lib/core/format/unit_format.dart:231`) rule for rule:
l/100km only for kilometres with litres, mpg for every other pairing with the
UK gallon only where the household pours those, and electricity never inverted
— it stays per 100 km, or per 100 miles. The fixture's `readings` hold the two
sets of constants to the same answers. The figures are meant to be the app's;
the wording is a chat line's, not a screen's — the app prints a volume to two
fixed decimals, the message says "42.8 l", and "42,8 l" to a Croatian channel.

**The app and the message decide a charge the same way.** Whether a fill-up is
electricity is the fuel that went in, or the car's main fuel when the fill-up
names none: here (`supabase/functions/dispatch-webhooks/events.ts:267`), and in
the app (`lib/domain/fuel/energy_type.dart:29`). Until 17 September 2026 the app
asked the car instead, so a charge logged on a plug-in kept as petrol read in
litres on the phone and in kilowatt-hours in the message — and a household
reading gallons had its charges stored converted. A charge is kilowatt-hours
whatever the car mainly burns, and the test that pinned the difference now pins
the agreement.

**The last digit is rounded the way the app rounds it**, which is not the way
JavaScript does. At a decimal half two correct formatters part ways: Dart's
`intl` takes the whole part off, multiplies the fraction up and rounds that, in
binary floating point; `Intl.NumberFormat` rounds the shortest decimal spelling,
so it prints 6.4 for a 6.35 the app shows as 6.3; and `toFixed` rounds the exact
binary value and parts from the app the other way, 1.9 for the app's 2.0. Run
against the app's own formatter over 2,080,004 values on 17 September 2026,
plain `Intl` disagreed on 15,404 and `toFixed` on 1,167. Repeating `intl`'s
three steps as written
(`supabase/functions/dispatch-webhooks/chat_message.ts:117`) disagreed on
none, and `Intl` is then handed a number with nothing left to round. The
fixture's `halves` record what the app prints in four such cases and both
suites assert them — the one place in that file where the expected value is
the app's output rather than hand arithmetic, because there the app's
arithmetic *is* the question.

**The message is in the hook's language**, which is the channel's rather than
any member's: `en`, `hr` or `it`, chosen when the hook is added — the app's
own language by default — and changeable on its screen. The words are
`_shared/chat_i18n.ts`'s, three tables written by hand and kept short
(`supabase/functions/_shared/chat_i18n.ts:49`): a label, a car, a name and a
few figures. Where a word would have to agree with a noun it is written out
per kind — "Trošak uređen", "Spesa modificata" — and where it would have to
agree with a person it is not written at all
(`supabase/functions/_shared/chat_i18n.ts:14`): a display name says nothing
about gender, so the person is named after the car with no verb, and "logged
by Ana" is "unos: Ana" and "voce di Ana". Figures and dates are `Intl`'s in
the language's locale (`supabase/functions/dispatch-webhooks/chat_message.ts:87`):
"49.680 km" and "4. stu 2026." to a Croatian channel, "4.500,00 €" to an
Italian one — grouped always, because Italian's CLDR data would leave a
four-digit amount ungrouped and the app's own formatter does not
(`supabase/functions/dispatch-webhooks/chat_message.ts:136`). The signed JSON
is keys and canonical values in every language.

A category, a service type or a trip's purpose is named as the app names it
(`supabase/functions/_shared/chat_i18n.ts:305`): `service_oil_change` reads
"Oil change", "Zamjena ulja", "Cambio dell'olio", from `_shared/names.json`,
which `test/ci/chat_names_test.dart` generates from the ARB files and holds
them to (see [Testing them](#testing-them)). That reversed a decision: until
19 September 2026 the key was tidied instead — `service_oil_change` to "Oil
change" by dropping the prefix and the underscores — because the function
could not read the ARBs and a copy would drift, so `ride` read "Ride" where the
app says "Lift share". The generated file is the copy that cannot drift, and
the English changed with it for every existing hook: 22 of the 60 names, among
them "Diesel particulate filter" for `service_dpf` and "Ride-hailing" for
`transport_app`. A key in no list — a household's own service type, since
`service_types` stores a key and nothing else
(`supabase/migrations/0005_maintenance.sql:3`) — is still tidied
(`supabase/functions/_shared/chat_text.ts:69`), and only `service_` is dropped
as a prefix, because only service types have one: cost and income categories
are bare words (`lib/domain/entities/cost_entry.dart:132`,
`lib/domain/entities/income_entry.dart:98`), and stripping `income_` would turn
a household's `income_protection` premium into "Protection".

**Nothing a person typed can break the shape.** Every value that is text goes
through one function
(`supabase/functions/_shared/chat_text.ts:32`) that folds
line breaks into spaces and cuts by character, never through one — a note at
200, a name at 80, the list of work at 400. That includes the two that look
constrained: a category is a key of any length, and a trip's `purpose` is
checked by its column, which a payload that did not come from the column has
not passed. The bound is not tidiness: Discord refuses content past 2,000
characters, the columns are unbounded, and a refusal is a notification that
never arrives.

**And it cannot ping the household's server.** The message carries what people
typed, and not only members type: a guest with a fuel pass can log a fill-up
with a note on it (`supabase/migrations/0055_guest_passes.sql:239`). A
reminder carries typed text too, a car's nickname and a household's own
service types, and goes through the same `deliveryFor`. Four services read
markup out of message text, and each is answered in its own terms:

- **Discord** is sent `allowed_mentions: { parse: [] }`, its own way of saying
  that nothing in the text is a mention, and `flags: 4` — `SUPPRESS_EMBEDS`,
  one of the few flags its webhook endpoint accepts — so a link in a note does
  not unfurl into a preview card
  (`supabase/functions/_shared/chat_targets.ts:136`).
- **Slack** gets `&`, `<` and `>` as entities, which is Slack's own rule and
  what stops `<!channel>`
  (`supabase/functions/_shared/chat_targets.ts:264`) — after the plain-text
  defusal below, because a Mattermost or a Rocket.Chat addressed through the
  Slack format reads `@channel` and a Markdown link out of the same text.
- **Google Chat** reads `<users/all>` as a mention of the whole space and
  `<https://…|words>` as a link wearing other words, and documents no escape
  for either. So it is left no token to find: every angle bracket becomes the
  single guillemet that looks most like it
  (`supabase/functions/_shared/chat_targets.ts:301`), which
  costs "tyres < 3 mm" a slightly odd character and costs markup everything.
- **Teams** renders Markdown in a TextBlock and documents no escape either, so
  the link syntax is broken with a space
  (`supabase/functions/_shared/chat_targets.ts:314`); `[words] (url)` is two
  things a person can read rather than one link.
- **`text`** receivers — Mattermost, Rocket.Chat — page the channel on
  `@channel`, `@all` or `@here` and render Markdown, so the mention gets a
  zero-width space after its `@` and the link a space after its bracket
  (`supabase/functions/_shared/chat_targets.ts:276`).

**What this costs.** A hook's language is one more thing to choose, and three
tables of strings to keep in step, which a parity test does leaf by leaf. The
signature, while still sent, means nothing to a chat service — it is
verifiable only by the generic receivers it was built for, which is the trade
for the feature working at all against services that were never going to
verify it.

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
- **Anybody holding the anon key can poke the dispatcher, and that is fine.**
  The poke carries nothing and nothing in it is read, so what a stranger can
  cause is one bounded drain of work that was due anyway — fifty outbox rows
  and a hundred due deliveries — which the five-minute cron would have done
  within five minutes regardless. The replay the read-back design left open,
  a real row announced twice by whoever knew its id and its car's, is gone
  with the read-back: there is nothing in a request to replay. A member can
  still make the garage's hooks say one thing on demand, `test.ping`, and
  only that.
- **What the events do not announce.** A pass that expires changes no row, so
  a loan that runs out is never `vehicle.returned`; a borrower who deletes
  their account has their pass's `redeemed_at` nulled by 0059, which ends the
  loan with no event either; a car moved by a merge is announced to nobody, by
  design; a car deleted outright is announced to nobody either, and neither
  are the entries that cascade away with it — the vehicles trigger fires on
  insert and update only, and the entry trigger finds no car to look up
  (`supabase/migrations/0079_webhook_outbox.sql:205`); and an update that
  changes only `created_by` — what deleting an account does to every row the
  person authored — is not an edit. All five are written down rather than
  fixed: as never announced in [public-api.md](../public-api.md#webhooks) and
  with their reasons in decision 183; the two that a household could take
  for a bug, the expiry and the borrower who leaves, are also in
  [known-bugs-and-risks.md](../operations/known-bugs-and-risks.md).
- **A webhook's consumption figure is a snapshot, and the app's is not.** It is
  worked out once, when the event is built — the drain after the insert, a
  moment or up to five minutes later — from the log as it stood. An edit, a
  delete, or an older fill-up entered afterwards changes what the app shows
  and sends `entry.updated` or `entry.deleted` with no figure. Fill-ups
  queued offline replay in quick succession, so a webhook can also be computed
  before a neighbouring entry has landed. Three narrower ways the two can
  part: a span more than sixty rows long has no figure here and one in the
  app; two *full* tanks at the same reading on the same day have no defined
  order in the app (Dart's sort is not guaranteed stable and the read is
  ordered by odometer alone), where the dispatcher always puts the new one
  last; and the app merges fill-ups still waiting in the offline queue, which
  the server has never seen.
- **A reminder due by distance holds still only between readings.** The daily
  run dates it from the furthest reading on record — the highest, and the
  later of two at one odometer — at 30 km a day from the day of that reading
  (`supabase/functions/push-due-reminders/handler.ts:325`). Until September
  2026 it counted from the day of the run, so with no new reading the days to
  go never changed and the same notice went out every morning: as a push, each
  one new because the due day is part of the notification id
  (`lib/core/notifications/notification_scheduler.dart:88`), and it would have
  gone to chat the same way. The run still keeps no record of what it sent, so
  a reading that moves the date can bring a notice round again or carry the
  date past one. The app's own projector still counts from today; see
  [08](08-reminders-and-notifications.md#sharp-edges). A one-off due at an
  odometer is dated the same way; until then the run never read its target,
  and never sent it at all.
- **Markup in a note is defused for Discord, Slack, Google Chat, Teams and
  `text`, and for nobody else.** Telegram, ntfy, Gotify, Pushover and
  Pushbullet are sent the text as typed. Telegram is given no `parse_mode`,
  so it formats nothing, but whether a plain `@username` still notifies has
  not been checked; the others have not been checked at all. A Mattermost
  addressed through the Slack format used to link `@channel` typed as plain
  words, by its own documentation, since entity escaping does not touch
  that; the Slack shape now gets the plain-text defusal first. A bare URL in
  a note is still turned into a link by most of these services, which no
  escaping can or should prevent — the address shown is at least the address
  followed.
- **A month of history, and no more.** Deliveries and outbox rows older than
  thirty days are pruned nightly
  (`supabase/migrations/0079_webhook_outbox.sql:558`), processed or not: a
  garage whose operator never configured an endpoint must not grow a queue
  forever, and a month-old event is not worth delivering once it finally
  could be. A delivery still retrying on day thirty goes with its outbox row.
- **Webhook secrets are per household and stored in plain text** in the
  `webhooks` table, since they must be replayable to sign each delivery. The table
  is readable only by that household under RLS.
- **The API is read-only.** There is no write path, deliberately. A key that leaks
  exposes history; it cannot corrupt it.
