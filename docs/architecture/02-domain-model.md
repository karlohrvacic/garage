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
                                                                    tyre_readings

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
| `trip_entries` | `supabase/migrations/0029_trips_and_income.sql:12` | A mileage logbook: where, how far, private or business |
| `income_entries` | `supabase/migrations/0029_trips_and_income.sql:41` | Money in, including what the car sold for |
| `attachments` | `supabase/migrations/0016_attachments.sql` | Receipts and documents, pointed at Storage |
| `tyre_sets`, `tyre_readings` | `supabase/migrations/0023_tyre_sets.sql` | A set as a thing in its own right, and its tread over time |

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
(`lib/features/stats/providers/stats_providers.dart:40`) re-unifies them for
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
- **Deleting a household cascades hard.** Foreign keys are `on delete cascade`
  from `households` down. That is what makes account deletion work, and it is also
  why nothing in the UI offers to delete a household casually.
