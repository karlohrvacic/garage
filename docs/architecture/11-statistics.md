# Statistics

What the Statistics screen computes, over what period, and why the reader gets
to switch parts of it off.

**Code:** `lib/domain/stats/`, `lib/features/stats/`

---

## Why this exists, and why it is built this way

A car costs money in a way nobody can hold in their head. The log answers "what
did I pay in March"; statistics answers the questions the log cannot — is this
year worse than last, where is the money actually going, and what does this car
cost per kilometre.

The whole screen is **read-side**. It writes nothing, owns no table, and every
figure on it is derived from `fuel_entries`, `service_entries`, `cost_entries`
and `odometer_entries`. That is deliberate: a derived figure that turns out
wrong is a bug in one pure function, not a column that has to be backfilled.

## Period

Everything on the screen is taken over one period, chosen once and applied to
all three tabs. `StatsPeriod` (`lib/domain/stats/stats_period.dart:48`) resolves
to a `DateRange`, and `StatsData.within`
(`lib/features/stats/providers/stats_providers.dart:73`) does the filtering in
one place.

Filtering centrally is the point. A card that forgot to filter would quietly
report the whole log under a heading that says "this month", and nothing about
the number would look wrong.

Two details are load-bearing:

- **`DateRange` compares by calendar day, not by instant.** Entries are stored
  at UTC midnight, and a range built from the date picker carries whatever time
  of day the picker returned. Comparing instants drops the last day of every
  range a user picks by hand.
- **`days` counts both ends and never returns zero.** Every per-day average
  divides by it.

The **year/month comparison card is the exception**: it is always computed over
the whole log. "This year against last" inside a filter that says "this month"
would compare two slices of one month and label them years.

## A charge is not a volume

Litres and kilowatt-hours cannot be added, so every figure the fill-ups tab
takes over many fill-ups is taken over one kind: the total and its rate, the
comparison with the previous period, the smallest and largest fill, the
consumption records and economy by station. It is the tanks when the period has
any and the charges when it has only those, each read in its own unit.
`StatsData.chargeIds` (`lib/features/stats/providers/stats_providers.dart:66`)
says which fill-ups are charges, by the fuel that went in, or the car's own
when the fill-up names none. The costs tab's best and worst fuel price follow
the same rule, per the unit the fill-up sheet prices by (decision 169).

A garage with a petrol car and an electric one therefore reads the petrol car's
figures across the whole garage, and the electric car's once that car is
chosen; a second set of cards would need words the app does not have yet.

## Rates: what a total works out to

`SpendRate` (`lib/domain/stats/spend_rate.dart:11`) carries a total together
with the two things worth dividing it by — the days in the period and the
distance covered in it.

Both divisors travel with the total so no screen can show one without the other
being available. `perDay` and `perKm` return **null** rather than zero when
there is nothing to divide by: a household that logs registration and insurance
but never an odometer reading has a real total and no distance, and zero would
be a lie.

The records cards multiply the per-day rate out to a month and a year
(`lib/features/stats/screens/stats_screen.dart:40`): a year of 365.25 days, a
month a twelfth of it. The year is the figure people quote and are asked for.
Both are extrapolations — a period of three days still shows what a year at
that rate would come to — and nothing on the card says so (decision 179).

## Charts

**The odometer chart's axis is the calendar.** `TimeAxis`
(`lib/features/stats/time_axis.dart:11`) puts its ticks on month starts —
the finest of a month, a quarter, a half-year, a year, two and five that fits
five labels — with the year where the year turns and the month's name
elsewhere, and labels a span too short to cross a boundary by its two ends. Its
x is calendar months with the day interpolated, not days, because fl_chart
ticks at multiples of one interval and months are not one length; a day in
February is therefore a tenth wider than one in July (decision 179).

**A legend never cuts a figure short.** The spend donut measures its widest
amount in the style it is drawn in and gives every amount that width
(`lib/features/stats/widgets/spend_donut.dart:163`); the label takes what is
left. When even the swatch, the share and the amount would not fit the row,
the share is dropped before the amount is touched (decision 178). This widget
has broken three ways — an overflow, a ragged column, and an ellipsis in the
cents — and `test/features/stats/spend_donut_test.dart` holds all three.

## Breakdowns

`SpendBreakdown` (`lib/domain/stats/spend_breakdown.dart:36`) turns labelled
amounts into donut slices. It:

- sums by label, biggest first, and **drops anything that came to nothing** — a
  zero slice is invisible in the ring but still takes a legend row and a colour;
- groups a missing label and an empty one together, because a fill-up where
  nobody typed the station is one thing, not two;
- caps the list with `topN`, rolling the tail into an "Others" slice — but
  leaves a tail of exactly one alone, since an "Others" that *is* one named
  thing hides a name and gains nothing.

`SpendSlice.isOthers` exists so the legend can tell "Others" from "not
recorded". They look identical in a legend and are different facts.

## Economy by station, and why it is mostly silent

`StationEconomy` (`lib/domain/stats/station_economy.dart:32`) groups full-tank
economy by where the fuel was bought. It is the app's most easily-misread
statistic and is built to stay quiet.

