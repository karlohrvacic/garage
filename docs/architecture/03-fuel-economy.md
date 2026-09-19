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
`lib/domain/fuel/fuel_economy.dart:48` states it in the same terms.

## How the algorithm works

`FuelEconomy.compute` (`lib/domain/fuel/fuel_economy.dart:68`) walks the log once:

1. **Sort by odometer, then date** (`lib/domain/fuel/fuel_economy.dart:90`).
   Entries arrive in whatever order the database returned.
2. **Wait for the first full tank.** Anything before it is skipped: there is no
   known starting point, so no span can begin (`fuel_economy.dart:124`).
3. **Accumulate.** Every subsequent entry adds its volume, and its cost when
   known, to the running span.
4. **Close on the next full tank.** Distance is the odometer difference, and the
   figure is `spanVolume / distance * 100` litres per 100 km.
5. **Start the next span at that same entry.** Each full tank both closes one span
   and opens the next.

A span produces a point only when it is unbroken and covers a positive distance
(`fuel_economy.dart:152`).

| Situation | What happens | Why |
|---|---|---|
| Partial fill mid-span | Volume counts toward the span, no point emitted | The tank is not at a known level, so the span cannot close here |
| `missedFill` set | Span is discarded entirely (`fuel_economy.dart:143`) | Fuel went in unlogged. Reporting it would show an implausibly good figure, which is worse than showing nothing |
| Zero distance between fills | No point | Two fills at the same reading say nothing about consumption |
| Cost missing on any entry in the span | Point still emitted, `costPerKm` null (`fuel_economy.dart:161`) | Distance data is still good; only the money is unknown |

### The tie-break that is easy to delete

At an identical odometer *and* date, a full tank sorts before a partial one
(`lib/domain/fuel/fuel_economy.dart:100`). Without that rule the two orderings are
both "valid" sorts, and which one you get depends on the order the rows arrived
in, so the same data can produce a different economy figure between runs. The
comment there records this; it is not a stylistic sort.

### The lifetime average

`FuelEconomy.average` (`lib/domain/fuel/fuel_economy.dart:184`) is
**distance-weighted**: total volume over total distance, not the mean of the
points. Averaging the points directly lets one short tank count as much as a long
motorway run, which flatters or punishes the figure depending on driving that has
nothing to do with the car.

### Good or bad, against this car's own history

`EconomyRange.of` (`lib/domain/fuel/fuel_economy.dart:226`) collapses a car's
points to its best and worst, and `fractionFor` places one figure in that span:
1 at the frugal end, 0 at the thirsty one. Two screens read it. The economy
gauge fills toward frugal, and the fuel log tints each row's figure green,
amber or red at thirds of the fraction
(`lib/features/fuel/widgets/fuel_entry_row.dart:71`).

**A fixed band was rejected.** 4 to 12 l/100km flatters a small diesel, pins a
large petrol car at empty, and means nothing at all for an electric one measured
in kWh. The question a driver has is whether this tank was good *for this car*,
which is the only version the app has the data to answer.

`of` returns null below two points, and below a spread of 0.05 — economy prints
to one decimal, so a narrower range is one the reader cannot see, and twelve
tanks that all worked out to 6.0 differ by about 9e-16 in floating point. A null
range leaves the figure in the ordinary text colour rather than inventing a
verdict out of a single reading.

## A car that runs on two fuels

`FuelEconomy.compute` takes an optional `primaryFuelKey` and, when the entries
name more than one fuel, computes **one chain of full tanks per fuel** rather
than one chain for the car. Averaging petrol and LPG together produced a figure
that was neither, which is the defect this closes.

An entry with no fuel of its own is taken to be `primaryFuelKey`. That matters
for a household that turns the second tank on part-way through: their older rows
carry null, and those belong to the chain of the fuel the car mainly runs on
rather than to a chain of their own. The provider passes it **only when the
vehicle is bi-fuel** (`lib/features/fuel/providers/fuel_providers.dart:56`), so
a single-fuel car's points stay unlabelled and behave exactly as before.

