// What a fill-up says about consumption, worked out the way the app does it.
//
// The canonical rule is `FuelEconomy._computeChain` in
// `lib/domain/fuel/fuel_economy.dart`: economy only means something between two
// fills that both brought the tank to full, because the fuel burned over that
// span is exactly what went in after the first one, up to and including the
// second. The app walks a vehicle's whole log and returns every such span.
// A webhook is about one entry, so this ports one span only: the one that
// closes at the entry just logged.
//
// It is a second copy of a rule, in a language that cannot import the first,
// and the two disagreeing would put one figure on the phone and another in the
// household's chat with nothing to say so. `test/fixtures/economy_spans.json`
// is what holds them together: hand-computed cases that `economy_test.ts` runs
// here and `test/domain/fuel/economy_fixture_test.dart` runs over the Dart.
// Change the rule in one and the fixture fails the other.

/// The columns of a `fuel_entries` row the rule reads, in canonical units:
/// kilometres and litres, or kilowatt-hours where the car is electric.
export interface FuelRow {
  id: string
  /// `YYYY-MM-DD`. A Postgres `date` has no other spelling, and that one sorts
  /// correctly as text, so it is compared as text.
  entry_date: string
  odometer_km: number
  volume_l: number
  full_tank: boolean
  missed_fill: boolean
  /// Which fuel went in, on a car that takes two. Null on every other row.
  fuel_type_key: string | null
}

export interface ClosingSpan {
  litresPer100Km: number
  distanceKm: number
  volumeL: number
}

/// How far back the handler looks for the full tank that opened the span.
///
/// A span is normally two or three rows. Sixty leaves room for a car on two
/// fuels and a driver who tops up daily, without reading ten years of log on
/// every fill-up. A span longer than this comes out as no figure, which is
/// wrong but quiet, where an unbounded read would be slow on every call.
export const HISTORY_LIMIT = 60

/// The order the app sorts a chain in, tie-breaks included: odometer, then
/// date, then a full tank before a partial one at the same reading on the same
/// day. Without the last, two fills at one point come out in whatever order
/// they arrived and the span flips between them.
function inChainOrder(a: FuelRow, b: FuelRow): number {
  if (a.odometer_km !== b.odometer_km) {
    return a.odometer_km - b.odometer_km
  }
  if (a.entry_date !== b.entry_date) {
    return a.entry_date < b.entry_date ? -1 : 1
  }
  if (a.full_tank === b.full_tank) {
    return 0
  }
  return a.full_tank ? -1 : 1
}

/// The span that closes at [closing], or null when there is no figure to give.
///
/// [earlier] is the vehicle's other fill-ups, in any order. It may hold rows
/// that come after [closing] — a fill-up entered late has later ones already
/// in the log — and may even hold [closing] itself; both are dealt with here
/// rather than trusted to the query.
///
/// [primaryFuelKey] is what a row with no fuel of its own is taken to be, and
/// is passed exactly as the app passes it to `FuelEconomy.compute`: the
/// vehicle's main fuel when it takes two, null otherwise. Each fuel is its own
/// chain, so an LPG fill between two petrol ones is not part of the petrol
/// span.
export function closingSpan(
  closing: FuelRow,
  earlier: FuelRow[],
  primaryFuelKey: string | null,
): ClosingSpan | null {
  // Only a full tank closes a span: after a partial fill nobody knows how much
  // room was left.
  if (!closing.full_tank) {
    return null
  }

  const fuelOf = (row: FuelRow) => row.fuel_type_key ?? primaryFuelKey
  // `closing` goes in last and the sort is stable, so where the comparator
  // calls two rows equal the new one lands after the one already there —
  // which is where the app's own read, in insertion order, tends to put it.
  const chain = [
    ...earlier.filter((row) => row.id !== closing.id),
    closing,
  ]
    .filter((row) => fuelOf(row) === fuelOf(closing))
    .sort(inChainOrder)

  const end = chain.indexOf(closing)
  let start = end - 1
  while (start >= 0 && !chain[start].full_tank) {
    start--
  }
  // No full tank before this one: it is the baseline, not a result.
  if (start < 0) {
    return null
  }

  // Everything after the opening tank, the closing fill included. The opening
  // tank's own volume and its `missed_fill` belong to the span before it.
  // Summed oldest first, as the app does. Floating-point addition is not
  // associative, so the same litres added in another order can differ in the
  // last bit, and then the two copies agree to a tolerance instead of exactly.
  let volumeL = 0
  for (const row of chain.slice(start + 1, end + 1)) {
    // Fuel went in unlogged somewhere in here, so the honest sum is unknown
    // and the figure would flatter the car.
    if (row.missed_fill) {
      return null
    }
    volumeL += row.volume_l
  }

  const distanceKm = closing.odometer_km - chain[start].odometer_km
  if (distanceKm <= 0) {
    return null
  }
  return { litresPer100Km: volumeL / distanceKm * 100, distanceKm, volumeL }
}

/// A number, however it was spelled on the way here.
///
/// Postgres `numeric` reaches this function as a JSON number from both
/// `to_jsonb` and PostgREST today. A driver or a setting that turns it into
/// "42.800" must not turn a sum into string concatenation.
export function numberFrom(value: unknown): number | null {
  const parsed = typeof value === 'string' && value.trim() !== ''
    ? Number(value)
    : value
  return typeof parsed === 'number' && Number.isFinite(parsed) ? parsed : null
}

/// A stored row — the trigger's payload, or one read back — as a [FuelRow].
///
/// Null when anything the rule reads is missing. There are no defaults here on
/// purpose: a row whose `missed_fill` cannot be read is not a row that was
/// not missed.
export function fuelRowFrom(record: Record<string, unknown>): FuelRow | null {
  const odometerKm = numberFrom(record.odometer_km)
  const volumeL = numberFrom(record.volume_l)
  if (
    typeof record.id !== 'string' ||
    typeof record.entry_date !== 'string' ||
    odometerKm === null ||
    volumeL === null ||
    typeof record.full_tank !== 'boolean' ||
    typeof record.missed_fill !== 'boolean'
  ) {
    return null
  }
  return {
    id: record.id,
    entry_date: record.entry_date,
    odometer_km: odometerKm,
    volume_l: volumeL,
    full_tank: record.full_tank,
    missed_fill: record.missed_fill,
    fuel_type_key: typeof record.fuel_type_key === 'string'
      ? record.fuel_type_key
      : null,
  }
}

/// A whole history, or null if any row of it cannot be read.
///
/// All or nothing: leaving one bad row out would drop a partial fill from the
/// sum and report a better figure than the car earned.
export function fuelRowsFrom(records: unknown[]): FuelRow[] | null {
  const rows: FuelRow[] = []
  for (const record of records) {
    const row = typeof record === 'object' && record !== null
      ? fuelRowFrom(record as Record<string, unknown>)
      : null
    if (!row) {
      return null
    }
    rows.push(row)
  }
  return rows
}