**Attribution is exact, not approximate.** A span's fuel is what went in
*after* the opening full tank, up to and including the closing one — so the
closing fill's station is what bought the fuel that was burned, and the opening
tank's station is irrelevant because its fuel went before the span began.
`EconomyPoint.station` (`lib/domain/fuel/fuel_economy.dart:43`) records the one
station that supplied a span, and is **null** when a partial fill inside the
span came from somewhere else or named no station. Two stations' fuel burned
together measures neither.

**New fill-ups name the brand, and old ones are read as one.** A forecourt the
sheet recognised is logged as "INA" or "Petrol" (decision 170). Older fill-ups
kept the forecourt's own name, and the price feed says which brand that was
(`lib/domain/stations/station_brands.dart:11`), so they are counted under it
here and in the spending by station. Only for a garage in Croatia, whose feed
it is; until it has loaded, and offline, each name stands alone (decision
172).

**Three gates before anything is shown:**

| Gate | Why |
|---|---|
| ≥ 3 tanks per station | Below that a single unusual tank *is* the average |
| ≥ 2 qualifying stations | "Better at INA" needs something to be better than |
| Gap ≥ 5% | Smaller than the spread one driver produces between a motorway month and a city one |

Fuel brand is a small effect; how, where and when the car was driven are large
ones. The card therefore reads as an observation and says so on its face — the
caveat is not fine print to be trimmed. When the gates are not met the section
does not appear at all, because a card announcing "no difference" invites
exactly the comparison it is refusing to make.

**What this still cannot do.** It does not control for season, route, load or
tyre pressure, and it never will from this data. A driver who tanks at the
motorway station on long trips and in town elsewhere will see a difference that
is entirely about the driving.

## Sections, and why they can be hidden

The useful set genuinely differs by reader. Somebody running a company car wants
cost per kilometre and does not care which station they used; somebody chasing
economy is the other way round. Rather than guess, everything is on and anything
can be switched off, from a sheet on the screen itself
(`lib/features/stats/screens/stats_screen.dart:274`) rather than from Settings —
the person who wants a section gone is looking at it.

`hiddenStatsSectionsProvider`
(`lib/features/stats/providers/stats_section_providers.dart:17`) stores the
choice **on the device**, like the theme, not on the household: one member
hiding the station donut must not hide it for everyone else.

It stores **hidden** rather than visible, so a section added in a later release
turns up for people who had already customised the screen instead of being
invisible to exactly the readers who care most.

`StatsSection.key` is a hand-written string rather than `name`, so renaming the
Dart enum value cannot silently reset everybody's choices.

## The timeline totals itself

The timeline groups by month and, since August 2026, says what each month came
to and what the whole visible list came to. The arithmetic is `balanceOf`
(`lib/domain/stats/entry_balance.dart:33`), which takes a record —
`({double? amount, bool isIncome})` — rather than the timeline's own
`TimelineItem`, because a domain function has no business knowing what a fill-up
is. The screen adapts its rows with `_ledgerEntry`
(`lib/features/timeline/screens/timeline_screen.dart:517`).

**Net, signed, income-aware.** A month is `income − spending`, so a car earning
its keep as a taxi can show `+€117.60` in the household's success colour while
an ordinary month shows `−€65.40`. The minus is written explicitly rather than
left to `NumberFormat`, which brackets negatives in some locales.

**A row is not a transaction.** Odometer readings and trips carry no amount, and
a fill-up whose total was never typed in carries none either. They are rows in
the list but they do not move the balance and they are not counted — "12
transactions" means twelve amounts, not twelve entries. A month holding nothing
but readings shows no figure at all, and a list with no money in it closes
without a footer.

**Breaking even exactly reads as spent** (`entry_balance.dart:26`), because
"received €0.00" claims money arrived when none did.

**Both figures are of the filtered list.** The timeline has a search box and a
kind filter; totalling everything while showing a subset would put a header in
contradiction with the rows underneath it. Filtering to Fuel gives fuel totals.

This is the fourth place money gets bucketed by time, and the only one in the
domain layer — `_monthlySpend` in the stats screen
(`lib/features/stats/screens/stats_screen.dart:901`) still hand-rolls its own
per-month loop over fuel, services and costs, ignoring income. Worth collapsing
into `balanceOf` the next time either is touched.

## Sharp edges

- **A hidden section still computes.** Visibility is applied when building the
  widget list, not before the arithmetic. Cheap today at a few hundred entries;
  it would be the first thing to change if a household's log got large.
- **The monthly bar chart caps at 24 bars.** A longer period silently shows only
  the last two years of months, because beyond that the axis is unreadable. The
  cap is in `_monthlySpend` and nothing on screen says it applied.
- **Distance is summed per vehicle, never across them.** A fleet figure is the
  sum of per-vehicle spans; a span taken across two odometers is meaningless.
  Anything new that aggregates distance has to keep the grouping.
- **`statsDataProvider` loads a household's whole history** and filters in
  memory. That is what makes period switching instant, and it is also what would
  stop scaling first.