What this does **not** fix, and cannot from this data: the chains overlap in
distance. An LPG span from 1000 to 1500 km includes whatever was driven on
petrol in between, so each figure is an approximation of that fuel's consumption
over a period rather than a measurement of it. Every app that tracks a second
tank has the same limitation; the alternative is asking the driver to record
every switch of the changeover valve.

## What a fill-up is measured in

The quantity column is litres for a tank and kilowatt-hours for a battery: one
column, read two ways. **Which way is decided per fill-up, not per car.** A
quantity is kilowatt-hours, and is never converted, exactly when the entry's
own fuel is electric — its `fuelTypeKey`, or the car's main fuel when it names
none. `EnergyType.forEntry` (`lib/domain/fuel/energy_type.dart:29`) is that
rule, and a plug-in hybrid kept as petrol is the case it exists for: its
charges are kilowatt-hours though the car is not electric.

Until September 2026 the car decided, and where it mattered most nothing did:
the fill-up sheet converted whatever was typed from the household's volume
unit, a charge included. In a garage that pours US gallons, 50 kWh was stored
as 189.27, the log read "189.27 kWh" and the consumption came out 3.8 times too
high. A litre garage converts by one, which is why nobody in the closed test
saw it. Entries saved that way cannot be told apart from right ones, so nothing
corrects them.

Every place a fill-up crosses the unit boundary now goes through
`UnitPreferences.quantityToDisplay`, `displayToQuantity` and
`unitPriceToDisplay` (`lib/core/format/unit_format.dart:64`), which convert a
volume and a price per litre and leave a charge alone:

| Where | What follows the entry's own energy |
|---|---|
| Fill-up sheet | The amount and price on save (`fuel_entry_sheet.dart:729`), an edited entry's amount and price, the prices it guesses, the label and unit beside each field, the tank-size warning and the implied-consumption warning |
| Fill-up row, timeline | The amount, the tank's consumption, and the "cheaper nearby" gap, which is said per the unit the sheet prices by |
| Statistics, PDF reports | Totals, smallest and largest fill, consumption, best and worst price |
| Calculator | Seeds from tanks only, since every box on it is litres |
| CSV import | A file for an electric car is kilowatt-hours, whatever was said about gallons |

**A figure over many fill-ups is over one kind.** Litres and kilowatt-hours do
not add up, so a total, a record or an average is taken over the tanks when
there are any and over the charges when there are only those
(`EnergyType.measuredOver`, `lib/domain/fuel/energy_type.dart:41`). A garage
with a petrol car and an electric one reads the petrol car's figures, and the
electric car's are one choice of car away. **A car's headline average is in
its own energy** (`lib/features/fuel/providers/fuel_providers.dart:91`): a
plug-in hybrid's is its tanks'. The fuel log, the vehicle page, the fleet strip
and the calculator read that figure, and the seller's report works it out the
same way (`lib/features/reports/report_builder.dart:704`). Petrol and LPG are
both litres and stay blended there, as the vehicle page says above its split by
fuel.

**A tank is measured against its own kind.** The colour a row's figure gets
and its "worse than usual" note compare a charge with charges and a tank with
tanks (`lib/features/fuel/widgets/fuel_entry_row.dart:91`); against each other,
a plug-in hybrid's charges read "60% more than this car's usual". The vehicle
page's gauge scale, its best-and-worst caption and its chart take the tanks of
the car's own energy (`lib/features/vehicles/screens/vehicle_detail_screen.dart:663`),
where the charges had been drawn and captioned as litres; the charges have
their own figure in the split by fuel beneath. Petrol and LPG are compared
with each other everywhere, being one unit.

## Entering a fill-up

Two pieces of domain logic sit behind the entry sheet:

**Any two of volume, price per litre, total.** `FuelEntry.deriveThird`
(`lib/domain/entities/fuel_entry.dart:90`) fills in whichever is missing, and
returns null unless exactly two are known. Receipts show different pairs, and
retyping the third is arithmetic the app can do.

**Odometer bounds.** `OdometerBounds.forSamples`
(`lib/domain/fuel/odometer_bounds.dart:77`) gives the window a reading must fall
in: nothing logged earlier may read higher, nothing logged later may read lower,
and every kind of reading counts, not only fill-ups. The important part is
`excluding` (`lib/domain/fuel/odometer_bounds.dart:80`), which drops the reading
the entry being edited contributes, so it is never measured against itself.

