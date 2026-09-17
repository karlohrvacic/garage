import {
  humanise,
  line,
  LOCALE,
  NAME_LIMIT,
  oneLine,
  type Part,
  present,
  WORK_LIMIT,
} from '../_shared/chat_text.ts'
import { type ClosingSpan, numberFrom } from './economy.ts'

// What a chat target is told: a few lines a person can read in a chat window.
//
// The generic receiver gets the whole row and can make of it what it likes. A
// chat service shows text and nothing else, so what is worth saying has to be
// said here — how much went in and where, what it cost in the household's own
// currency, what the tank worked out to, and whatever the driver wrote down.
//
// Deliberately plain and English. The edge function has no access to the
// household's locale or to the app's ARB files, and a half-translated
// notification would be worse than a consistent one — the app's own screens
// remain the localised surface. That is also why a category is a tidied key
// ("Vehicle sale") rather than the app's label for it: the labels live in the
// ARB files, and a copy of them here would drift the first time one was
// reworded.
//
// Units are the household's. Storage is canonical — kilometres, litres, the
// household's currency — and the conversion happens here, at the edge, with
// the constants and the rounding of `lib/core/format/unit_format.dart`. The
// figures are the app's; the wording is not, and does not try to be. The app
// prints a volume to two fixed decimals in the reader's language, this prints
// "42.8 l" in English. And one rule differs on purpose: the app reads a
// fill-up in kilowatt-hours when the *car's* main fuel is electricity, this
// when the *fill's* is — see `electric` below.

export interface Units {
  /// ISO 4217, or null when the household could not be read — money is then a
  /// bare number, as it was before this knew the currency at all.
  currency: string | null
  distance: 'km' | 'mi'
  volume: 'liter' | 'us_gallon' | 'uk_gallon'
}

/// A `households` row as [Units], with the app's own fallbacks
/// (`preferencesFor` in `unit_providers.dart`): anything that is not `mi` is
/// kilometres, and anything that is not a gallon is litres.
export function unitsFrom(household: Record<string, unknown> | null): Units {
  const volume = household?.volume_unit
  return {
    currency: typeof household?.currency_code === 'string'
      ? household.currency_code
      : null,
    distance: household?.distance_unit === 'mi' ? 'mi' : 'km',
    volume: volume === 'us_gallon' || volume === 'uk_gallon' ? volume : 'liter',
  }
}

export interface MessageContext {
  /// The vehicle's nickname.
  vehicleName: string | null
  /// The display name of whoever logged the entry, when there is a profile.
  author: string | null
  units: Units
  /// Whether this entry's quantity is kilowatt-hours rather than litres.
  ///
  /// Decided by the fuel that went in. The app decides by the vehicle's main
  /// fuel (`vehicleEnergyProvider`), so a charge logged on a car that mainly
  /// burns petrol reads in litres on the phone and in kilowatt-hours here.
  /// Kept that way knowingly: a charge is kilowatt-hours whatever the car
  /// mainly burns.
  electric: boolean
  /// The span a fill-up closed, or null — always null for any other kind.
  economy: ClosingSpan | null
}

// The same constants as `unit_format.dart`, which is where to look before
// changing one. `test/fixtures/economy_spans.json` holds both copies to the
// same readings.
const KM_PER_MILE = 1.609344
const LITRES_PER_US_GALLON = 3.785411784
const LITRES_PER_UK_GALLON = 4.54609
/// Divide by l/100km to get miles per US gallon, and per UK gallon.
const MPG_US = 235.214583
const MPG_UK = 282.480936

/// How much of a note is worth a chat window's room.
const NOTE_LIMIT = 200

/// [value] rounded to [decimals] places the way the app rounds it.
///
/// A figure here and the same figure on the phone should not differ in the
/// last digit, and at a decimal half two correct formatters do. Dart's `intl`
/// takes the whole part off, multiplies the fraction up and rounds that, all
/// in binary floating point. `Intl.NumberFormat` rounds the number's shortest
/// decimal spelling instead, so 6.35 — stored a hair under — is 6.4 to it and
/// 6.3 to the app; `toFixed` rounds the exact binary value, and parts from the
/// app the other way (1.95 is 2.0 in the app). Run against the app's formatter
/// over two million values, only these three steps, repeated as written,
/// agreed everywhere. `Intl` is then handed a number with nothing left to
/// round. `readings.halves` in the fixture pins the cases on both sides.
function rounded(value: number, decimals: number): number {
  const size = Math.abs(value)
  const whole = Math.floor(size)
  const power = 10 ** decimals
  const result = whole + Math.round((size - whole) * power) / power
  return value < 0 ? -result : result
}

