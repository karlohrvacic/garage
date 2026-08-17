# 03. Fuel economy

The full-tank algorithm, and the validation around odometer readings that keeps
it honest. Siblings: [02-domain-model.md](02-domain-model.md) for the entry
shape, [10-localization-and-units.md](10-localization-and-units.md) for how the
result is displayed.

> Jump to [Sharp edges](#sharp-edges): partial fills change what can be computed
> at all, the first fill-up produces no figure, and the lifetime average is not
> the mean of the points.

## Why this exists, and why it is built this way

Consumption is the number this kind of app is judged on, and the naive version is
wrong. Dividing one fill's volume by the distance since the last one assumes the
tank was equally full at both ends, which it almost never was.

The correct span is between **two fills that both brought the tank to full**. Over
that span the fuel burned is exactly what was put in after the first full tank, up
to and including the second: the tank starts full and ends full, so the difference
is what went through the engine. That is the whole idea, and
`lib/domain/fuel/fuel_economy.dart:32` states it in the same terms.

## How the algorithm works

`FuelEconomy.compute` (`lib/domain/fuel/fuel_economy.dart:54`) walks the log once:

1. **Sort by odometer, then date** (`lib/domain/fuel/fuel_economy.dart:77`).
   Entries arrive in whatever order the database returned.
2. **Wait for the first full tank.** Anything before it is skipped: there is no
   known starting point, so no span can begin (`fuel_economy.dart:105`).
3. **Accumulate.** Every subsequent entry adds its volume, and its cost when
   known, to the running span.
4. **Close on the next full tank.** Distance is the odometer difference, and the
   figure is `spanVolume / distance * 100` litres per 100 km.
5. **Start the next span at that same entry.** Each full tank both closes one span
   and opens the next.

A span produces a point only when it is unbroken and covers a positive distance
(`fuel_economy.dart:126`).

| Situation | What happens | Why |
|---|---|---|
| Partial fill mid-span | Volume counts toward the span, no point emitted | The tank is not at a known level, so the span cannot close here |
| `missedFill` set | Span is discarded entirely (`fuel_economy.dart:118`) | Fuel went in unlogged. Reporting it would show an implausibly good figure, which is worse than showing nothing |
| Zero distance between fills | No point | Two fills at the same reading say nothing about consumption |
| Cost missing on any entry in the span | Point still emitted, `costPerKm` null (`fuel_economy.dart:113`) | Distance data is still good; only the money is unknown |

### The tie-break that is easy to delete

At an identical odometer *and* date, a full tank sorts before a partial one
(`lib/domain/fuel/fuel_economy.dart:86`). Without that rule the two orderings are
both "valid" sorts, and which one you get depends on the order the rows arrived
in, so the same data can produce a different economy figure between runs. The
comment there records this; it is not a stylistic sort.

### The lifetime average

`FuelEconomy.average` (`lib/domain/fuel/fuel_economy.dart:154`) is
**distance-weighted**: total volume over total distance, not the mean of the
points. Averaging the points directly lets one short tank count as much as a long
motorway run, which flatters or punishes the figure depending on driving that has
nothing to do with the car.

## A car that runs on two fuels

`FuelEconomy.compute` takes an optional `primaryFuelKey` and, when the entries
name more than one fuel, computes **one chain of full tanks per fuel** rather
than one chain for the car. Averaging petrol and LPG together produced a figure
that was neither, which is the defect this closes.

An entry with no fuel of its own is taken to be `primaryFuelKey`. That matters
for a household that turns the second tank on part-way through: their older rows
carry null, and those belong to the chain of the fuel the car mainly runs on
rather than to a chain of their own. The provider passes it **only when the
vehicle is bi-fuel** (`lib/features/fuel/providers/fuel_providers.dart:30`), so
a single-fuel car's points stay unlabelled and behave exactly as before.

What this does **not** fix, and cannot from this data: the chains overlap in
distance. An LPG span from 1000 to 1500 km includes whatever was driven on
petrol in between, so each figure is an approximation of that fuel's consumption
over a period rather than a measurement of it. Every app that tracks a second
tank has the same limitation; the alternative is asking the driver to record
every switch of the changeover valve.

## Entering a fill-up

Two pieces of domain logic sit behind the entry sheet:

**Any two of volume, price per litre, total.** `FuelEntry.deriveThird`
(`lib/domain/entities/fuel_entry.dart:48`) fills in whichever is missing, and
returns null unless exactly two are known. Receipts show different pairs, and
retyping the third is arithmetic the app can do.

**Odometer bounds.** `OdometerBounds.forDate`
(`lib/domain/fuel/odometer_bounds.dart:10`) gives the window a reading must fall
in: no earlier fill may read higher, no later fill may read lower. The important
part is `excludingId` (`lib/domain/fuel/odometer_bounds.dart:24`), which drops the
entry being edited so it is never measured against its own stored reading.

This replaced a simpler rule that compared against the newest reading in the log.
That rule made editing an older fill-up impossible: the guard told the user their
reading was below the latest fill, which is true of every historical entry and
irrelevant to the one being changed. It also rejected backdated entries. The date
window is the correct frame because it is the only one that describes what an
odometer actually is: monotonic in time.

Same-day fills deliberately impose no order on each other
(`lib/domain/fuel/odometer_bounds.dart:8`): the stored date has no time of day, so
their sequence within the day is genuinely unknown and guessing would reject valid
data.

## Sharp edges

- **The first full tank yields nothing, and that is correct.** A user who logs one
  fill-up and sees no consumption figure has not hit a bug. Two full tanks are the
  minimum.
- **Economy is recomputed, never stored.** Editing or deleting any fill-up
  reshapes the spans around it, so caching a figure per entry would go stale
  invisibly. It is cheap: one pass over a vehicle's log.
- **`missedFill` is destructive to a span on purpose.** People reach for it rarely,
  so a span vanishing after someone ticks it looks like data loss. It is the
  algorithm refusing to report a number it cannot stand behind.
- **Bi-fuel and electric are not modelled in the span.**
  `lib/domain/fuel/energy_type.dart` classifies a vehicle's energy type, but
  `compute` treats every entry as one fuel. A car running petrol and LPG through
  the same log will produce figures that mix them.
- **Baseline odometer does not enter economy at all.** It is a maintenance
  concept, see [02-domain-model.md](02-domain-model.md). Economy only ever looks
  at fill-ups.
