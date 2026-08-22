// The twin of `lib/domain/maintenance/winter_tyre_period.dart`.
//
// Two copies exist because the push sender is Deno and the app is Dart, and
// the two must agree: the client stops scheduling dated reminders wherever
// push is configured, so a table that drifted here would send the household a
// date the app never shows. `test/ci/winter_tyre_twin_test.dart` fails if
// they diverge — the same guard `REMINDER_LEAD_DAYS` has.
//
// Only countries actually verified against a national source get a window.
// See the Dart file for the sources; do not add a country here without adding
// it there, and without checking it.

export const SEASONAL_SWAP_KEY = 'service_tire_swap_seasonal'

export type WinterTyreRule =
  | 'dated'
  | 'datedWhenWintry'
  | 'whenWintryOnly'
  | 'none'

export interface WinterTyrePeriod {
  rule: WinterTyreRule
  /// [month, day], 1-based month. Absent unless the rule is a dated one.
  start?: [number, number]
  end?: [number, number]
}

export const WINTER_TYRE_PERIODS: Record<string, WinterTyrePeriod> = {
  HR: { rule: 'dated', start: [11, 15], end: [4, 15] },
  SI: { rule: 'dated', start: [11, 15], end: [3, 15] },
  BA: { rule: 'dated', start: [11, 1], end: [4, 1] },
  RS: { rule: 'datedWhenWintry', start: [11, 1], end: [4, 1] },
  AT: { rule: 'datedWhenWintry', start: [11, 1], end: [4, 15] },
  DE: { rule: 'whenWintryOnly' },
}

export type SwapDirection = 'to_winter' | 'to_summer'

export interface SeasonalSwap {
  date: Date
  direction: SwapDirection
}

export function winterTyrePeriodFor(countryCode: string): WinterTyrePeriod {
  return WINTER_TYRE_PERIODS[(countryCode ?? '').toUpperCase()] ??
    { rule: 'none' }
}

/// The next swap this country puts on the calendar, or null where there is no
/// dated window to pin one to.
///
/// A swap falling *on* `today` is the next one rather than a missed one: the
/// tyres have to be on by the first day of the window.
export function nextSeasonalSwap(
  countryCode: string,
  today: Date,
): SeasonalSwap | null {
  const period = winterTyrePeriodFor(countryCode)
  if (!period.start || !period.end) return null

  const from = Date.UTC(
    today.getUTCFullYear(),
    today.getUTCMonth(),
    today.getUTCDate(),
  )
  const year = today.getUTCFullYear()
  const candidates: SeasonalSwap[] = []
  for (const inYear of [year, year + 1]) {
    candidates.push({
      date: new Date(Date.UTC(inYear, period.start[0] - 1, period.start[1])),
      direction: 'to_winter',
    })
    candidates.push({
      date: new Date(Date.UTC(inYear, period.end[0] - 1, period.end[1])),
      direction: 'to_summer',
    })
  }
  candidates.sort((a, b) => a.date.getTime() - b.date.getTime())

  for (const candidate of candidates) {
    if (candidate.date.getTime() >= from) return candidate
  }
  return null
}

/// Whether a vehicle's tyres are swapped with the seasons.
///
/// The twin of `TyreSeasons.swapsSeasonally`. An empty list means "not
/// tracked", never "all-season": tyre tracking is optional, and silence is not
/// evidence. Retired sets do not keep a swap alive.
export function swapsSeasonally(
  sets: { season: string; retired_at: string | null }[],
): boolean {
  const inUse = sets.filter((set) => set.retired_at === null)
  if (inUse.length === 0) return true
  return inUse.some((set) => set.season !== 'all_season')
}