function decimal(value: number, most: number, least = 0): string {
  return new Intl.NumberFormat(LOCALE, {
    minimumFractionDigits: least,
    maximumFractionDigits: most,
  }).format(rounded(value, most))
}

/// [decimals] overrides the currency's usual precision: a price per litre is
/// quoted to a tenth of a cent on every forecourt, and two decimals would
/// round the part of it that differs.
function money(
  amount: number,
  currency: string | null,
  decimals?: number,
): string {
  const precision = decimals === undefined ? {} : {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }
  if (currency !== null) {
    try {
      const format = new Intl.NumberFormat(LOCALE, {
        style: 'currency',
        currency,
        ...precision,
      })
      // The currency knows how many decimals it has; the rounding to that
      // many is the app's, as everywhere else.
      const places = format.resolvedOptions().maximumFractionDigits ?? 2
      return format.format(rounded(amount, places))
        // `Intl` separates a code from its number with a no-break space,
        // which looks identical and compares unequal.
        .replace(/[\u00a0\u202f]/g, ' ')
    } catch {
      // The column promises three characters, not three letters, and `Intl`
      // throws on anything else. The message matters more than the symbol.
      return `${decimal(amount, decimals ?? 2, decimals ?? 2)} ${currency}`
    }
  }
  return decimal(amount, decimals ?? 2, decimals ?? 2)
}

function distance(km: number, units: Units, most: number): string {
  const value = units.distance === 'mi' ? km / KM_PER_MILE : km
  return `${decimal(value, most)} ${units.distance}`
}

/// Litres in whatever the household pours. A household reading litres has no
/// gallon of its own, which only matters to [economyText] and is settled
/// there.
function litresPerUnit(units: Units): number {
  switch (units.volume) {
    case 'us_gallon':
      return LITRES_PER_US_GALLON
    case 'uk_gallon':
      return LITRES_PER_UK_GALLON
    case 'liter':
      return 1
  }
}

/// Electricity is kilowatt-hours the world over: a household that pours
/// gallons still charges in kWh, and nothing is converted.
function quantityUnit(units: Units, electric: boolean): string {
  if (electric) {
    return 'kWh'
  }
  // Lower case, as the app writes it (`volumeSuffix`).
  return units.volume === 'liter' ? 'l' : 'gal'
}

function quantity(stored: number, units: Units, electric: boolean): string {
  const value = electric ? stored : stored / litresPerUnit(units)
  return `${decimal(value, 2)} ${quantityUnit(units, electric)}`
}

/// A price per litre, as a price per whatever the household buys. The price
/// converts the opposite way to the volume — a gallon is more litres, so it
/// costs more — and doing one without the other is out by nearly four times.
function pricePerUnit(perLitre: number, units: Units, electric: boolean) {
  const value = electric ? perLitre : perLitre * litresPerUnit(units)
  return `${money(value, units.currency, 3)}/${quantityUnit(units, electric)}`
}

/// The canonical figure in the household's units: `formatEconomy` in
/// `unit_format.dart`, rule for rule.
///
/// Litres per 100 km for a household on kilometres and litres. Any other
/// pairing reads miles per gallon, which is the inverse — the UK gallon for a
/// household that pours those, the US one for everybody else. Electricity is
/// never inverted: there is no mpg of a battery, so it stays "per 100", over
/// miles where the household reads miles.
export function economyText(
  perHundredKm: number,
  units: Units,
  electric: boolean,
): string | null {
  if (!(perHundredKm > 0)) {
    return null
  }
  if (electric) {
    return units.distance === 'km'
      ? `${decimal(perHundredKm, 1, 1)} kWh/100km`
      : `${decimal(perHundredKm * KM_PER_MILE, 1, 1)} kWh/100mi`
  }
  if (units.distance === 'km' && units.volume === 'liter') {
    return `${decimal(perHundredKm, 1, 1)} l/100km`
  }
  const constant = units.volume === 'uk_gallon' ? MPG_UK : MPG_US
  return `${decimal(constant / perHundredKm, 1, 1)} mpg`
}

type Entry = Record<string, unknown>

const words = (...parts: Part[]) => present(parts).join(' ') || null

function odometer(entry: Entry, units: Units): string | null {
  const km = numberFrom(entry.odometer_km)
  return km === null ? null : distance(km, units, 0)
}

function amount(value: unknown, units: Units): string | null {
  const parsed = numberFrom(value)
  return parsed === null ? null : money(parsed, units.currency)
}

