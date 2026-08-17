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
(`lib/features/stats/providers/stats_providers.dart:57`) does the filtering in
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

## Rates: what a total works out to

`SpendRate` (`lib/domain/stats/spend_rate.dart:11`) carries a total together
with the two things worth dividing it by — the days in the period and the
distance covered in it.

Both divisors travel with the total so no screen can show one without the other
being available. `perDay` and `perKm` return **null** rather than zero when
there is nothing to divide by: a household that logs registration and insurance
but never an odometer reading has a real total and no distance, and zero would
be a lie.

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

## Sections, and why they can be hidden

The useful set genuinely differs by reader. Somebody running a company car wants
cost per kilometre and does not care which station they used; somebody chasing
economy is the other way round. Rather than guess, everything is on and anything
can be switched off, from a sheet on the screen itself
(`lib/features/stats/screens/stats_screen.dart:176`) rather than from Settings —
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
