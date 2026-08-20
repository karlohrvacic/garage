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
sensible presets are the pragmatic answer, and they have the side benefit of being
correct for a car that is driven unusually.

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

`_otherDeadline` (`lib/features/maintenance/screens/maintenance_screen.dart:415`)
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
