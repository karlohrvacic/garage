# 02. Domain model

The nouns of the system and how they hang together. Siblings:
[01-system-overview.md](01-system-overview.md) for the layers,
[06-security-and-tenancy.md](06-security-and-tenancy.md) for how these tables are
scoped, [03-fuel-economy.md](03-fuel-economy.md) for what fill-ups mean.

> Jump to [Sharp edges](#sharp-edges): the three entry kinds are deliberately not
> one table, "cost" means two different things depending on where you look, and a
> vehicle's baseline is not its first reading.

## Why this exists, and why it is built this way

Everything hangs off a **household**, not a user. A user with no household cannot
do anything except create or join one, which is why the router sends them to
onboarding (`lib/core/router/app_redirect.dart:13`). Vehicles belong to the
household; entries belong to vehicles; membership is what grants a person access.

That one decision produces the sharing model competitors lack: two people are
peers on the same car, with no owner-to-driver hierarchy, and no row belongs to
whoever happened to type it. Attribution is kept (`created_by` on every entry) but
it confers no rights, only a name on the timeline and — in a garage that has
asked for the settlement (decision 48; off by default) — a share in it
figures.

## The graph

```
auth.users ──1:1── profiles (display_name)
     │
     └──< household_members (household_id, user_id, role) >── households
                                                                  │
                                    invites >─────────────────────┤
                                                                  │
                                              vehicles <──────────┘
                                                 │
    ┌────────┬──────────┬─────────┬────┴────┬─────────┬──────────┬─────────┐
 fuel_    service_   cost_    odometer_  trip_    income_   reminder_  tyre_sets
 entries  entries    entries  entries    entries  entries   rules         │
                                            │                       tyre_readings
                                            │   vehicle_documents
                                    route_id│
                                            └──> routes ── household_id

           attachments ── (vehicle_id, entry_kind, entry_id)
           api_keys, webhooks ── household_id
```

## Core tables

| Table | Migration | Notes |
|---|---|---|
| `households` | `supabase/migrations/0001_households.sql:5` | Also holds the household's units, currency, bundling windows, tracking level, country |
| `profiles` | `supabase/migrations/0001_households.sql:18` | Display name, populated by a trigger on sign-up |
| `household_members` | `supabase/migrations/0001_households.sql:26` | The join table that grants access; carries `role` |
| `invites` | `supabase/migrations/0002_invites.sql:1` | 8-character codes, expiry, redemption |
| `vehicles` | `supabase/migrations/0003_vehicles.sql:1` | Nickname, fuel type, make/model/year/VIN/plate, baseline, archived flag |
| `fuel_entries` | `supabase/migrations/0004_fuel.sql:1` | Fill-ups |
| `service_types` | `supabase/migrations/0005_maintenance.sql:3` | Presets (household-scoped when `household_id` is set, built-in when null) |
| `reminder_rules` | `supabase/migrations/0005_maintenance.sql:21` | Recurring intervals by distance, time, or both |
| `service_entries` | `supabase/migrations/0005_maintenance.sql:39` | Work actually done |
| `cost_entries` | `supabase/migrations/0012_costs.sql:4` | Everything else that costs money |
| `odometer_entries` | `supabase/migrations/0028_odometer_entries.sql:10` | A dated reading with no money attached |
| `trip_entries` | `supabase/migrations/0029_trips_and_income.sql:12` | A mileage logbook: where, how far, private or business, and who drove (migration 0052). A row with no `distance_km` is a drive still under way (migration 0054) |
| `income_entries` | `supabase/migrations/0029_trips_and_income.sql:41` | Money in, including what the car sold for |
| `observations` | `supabase/migrations/0060_observations.sql:20` | Something noticed and not settled; an event is one carrying a `trip_id`. Carries photos, the fifth attachment kind |
| `vehicle_parts` | `VehiclePart` (`lib/domain/entities/vehicle_part.dart`) | What the car takes for one job, keyed by service type; one row per job per vehicle |
| `routes` | `supabase/migrations/0061_routes.sql:18` | A journey made over and over, named once so it can be compared with itself. A household-scoped label and nothing else — no addresses (decision 120) |
| `attachments` | `supabase/migrations/0016_attachments.sql` | Receipts and documents, pointed at Storage. `entry_id` is a bare uuid with no foreign key, so a file can be attached while the entry is still being typed (decision 90) |
| `tyre_sets`, `tyre_readings` | `supabase/migrations/0023_tyre_sets.sql` | A set as a thing in its own right, and its tread over time |
| `vehicle_documents` | `supabase/migrations/0049_vehicle_documents.sql:26` | The paperwork a car carries, and when each piece runs out |

The Dart mirrors live in `lib/domain/entities/`, one file per entity, each a plain
immutable class with no persistence knowledge.

## The entry kinds

A fill-up, a service, a cost and a reading are separate tables rather than one
polymorphic `entries` table with a type column. They genuinely differ:

| | Answers | Distinct fields |
|---|---|---|
| `fuel_entries` | how much fuel, how far, how efficient | `volume_l`, `full_tank`, `missed_fill`, `price_per_l` |
| `service_entries` | what was done to the car | `service_type_key`, parts/labour split, warranty, fault codes |
| `cost_entries` | what it cost to keep | `category`, `amount` |
| `odometer_entries` | how far it has gone | `odometer_km`, and nothing else |
| `trip_entries` | where it went, and whether it was work | `from_place`, `to_place`, `distance_km`, `purpose`, `minutes` |
| `income_entries` | what it brought in | `category`, `amount` |

Only fuel has an economy calculation; only service participates in reminder
projection; only a reading has no money at all; only a trip is measured in
distance rather than in currency; and income is the only one that adds rather
than subtracts. A single table would have carried a majority of null columns and
a type check in front of every query.

A **trip stores its own distance** rather than deriving it from its odometer
range, because the two are different claims. A range says what the car did
between two readings; a trip's distance is what that journey covered, and a day
of errands between two readings is several trips. The range is still recorded
when it is known, and the entry form derives the distance from it as a
convenience.

**A trip with no distance is a drive still under way.** That is the whole of the
draft state added by `supabase/migrations/0054_trip_drafts.sql`: `distance_km`
became nullable, `started_at` records when the car set off, and filling the
distance in is what finishes the journey. There is no status column and no
second table, so nothing already logged became a draft — every existing row has
a distance.

Two constraints keep the state honest. A row may only lack a distance if it has
a `started_at` (so a plain insert that forgets the distance is rejected rather
than quietly opening a drive), and a partial unique index holds a vehicle to one
open drive at a time — a car cannot be on two journeys at once, and a double tap
would otherwise leave a second draft that finishing the first appears to lose.

`TripDraft` (`lib/domain/entities/trip_draft.dart`) is the domain half, and
`finishDraft` turns one into a `TripEntry`: the distance comes from the odometer
range unless one is stated outright, the duration is the time the drive was
open, and the trip is dated **the day it set off** — a drive over midnight
belongs to the evening it began. It throws rather than logging a zero when
nothing was measured, because a journey nobody measured is not a journey of
length zero and a silent 0 drags down every average that reads it.

Finishing is an `update`, so the row keeps its id and — through the trigger from
`0041` — its author. Any member can close a drive somebody else opened, which is
the shared-garage case: one person takes the car, another closes the logbook.

**An observation is something noticed and not settled** — a rattle when cold, a
vibration since a pothole, a warning light that came on once
(`supabase/migrations/0060_observations.sql`). It is deliberately one table
rather than three: a driving event, a symptom and a note for the mechanic are
the same shape, and an event is simply an observation that carries the
`trip_id` of the journey it happened on.

Two columns hold the state, and the split is the point. `addressed_by` records
that a service did work about it; `resolved_on` records that the symptom
stopped. A repair that did not help leaves the first set and the second null —
`ObservationState.stillThere` — which is the row the handover sheet leads with
and the thing a single "done" flag cannot say.

Observations do **not** appear in the timeline. The timeline is what happened
and what it cost; a problem is a state, and one open for four months would push
four months of entries down the page while saying nothing new. They live on the
vehicle instead.

**Income exists so "what has this car cost me" can be a complete answer.** The
sale price in particular has nowhere else to live, and without it every running
cost is an overstatement.

An odometer reading is the newest and the smallest of the four. It exists because
maintenance projection needs to know how far a car has gone and could previously
only learn that from something the owner paid for: an owner who services their
car but pays cash at the pump had to invent a fill-up. Everything it carries is
a date and a number, and adding anything else would defeat the point.

The timeline (`lib/features/timeline/`) is what re-unifies them for display,
`OdometerHistory` (`lib/domain/fuel/odometer_history.dart:33`) re-unifies their
odometer readings for measurement, and `StatsData`
(`lib/features/stats/providers/stats_providers.dart:41`) re-unifies them for
statistics. Those three are the only places that need to think about every kind
at once — and `test/support/vehicle_entries.dart` exists so adding a kind is one
edit in the test harnesses rather than one per harness.

## A vignette carries what it was bought for

`cost_entries` has two columns that mean something only for one category:
`vignette_country` and `vignette_validity`, null everywhere else. This is a
narrower exception to "distinct fields belong on distinct tables" than it
looks — the sheet had always *asked* which country and how long, computed an
expiry from the answer, and then discarded both the moment the sheet closed.
Editing an existing vignette restored the amount and the notes and silently
forgot what it was even for.

`VignetteCountry.code` (ISO 3166-1 alpha-2) and `VignetteValidity.key` are the
stored forms — language-neutral, like every other stored choice in this
schema — and `RecurringCosts.nextDue` (`lib/domain/maintenance/recurring_costs.dart`)
is what turns them into the reminder's due date. See decision 61 for why the
reminder that date raises does **not** default to on for this one category the
way it does for registration and insurance.

## Vehicles

A vehicle's **baseline** (`supabase/migrations/0003_vehicles.sql:14`) is the
odometer and date from which tracking starts, not the first recorded fill-up.
It exists so maintenance that has never been done on record can still be
projected: without it, a car bought at 90,000 km would look like it has never had
an oil change and everything would read as wildly overdue.

Fuelio import sets it from the oldest reading in the backup
(`lib/domain/import/fuelio_backup.dart`, `vehicleFromFuelio`), because a later
baseline would place imported history before the vehicle existed.

Vehicles are **archived, never deleted** from the UI
(`lib/features/vehicles/data/vehicle_repository.dart:12`): history stays intact
for a car that has left the household. Hard deletion exists but is admin-only at
the database level, see [06-security-and-tenancy.md](06-security-and-tenancy.md).

A vehicle may also say how its camshaft is driven (`timing_drive`: belt, chain,
or a belt running in oil) and what gearbox it has (`transmission`), both from
migration 0046 and both null until someone sets them. Inside the app nothing
reads them but the reminder sheet's choice of a default interval — see
[04-maintenance-projection.md](04-maintenance-projection.md#where-a-default-comes-from);
the public API exposes them on `/vehicles` ([public-api.md](../public-api.md)).
They are on the vehicle rather than inferred from the make because one make
sells all three timing drives in one model year.

A vehicle may carry what the household **paid** for it (`purchase_price`,
migration 0039) and what they reckon it is **worth now** (`current_value` with
`valued_on`, migration 0050). The second exists because depreciation is the
largest cost of owning a car and appeared in no figure the app printed: with
both, the vehicle page shows what the car costs to *own* beside what it costs
to run (`lib/domain/costs/running_cost.dart:129`). It is hand-entered rather
than looked up — see decision 96 — and `valued_on` is stamped by the form on
the day the figure changes, so a valuation over a year old is flagged as one
rather than quoted as today's.

A vehicle also has a **kind** — `car`, `motorcycle` or `van`, never null,
migration 0047 — and a motorcycle may say its **final drive** (`chain`,
`belt`, `shaft`). The kind decides which service types are offered (a
motorcycle is not offered a cabin filter; a car is not offered chain
lubrication) and whether the per-make interval overlay applies (it is sourced
from car schedules, so a motorcycle skips it). The final drive decides whether
there is a chain to lubricate. Every row from before the column existed is a
car, which is what it was. The kind also shapes the tread sheet: a motorcycle
is asked for a front and a rear rather than four corners, stored in the
front-left and rear-left columns, since nothing reads a corner on its own
(decision 88).

## Documents are not an entry kind

`vehicle_documents` looks like a seventh entry kind and deliberately is not
one. An entry is something that *happened* on a date and carries an odometer;
a document is a piece of paper whose only interesting property is when it
stops being valid. The distinction is load-bearing in two places:

- `test/ci/entry_kinds_wired_test.dart:12` lists the six entry tables and
  asserts, among other things, that every one of them carries an odometer the
  push sender can read. A document carries none, so adding it there would have
  to be weakened rather than satisfied.
- The CSV importer, the timeline and the odometer series all merge entry kinds
  and would have nothing to do with a document.

What it does share is the plumbing that matters: RLS scoped through
`user_vehicle_ids()`, the realtime publication with `replica identity full`
(`supabase/migrations/0049_vehicle_documents.sql:106`), the backup
(`lib/domain/export/garage_backup.dart:65`), the CSV export, and a fourth
`attachments.entry_kind` so a photo of the paper hangs off the row.

**One row per vehicle per type**, enforced by a partial unique index that
exempts `other` (`supabase/migrations/0049_vehicle_documents.sql:61`). A car
holds one current registration certificate; renewing it is a new expiry on
the same row. The history of what was *paid* stays in `cost_entries`, which is
where it always was.

**The reminder is the point, and it is not a new mechanism.** Each type maps
to the maintenance service type its paperwork already had
(`lib/domain/entities/vehicle_document.dart:42`), and saving a document with
an expiry writes a one-time `reminder_rules` row dated on it. That is what
makes a registration appear on the dashboard, in the planner and in a
notification without any of them learning what a document is — and it means
the cost sheet and the document sheet settle the *same* reminder rather than
raising two that contradict each other. The later write wins, which is the
document whenever a household keeps one, because it carries the date printed
on the paper instead of twelve months from the payment.

`DocumentType.other` maps to no service type and so raises no reminder. The
sheet says so rather than staying silent about it.

**Not modelled:** a driving licence. It belongs to a person, not to a car, and
both this table and the attachments bucket are scoped by vehicle.

## Household settings that change behaviour

`households` carries more than a name, and each field changes what the app does:

| Column | Effect |
|---|---|
| `distance_unit`, `volume_unit`, `currency_code` | Display only. Storage stays km, litres, and the household currency |
| `bundling_window_days`, `bundling_window_km` | How close two due items must fall to be suggested as one visit, see [04](04-maintenance-projection.md) |
| `tracking_level` | How much a service entry asks for, see `lib/domain/maintenance/tracking_level.dart:7` |
| `country_code` | Which statutory items (registration, roadworthiness) are offered |

## Sharp edges

- **"Cost" is overloaded.** A `cost_entries` row is an expense. A `service_entries`
  row also has a cost. Fuel has a total. "What did this car cost" therefore means
  summing three tables, which is what the stats layer does, and it is easy to
  write a query that quietly counts only one.
- **`service_types` is two things in one table.** Rows with a null `household_id`
  are the built-in presets shared by everyone and are not writable; rows with a
  household are that household's own. Any query over service types must be
  explicit about which it wants.
- **A partial fill is not a smaller fill-up.** It changes what the economy
  algorithm can compute at all, see [03-fuel-economy.md](03-fuel-economy.md).
- **`created_by` is attribution, not ownership.** It cannot be rewritten (the RLS
  suite asserts this) and it grants nothing. Deleting a member does not delete
  their entries, which is deliberate: the car's history outlives who logged it.
- **A route is a label, and losing it does not lose the drives.**
  `trip_entries.route_id` is `on delete set null`, so deleting a route unfiles
  the journeys rather than deleting them. The unique index is on
  `lower(name)`, which is why every write trims and why
  `TripRoute.matching` folds case: an app that disagreed with the index would
  offer a name the database then refuses.
- **Deleting a household cascades hard.** Foreign keys are `on delete cascade`
  from `households` down. That is what makes account deletion work, and it is also
  why nothing in the UI offers to delete a household casually.