This replaced a simpler rule that compared against the newest reading in the log.
That rule made editing an older fill-up impossible: the guard told the user their
reading was below the latest fill, which is true of every historical entry and
irrelevant to the one being changed. It also rejected backdated entries. The date
window is the correct frame because it is the only one that describes what an
odometer actually is: monotonic in time.

Same-day fills deliberately impose no order on each other
(`lib/domain/fuel/odometer_bounds.dart:9`): the stored date has no time of day, so
their sequence within the day is genuinely unknown and guessing would reject valid
data.

**The guesses are per fuel.** A new fill-up starts from the newest one of the
fuel going in (`fuel_entry_sheet.dart:405`), which on a car of one fuel is
simply the newest: the other fuel's last price is no guess at this one's, and
on a plug-in hybrid it is not even per the same unit. Changing the fuel on a car
that takes two takes back what the sheet guessed — the price, and a station
remembered from the other fuel's last fill-up — and guesses again
(`fuel_entry_sheet.dart:353`). A forecourt the phone is standing at stays, and
so does anything typed; its posted price is the chosen fuel's, and there is
none for a charge. An edit guesses nothing when its fuel is changed.

## How far a full tank goes

`fullTankRange` (`lib/domain/fuel/full_tank_range.dart:58`) is capacity over
the car's own measured consumption: a typical figure from the distance-weighted
average, plus the best and worst a tankful has worked out to. **Best economy is
the lowest consumption and so the longest range** — the two read in opposite
directions, which is the one thing in that file worth reading twice.

It shows on the statistics screen, under "On a full tank", for a chosen car or
for a garage that has only one (`stats_screen.dart:182`). It is silent for a
car with no tank capacity recorded, which is most of them, and for a garage of
two with no filter set: a tank belongs to one vehicle, and averaging a diesel
estate with a city runabout answers nobody's question.

**What used to be here, and why it is gone.** `estimateTankRange` counted down
from the last full tank towards empty and was shown on the dashboard, the fuel
log and the vehicle page. It depended on the odometer being current, and
between fill-ups it never is — `currentKm` is the *highest logged reading*
(`lib/domain/fuel/odometer_history.dart:99`), so a driver who logs at the pump
and nowhere else leaves it frozen at the fill-up. Measured: a fortnight and six
hundred kilometres after a full tank, with a rate of 43 km/day available in the
same call, it reported 60.0 of 60 litres and 706 km. It read as a full tank for
the entire tank and jumped back to full at each fill-up. Decision 152 has the
reasoning and what was lost with it.

Electric cars have no range figure at all
(`lib/features/fuel/providers/fuel_providers.dart:118`) — `tankCapacityL` is
litres and battery capacity is not modelled, so there is nothing to compute.

## Saying by how much, not just which way

The fuel log has always coloured each tank's economy green or red against the
car's own best and worst (`fuel_entry_row.dart:64`). That says *where* a tank
sits and never by how much, which is a verdict without its evidence.
`deviationFor` (`lib/domain/fuel/economy_deviation.dart:22`) supplies the
number, and the row states it flatly in muted type.

Two decisions inside it:

- **Measured against the other tanks, not all of them.** A tank inside its own
  baseline drags that baseline towards itself and under-reports how odd it was.
- **Three other tanks minimum, five percent noise floor** — the same numbers
  and the same reasoning `StationEconomy` already settled on: below three, one
  unusual tank simply *is* the average.

Deliberately not a warning. One cold winter tank earns a deviation, and a red
flag on a fill-up nobody can now undo is nagging about the past.

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
- **A charge and a tank share a column.** `volumeL` and `pricePerL` hold
  kilowatt-hours and a price per kilowatt-hour for a charge, and nothing in
  the type says so. Anything that reads them has to ask `EnergyType.forEntry`
  which they are; converting one as litres is the bug recorded above.
- **Baseline odometer does not enter economy at all.** It is a maintenance
  concept, see [02-domain-model.md](02-domain-model.md). Economy only ever looks
  at fill-ups.