/// "6.1 l/100km over 702 km": the figure, and how much road it was measured
/// over, because a figure from 80 km of town is not one from 700 of motorway.
function consumption({ economy, units, electric }: MessageContext) {
  if (economy === null) {
    return null
  }
  const figure = economyText(economy.litresPer100Km, units, electric)
  return figure && `${figure} over ${distance(economy.distanceKm, units, 0)}`
}

function fuelLines(entry: Entry, context: MessageContext): Part[] {
  const { units, electric } = context
  const stored = numberFrom(entry.volume_l)
  const station = oneLine(entry.station, NAME_LIMIT)
  const perLitre = numberFrom(entry.price_per_l)

  const price = perLitre === null
    ? null
    : pricePerUnit(perLitre, units, electric)
  const total = amount(entry.total, units)

  return [
    line(
      words(
        stored !== null && quantity(stored, units, electric),
        station && `at ${station}`,
      ),
      total && price ? `${total} (${price})` : total ?? price,
    ),
    line(consumption(context), odometer(entry, units)),
  ]
}

function serviceLines(entry: Entry, { units }: MessageContext): Part[] {
  const keys = Array.isArray(entry.service_type_keys)
    ? entry.service_type_keys
    : []
  const shop = oneLine(entry.shop, NAME_LIMIT)
  const work = keys
    .filter((key): key is string => typeof key === 'string')
    .map(humanise)
    .join(', ')
  return [
    line(
      oneLine(work, WORK_LIMIT),
      shop && `at ${shop}`,
      amount(entry.cost, units),
      odometer(entry, units),
    ),
  ]
}

/// A cost and an income are the same three facts with the sign reversed.
function moneyLines(entry: Entry, { units }: MessageContext): Part[] {
  return [
    line(
      // A key, and a key is as long as whoever wrote it liked.
      typeof entry.category === 'string' &&
        oneLine(humanise(entry.category), NAME_LIMIT),
      amount(entry.amount, units),
      odometer(entry, units),
    ),
  ]
}

/// The app's own "1 h 05 min": an hour and five minutes read as "65 min" is
/// arithmetic the reader has to do.
function duration(minutes: number): string {
  const whole = Math.round(minutes)
  const hours = Math.floor(whole / 60)
  const rest = whole % 60
  return hours === 0
    ? `${rest} min`
    : `${hours} h ${String(rest).padStart(2, '0')} min`
}

function tripLines(entry: Entry, { units }: MessageContext): Part[] {
  const from = oneLine(entry.from_place, NAME_LIMIT)
  const to = oneLine(entry.to_place, NAME_LIMIT)
  const km = numberFrom(entry.distance_km)
  const minutes = numberFrom(entry.minutes)
  const driver = oneLine(entry.driver, NAME_LIMIT)
  return [
    line(
      oneLine(entry.title, NAME_LIMIT),
      from && to ? `${from} → ${to}` : from ? `from ${from}` : to && `to ${to}`,
      // One decimal, which is what the column keeps.
      km !== null && distance(km, units, 1),
      minutes !== null && duration(minutes),
      // `private` or `business` by the column's own check, which a payload
      // that did not come from the column has not passed.
      oneLine(entry.purpose, NAME_LIMIT),
      driver && `driver ${driver}`,
    ),
  ]
}

const kinds: Record<
  string,
  { label: string; lines: (entry: Entry, context: MessageContext) => Part[] }
> = {
  fuel: { label: '⛽ Fill-up', lines: fuelLines },
  service: { label: '🔧 Service', lines: serviceLines },
  cost: { label: '🧾 Cost', lines: moneyLines },
  odometer: {
    label: '🛣️ Odometer reading',
    lines: (entry, { units }) => [odometer(entry, units)],
  },
  trip: { label: '🚗 Trip', lines: tripLines },
  income: { label: '💶 Income', lines: moneyLines },
}

/// The message for one new entry: what it is, whose car and who logged it;
/// then the figures; then the note, in quotes, if there was one.
///
/// A kind this does not know still gets its first line and its note, under its
/// own name — a new entry table reaches the dispatcher before anyone has
/// decided what is worth saying about it.
export function chatMessage(
  kind: string,
  entry: Entry,
  context: MessageContext,
): string {
  const vehicle = oneLine(context.vehicleName, NAME_LIMIT)
  const author = oneLine(context.author, NAME_LIMIT)
  const note = oneLine(entry.notes, NOTE_LIMIT)
  return present([
    line(kinds[kind]?.label ?? kind, vehicle, author && `by ${author}`),
    ...(kinds[kind]?.lines(entry, context) ?? []),
    note && `"${note}"`,
  ]).join('\n')
}
