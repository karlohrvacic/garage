# 04. Maintenance projection and bundling

How a recurring rule becomes a date on a calendar, and how items due near each
other become one shop visit. Siblings:
[02-domain-model.md](02-domain-model.md) for the rule and service tables,
[08-reminders-and-notifications.md](08-reminders-and-notifications.md) for what
happens when something falls due.

> Jump to [Sharp edges](#sharp-edges): the fallback rate hides thin history,
> overdue items are clamped to today before grouping, a bundle anchors to its
> earliest deadline for a reason, and suggestions stop at twelve weeks out.

## Why this exists, and why it is built this way

A service interval is written as "every 15,000 km or 12 months, whichever comes
first". A calendar needs a date. Turning the first into the second requires
knowing how fast this particular car accumulates distance, which the app already
knows from the odometer readings on its fuel entries.

The alternative, asking manufacturers, was rejected during planning
([`plan.md`](../plan.md)): OEM schedules are proprietary, US-centric, and priced
per call or in the four figures for a bulk dataset. For a free app with EU users
that is a recurring cost with no revenue behind it. User-defined intervals with
sensible presets are the pragmatic answer, and they have the side benefit of
being correct for a car that is driven unusually.

## Where a default comes from

A preset is where a rule *starts*, and since September 2026 the start depends
on the car. `IntervalDefaults.resolve`
(`lib/domain/maintenance/interval_defaults.dart`) is asked when a service type
is picked in the rule sheet, and answers from the first of these that applies:

1. **The drivetrain**, for the timing belt, water pump and gearbox oil. A chain
   needs no interval; a belt that runs in oil gets 100,000 km / 6 years, the
   floor of the wet-belt intervals in the spike, the one PureTech was revised
   down to; a dry dual-clutch gearbox is sealed. These vary by engine, not make, which is
   why `vehicles.timing_drive` and `vehicles.transmission` exist (migration
   0046) and why nothing keys a belt on the badge.
2. **The fuel**, for the fuel filter: 40,000 km / 4 years on a diesel, 90,000 km
   on anything else that burns fuel, nothing on an electric car.
3. **The make**, for oil, coolant, cabin and air filter, from the hand-built
   overlay in `lib/domain/maintenance/make_intervals.dart`. Every row cites the
   research spike (`docs/research/2026-09-02-service-interval-presets-spike.md`)
   and a test refuses a row that does not. The shorter official regime always
   wins: LongLife is never the default.
4. **The type's own preset**, which is what every rule started from before.

The sheet says which of these it used, in one line under the fields, and the
saved rule remembers none of it: `reminder_rules` stores the number the person
saved, exactly as before.

`availableServiceTypesProvider` is keyed by vehicle for the same reason: a
diesel is not offered spark plugs, an electric car is not offered an oil change,
because a prefilled number beside a type that does not apply looks like advice.
The vehicle's kind filters the same way: a motorcycle is offered chain
lubrication, chain and sprockets, fork oil and valve clearance (presets from
migration 0047) and not the car-only set in `_carOnly` — cabin filter, wheel
alignment, tyre rotation, seasonal swap, serpentine belt, air-conditioning
service, wipers, glow plugs, DPF and AdBlue; a
shaft- or belt-driven motorcycle loses the two chain items; a car or van is
offered none of the motorcycle four. A motorcycle
also skips step 3, the make overlay, because every row in it is a car schedule
and a Honda motorcycle is not a Honda car.

## Rate: how fast this car is used

`OdometerHistory.kmPerDay` (`lib/domain/fuel/odometer_history.dart:113`) takes
readings with their dates and divides. It returns **null** rather than a guess
when there is nothing to measure — fewer than two usable readings, no days
between them, or no distance covered — so the caller decides what an
unmeasurable rate means instead of being handed a number that looks measured.
`vehicleProjectionsProvider` falls back to `fallbackKmPerDay`
(`lib/domain/maintenance/reminder_projection.dart:74`), a deliberately modest
30 km/day.

**The rate is recent, not lifetime.** It is taken from the last
`rateWindowDays` — 90 — of the series, and only falls back to the whole series
when that window holds fewer than two readings or spans under 21 days
(`odometer_history.dart:115`). Dividing total distance by total age looks
harmless and is not: a car imported with four years of history barely moves its
rate when its owner starts commuting, and *every* distance-based date it has is
then months late, all in the same direction — and worse, it can hide which
deadline is binding at all, since a distance date pushed far enough out simply
loses to the calendar. Decision 51 has the numbers from the report that
surfaced it.

The window is anchored to the series' own last reading rather than to today, so
the function stays pure and a car parked for a season still reports the rate it
was driven at — which is what the projection's current-odometer figure already
assumes. The 21-day floor is what stops two fills a week apart on a road trip
from trebling every projection the car has.

Anchoring to the last reading is what makes a *future-dated* one dangerous, and
why `OdometerHistory.sorted` drops them. One entry with a fat-fingered year
becomes the series' last reading, so the 90-day window opens in the future and
the real recent driving falls outside it; the rate then falls back to the whole
series and comes out far too low. `currentKm` takes the highest reading whatever
its date, so where the car stands jumps forward at the same time. The two errors
pull the projection in opposite directions and both are wrong.

The pickers now stop at today as well (`lib/core/widgets/date_pickers.dart:12`),
which is the cheapest place to catch a fat-fingered year. That is a
convenience, not the guard: the guard stays in the domain because the entry
sheets are not the only door: the Fuelio and CSV importers and a restored backup
all write entries without passing one. `odometerSamplesProvider`
(`lib/features/odometer/providers/odometer_providers.dart:69`) is the single
funnel every consumer of the series comes through — the rate, the current
reading, and the projections — so it is the one place the clock has to be
supplied. Readings are dropped, not clamped: the true date is unknowable and a
guess would be another wrong reading. `rawOdometerSamplesProvider` stays
unfiltered, because the fill-up sheet's plausibility check needs to see exactly
the contradictions this removes.

Modest is the point: a low assumed rate pushes projections further out, so a car
with no history reads as "nothing due yet" rather than nagging on the day it was
added.

**Where the readings come from matters more than the arithmetic.** The series is
merged from every source that records an odometer — fill-ups, services, cost
entries that carry one, and standalone readings — not from fill-ups alone. It
used to be fill-ups alone, and that made the whole projection silently wrong for
anyone who paid cash at the pump. `OdometerHistory.sorted` also keeps one reading
per day (the highest) and drops anything that goes backwards, because two points
zero days apart drag the rate towards nothing and a reading below an earlier one
means somebody mistyped.

## Projection

`ReminderProjector.project` (`reminder_projection.dart:74`) resolves one rule:

| Input | Meaning |
|---|---|
| `lastServiceDate` / `lastServiceOdometerKm` | When this item was last done, if ever |
| `baselineDate` / `baselineOdometerKm` | Stand-in when it never was, normally the vehicle's baseline |
| `currentOdometerKm` | Latest known reading |
| `kmPerDay` | From the function above |

The anchor is the last service, falling back to the baseline
(`reminder_projection.dart:88`). Both intervals are then projected and the
**earliest wins**, which is what "whichever comes first" means:

- **Distance**: `anchor + intervalKm` gives a due odometer; the gap to the current
  reading divided by the rate gives days out.
- **Time**: `anchor + intervalMonths` via `DateMath.addMonths`.

An item reads as due once it is within `dueWindow`, 14 days
(`reminder_projection.dart:47`).

### The DST detail

Days are added by rebuilding the calendar date, not by adding a `Duration`
(`reminder_projection.dart:110`). Adding 24-hour durations to a local `DateTime`
drifts by an hour across a daylight-saving boundary, and enough of those turn a
midnight into the previous evening, which moves a due date by a day. Rebuilding
keeps it on calendar midnight.

### A predicted date and a deadline are different claims

`ReminderProjection.isPredicted` (`reminder_projection.dart:66`) is true when the
**distance** dimension is what binds. That date is remaining kilometres over a
measured driving rate, so it moves every time somebody logs a reading — a
forecast, and a good one, but not something anyone promised. A month interval
and a one-off's own date are deadlines: they are what they say.

The maintenance row words the two differently — *Expected 12 Jun 2027* against
*Due 1 Jan 2028* (`maintenance_screen.dart:501`). Before that both read "Due",
so an extrapolation looked exactly like a registration that genuinely expires
on the day it named. Two deadlines landing on the same day read as the
deadline: nothing is gained by hedging a date the calendar also guarantees.

### The seasonal tyre swap is pinned, not projected

`ReminderProjector.pinToSeasonalSwap` (`reminder_projection.dart:232`) replaces
a `service_tire_swap_seasonal` projection with the country's next statutory
date, and `vehicleProjectionsProvider` applies it
(`lib/features/maintenance/providers/maintenance_providers.dart:172`).

The rule ships as a six-month interval, which anchors on whenever the last swap
was logged and drifts from there — a swap done in late June puts the next one
just before Christmas, a date nothing in the world happens on. The window is
national and fixed, so the honest projection is the statutory date. The result
is deliberately built as a **dated** item (no fraction, no due odometer): a
fixed calendar date is not "half consumed" in January in any sense a reader
would recognise, and `dueness` already handles dated items with a 90-day
approach.

Countries with no verified window keep the interval. See
`lib/domain/maintenance/winter_tyre_period.dart` and
[08-reminders-and-notifications.md](08-reminders-and-notifications.md).

### Further out

The runway is twelve weeks. The first reminder most people set is an oil
change a year away, and the planner answered it with "Nothing due in the next
12 weeks" and nothing else, which read as a failed save. `furtherOutProvider`
(`lib/features/planner/providers/planner_providers.dart`) is everything past
the horizon, soonest first, never anything overdue (that anchors at today and
belongs to the runway); the planner lists it under the runway, grouped by
month. The reminder sheet also says what it set, in a snackbar, and so does
the fill-up sheet — with "one more full tank and consumption appears" on the
first full fill, because "Average —" on the dashboard gave no reason.

## Bundling

`BundlingEngine.bundle` (`lib/domain/maintenance/bundling.dart:68`) clusters
projections that fall close together, so a household makes one trip instead of
three. The window comes from the household's settings, defaulting to
`BundlingWindow.defaults` (`bundling.dart:11`).

Three rules make the output trustworthy:

**Overdue items are clamped to today before grouping**
(`bundling.dart:76`). An item three months late has a date in the past, which
would put it out of range of everything upcoming and defeat the feature. A late
oil change should absolutely be bundled with the plugs due in three weeks.

**A bundle's date is its earliest deadline**, not its latest or its mean
(`bundling.dart:47`). Anchoring anywhere later would schedule at least one item
past its own deadline, and for a statutory item like a roadworthiness test that is
not a rounding error.

**A suggestion more than `BundlingEngine.suggestionHorizon` away is not made**
(`bundling.dart:78`). Proximity says which items belong together; the horizon says
when saying so is any help. Without it, a car with a three-year oil interval was
told today to combine four items into a visit in 2028 — correct, useless, and
pinned to the top of the dashboard for two and a half years. The horizon is
twelve weeks, the same span the planner's runway draws, and
`test/features/planner/planner_providers_test.dart` fails if the two drift apart.
The filter is on the visit date, not per item, so a group anchored inside the
horizon keeps members trailing just past it — those are the reason to make one
trip instead of two.

### Both deadlines, not just the binding one

A rule with a distance *and* a month interval has two deadlines.
`ReminderProjector` computes both (`reminder_projection.dart:158`,
`reminder_projection.dart:163`), keeps them on the projection as
`dateFromDistance` and `dateFromTime`, and sets `projectedDueDate` to the
earlier. It used to discard the loser, which meant the row could not say the
one useful thing the odometer history was for: *the calendar says July 2028,
but you will be at 77,006 km by autumn 2027.*

`_otherDeadline` (`lib/features/maintenance/screens/maintenance_screen.dart:466`)
renders the non-binding one, and only when both exist and fall on different
days. Above the list, the same screen states the rate every distance date was
extrapolated from, or says the rate is assumed
(`maintenance_screen.dart:204`) — a projection built on the fallback used to be
indistinguishable from one built on four years of driving.

Everything else still reads `projectedDueDate` alone. Bundling, the runway, the
state chip and the notifications all want one date per item; carrying two
through them would be a far larger change than putting a second line on a row.

`MaintenanceBundle.exclude` (`bundling.dart:56`) removes an item and recomputes,
returning null below two items, so a dismissed suggestion never leaves a stale
date on screen and a single item is never called a bundle.

Both the bundle and its items sort deterministically, with a tie-break on rule id
(`bundling.dart:36`), so the same data always renders in the same order.

## Sharp edges

- **The extrapolated date is a claim about the future.** A rule 16 months out is
  dated from a 90-day sample, and the further out it is the less the sample is
  worth. The row hedges with "not until" and states the rate it used, which is as
  far as honesty goes without inventing a confidence interval the data cannot
  support.
- **A car nobody logs has no rate at all.** The series is merged from every
  source that records an odometer, so paying cash at the pump is no longer fatal
  — but a vehicle with no fill-ups, no services and no readings still falls back
  to the assumed 30 km/day, and nothing on screen says so.
- **The window makes the rate livelier than it was.** Ninety days of unusual
  driving — a long trip, a month off the road — now moves every distance-based
  date on the car, where the lifetime average would have absorbed it. That is
  the intended trade, but it does mean due dates move more than they used to.
- **There are two `kmPerDay` functions.** `ReminderProjector.kmPerDay`
  (`reminder_projection.dart:81`) is the older one, superseded by
  `OdometerHistory.kmPerDay` and called from nothing but its own tests. It takes
  parallel lists rather than samples and has no window, so a change made to the
  wrong one would look applied and do nothing.
- **Projections are computed, never stored.** They shift whenever a fill-up or a
  service is logged. Nothing caches them, and nothing should without an
  invalidation story.
- **`baseline` is doing quiet work.** A wrong baseline (an imported vehicle, or a
  car added with a guessed odometer) moves every never-done item at once.
- **One-time rules take a different path** (`reminder_projection.dart:93`,
  `_projectOneTime`) and do not repeat. They are the same table with `oneTime`
  set, so a query over reminder rules can silently mix the two kinds.
- **Coolant on a Kia, a Mazda or a Nissan is the first fill.** The overlay says
  210,000 km / 10 years, 200,000 km / 10 years and 145,000 km / 8 years, which
  is the manufacturer's first change; the second comes at 30,000 km / 2 years,
  100,000 km / 5 years and 90,000 km / 4 years (the spike has Nissan at
  90,000 mi / 96 months first, then 54,000 mi / 48 months). A rule fires on
  the first and the person edits it then. Modelling "first, then" intervals
  was not worth a schema change for three makes.
- **A make with a condition-based oil service has no oil row.** BMW and Ford are
  generic on purpose: the car's own indicator is the authority, and a number
  beside it would compete with it. The absence is deliberate, not a gap to fill.

## Where the driving rate is shown

The maintenance page has always said which rate a projection rests on
("Estimated from 196 km/day over the last 3 months", or the assumed rate).
Since decision 78 the dashboard's Due soonest row says it too, but only for
a projection whose distance deadline is the one that won: a date the
calendar decided rests on nothing the rate could change.

## When there is no rate

Since decision 79 a driving rate needs at least fourteen days between its
first and last reading (`OdometerHistory.minimumSeriesDays`); below that it
is null. The projector (`ReminderProjector.project`, `kmPerDay` nullable)
then makes no distance date for a rule that also has a calendar interval,
and assumes `fallbackKmPerDay` only for a rule that has nothing else. The
maintenance page states the measured span; the dashboard says "by date" for
a distance rule projected by the calendar.
