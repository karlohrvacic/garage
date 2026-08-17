# 04. Maintenance projection and bundling

How a recurring rule becomes a date on a calendar, and how items due near each
other become one shop visit. Siblings:
[02-domain-model.md](02-domain-model.md) for the rule and service tables,
[08-reminders-and-notifications.md](08-reminders-and-notifications.md) for what
happens when something falls due.

> Jump to [Sharp edges](#sharp-edges): the fallback rate hides thin history,
> overdue items are clamped to today before grouping, and a bundle anchors to its
> earliest deadline for a reason.

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

`OdometerHistory.kmPerDay` (`lib/domain/fuel/odometer_history.dart:88`) takes the
oldest and newest readings with their dates and divides. It returns **null**
rather than a guess when there is nothing to measure — fewer than two usable
readings, no days between them, or no distance covered — so the caller decides
what an unmeasurable rate means instead of being handed a number that looks
measured. `vehicleProjectionsProvider` falls back to `fallbackKmPerDay`
(`lib/domain/maintenance/reminder_projection.dart:74`), a deliberately modest
30 km/day.

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

Two rules make the output trustworthy:

**Overdue items are clamped to today before grouping**
(`bundling.dart:76`). An item three months late has a date in the past, which
would put it out of range of everything upcoming and defeat the feature. A late
oil change should absolutely be bundled with the plugs due in three weeks.

**A bundle's date is its earliest deadline**, not its latest or its mean
(`bundling.dart:47`). Anchoring anywhere later would schedule at least one item
past its own deadline, and for a statutory item like a roadworthiness test that is
not a rounding error.

`MaintenanceBundle.exclude` (`bundling.dart:56`) removes an item and recomputes,
returning null below two items, so a dismissed suggestion never leaves a stale
date on screen and a single item is never called a bundle.

Both the bundle and its items sort deterministically, with a tie-break on rule id
(`bundling.dart:36`), so the same data always renders in the same order.

## Sharp edges

- **The fallback rate is invisible in the UI.** A projection built on 30 km/day
  looks exactly like one built on measured history. For a car driven 100 km a day,
  early projections will be far too far out until enough fill-ups exist.
- **The rate comes from fuel entries.** A vehicle whose owner logs services but
  not fuel has no odometer history to measure, so every distance projection uses
  the fallback. This couples maintenance accuracy to fuel logging in a way nothing
  on screen explains.
- **Projections are computed, never stored.** They shift whenever a fill-up or a
  service is logged. Nothing caches them, and nothing should without an
  invalidation story.
- **`baseline` is doing quiet work.** A wrong baseline (an imported vehicle, or a
  car added with a guessed odometer) moves every never-done item at once.
- **One-time rules take a different path** (`reminder_projection.dart:93`,
  `_projectOneTime`) and do not repeat. They are the same table with `oneTime`
  set, so a query over reminder rules can silently mix the two kinds.
