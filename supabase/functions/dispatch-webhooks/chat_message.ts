import {
  kindWords,
  type Language,
  nameOf,
  strings,
} from '../_shared/chat_i18n.ts'
import {
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
// In the hook's language, which is the channel's rather than any member's:
// the words from `_shared/chat_i18n.ts`, the name of a service or a category
// from the app's own ARB files through `names.json`, and the figures and the
// date in the language's locale — a Croatian channel reads "49.680 km".
//
// Units are the household's. Storage is canonical — kilometres, litres, the
// household's currency — and the conversion happens here, at the edge, with
// the constants and the rounding of `lib/core/format/unit_format.dart`. The
// figures are the app's; the wording is a chat line's, not a screen's. The
// app prints a volume to two fixed decimals, this prints "42.8 l". And one
// rule differs on purpose: the app reads a fill-up in kilowatt-hours when the
// *car's* main fuel is electricity, this when the *fill's* is — see
// `electric` below.

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
  /// The hook's, not the author's: one channel reads one language.
  language: Language
}

/// How a figure is written: in whose units, and in which language.
interface Figures {
  units: Units
  locale: string
}

const figuresOf = ({ units, language }: MessageContext): Figures => ({
  units,
  locale: strings(language).locale,
})

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

function decimal(
  value: number,
  most: number,
  least: number,
  locale: string,
): string {
  return new Intl.NumberFormat(locale, {
    minimumFractionDigits: least,
    maximumFractionDigits: most,
    // As the app groups: Italian's CLDR data leaves a four-digit number
    // ungrouped ("4500,00 €"), and the app's own formatter does not.
    useGrouping: 'always',
  }).format(rounded(value, most))
}

/// [decimals] overrides the currency's usual precision: a price per litre is
/// quoted to a tenth of a cent on every forecourt, and two decimals would
/// round the part of it that differs.
function money(
  amount: number,
  { units: { currency }, locale }: Figures,
  decimals?: number,
): string {
  const precision = decimals === undefined ? {} : {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }
  if (currency !== null) {
    try {
      const format = new Intl.NumberFormat(locale, {
        style: 'currency',
        currency,
        useGrouping: 'always',
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
      return `${
        decimal(amount, decimals ?? 2, decimals ?? 2, locale)
      } ${currency}`
    }
  }
  return decimal(amount, decimals ?? 2, decimals ?? 2, locale)
}

function distance(km: number, { units, locale }: Figures, most: number) {
  const value = units.distance === 'mi' ? km / KM_PER_MILE : km
  return `${decimal(value, most, 0, locale)} ${units.distance}`
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

function quantity(stored: number, figures: Figures, electric: boolean) {
  const { units, locale } = figures
  const value = electric ? stored : stored / litresPerUnit(units)
  return `${decimal(value, 2, 0, locale)} ${quantityUnit(units, electric)}`
}

/// A price per litre, as a price per whatever the household buys. The price
/// converts the opposite way to the volume — a gallon is more litres, so it
/// costs more — and doing one without the other is out by nearly four times.
function pricePerUnit(perLitre: number, figures: Figures, electric: boolean) {
  const { units } = figures
  const value = electric ? perLitre : perLitre * litresPerUnit(units)
  return `${money(value, figures, 3)}/${quantityUnit(units, electric)}`
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
  locale = LOCALE,
): string | null {
  if (!(perHundredKm > 0)) {
    return null
  }
  const figure = (value: number) => decimal(value, 1, 1, locale)
  if (electric) {
    return units.distance === 'km'
      ? `${figure(perHundredKm)} kWh/100km`
      : `${figure(perHundredKm * KM_PER_MILE)} kWh/100mi`
  }
  if (units.distance === 'km' && units.volume === 'liter') {
    return `${figure(perHundredKm)} l/100km`
  }
  const constant = units.volume === 'uk_gallon' ? MPG_UK : MPG_US
  return `${figure(constant / perHundredKm)} mpg`
}

type Entry = Record<string, unknown>

const words = (...parts: Part[]) => present(parts).join(' ') || null

function odometer(entry: Entry, figures: Figures): string | null {
  const km = numberFrom(entry.odometer_km)
  return km === null ? null : distance(km, figures, 0)
}

function amount(value: unknown, figures: Figures): string | null {
  const parsed = numberFrom(value)
  return parsed === null ? null : money(parsed, figures)
}

/// "6.1 l/100km over 702 km": the figure, and how much road it was measured
/// over, because a figure from 80 km of town is not one from 700 of motorway.
function consumption(context: MessageContext) {
  const { economy, units, electric, language } = context
  if (economy === null) {
    return null
  }
  const figures = figuresOf(context)
  const figure = economyText(
    economy.litresPer100Km,
    units,
    electric,
    figures.locale,
  )
  return figure &&
    strings(language).over(figure, distance(economy.distanceKm, figures, 0))
}

function fuelLines(entry: Entry, context: MessageContext): Part[] {
  const { electric, language } = context
  const text = strings(language)
  const figures = figuresOf(context)
  const stored = numberFrom(entry.volume_l)
  const station = oneLine(entry.station, NAME_LIMIT)
  const perLitre = numberFrom(entry.price_per_l)

  const price = perLitre === null
    ? null
    : pricePerUnit(perLitre, figures, electric)
  const total = amount(entry.total, figures)

  return [
    line(
      words(
        stored !== null && quantity(stored, figures, electric),
        station && text.atStation(station),
      ),
      total && price ? `${total} (${price})` : total ?? price,
    ),
    line(consumption(context), odometer(entry, figures)),
  ]
}

function serviceLines(entry: Entry, context: MessageContext): Part[] {
  const { language } = context
  const figures = figuresOf(context)
  const keys = Array.isArray(entry.service_type_keys)
    ? entry.service_type_keys
    : []
  const shop = oneLine(entry.shop, NAME_LIMIT)
  const work = keys
    .filter((key): key is string => typeof key === 'string')
    .map((key) => nameOf(language, key))
    .join(', ')
  return [
    line(
      oneLine(work, WORK_LIMIT),
      shop && strings(language).atShop(shop),
      amount(entry.cost, figures),
      odometer(entry, figures),
    ),
  ]
}

/// A cost and an income are the same three facts with the sign reversed.
function moneyLines(entry: Entry, context: MessageContext): Part[] {
  const figures = figuresOf(context)
  return [
    line(
      // A key, and a key is as long as whoever wrote it liked.
      typeof entry.category === 'string' &&
        oneLine(nameOf(context.language, entry.category), NAME_LIMIT),
      amount(entry.amount, figures),
      odometer(entry, figures),
    ),
  ]
}

/// The app's own "1 h 05 min": an hour and five minutes read as "65 min" is
/// arithmetic the reader has to do.
function duration(minutes: number, language: Language): string {
  const whole = Math.round(minutes)
  const hours = Math.floor(whole / 60)
  const rest = whole % 60
  const text = strings(language)
  return hours === 0
    ? text.minutes(rest)
    : text.hoursMinutes(hours, String(rest).padStart(2, '0'))
}

function tripLines(entry: Entry, context: MessageContext): Part[] {
  const { language } = context
  const text = strings(language)
  const figures = figuresOf(context)
  const from = oneLine(entry.from_place, NAME_LIMIT)
  const to = oneLine(entry.to_place, NAME_LIMIT)
  const km = numberFrom(entry.distance_km)
  const minutes = numberFrom(entry.minutes)
  const driver = oneLine(entry.driver, NAME_LIMIT)
  return [
    line(
      oneLine(entry.title, NAME_LIMIT),
      from && to
        ? `${from} → ${to}`
        : from
        ? text.from(from)
        : to && text.to(to),
      // One decimal, which is what the column keeps.
      km !== null && distance(km, figures, 1),
      minutes !== null && duration(minutes, language),
      // `private` or `business` by the column's own check, named as the app
      // names them; a payload that did not come from the column is shown as
      // words, cut like any other key.
      typeof entry.purpose === 'string' &&
        oneLine(nameOf(language, entry.purpose), NAME_LIMIT),
      driver && text.driver(driver),
    ),
  ]
}

interface Kind {
  icon: string
  lines: (entry: Entry, context: MessageContext) => Part[]
}

/// The icon and the figures of each kind. Its name is in `chat_i18n.ts`, by
/// language, under the same key.
const kinds: Record<string, Kind> = {
  fuel: { icon: '⛽', lines: fuelLines },
  service: { icon: '🔧', lines: serviceLines },
  cost: { icon: '🧾', lines: moneyLines },
  odometer: {
    icon: '🛣️',
    lines: (entry, context) => [odometer(entry, figuresOf(context))],
  },
  trip: { icon: '🚗', lines: tripLines },
  income: { icon: '💶', lines: moneyLines },
}

/// What a kind is called in the language, without its icon, or undefined for
/// a kind this does not know. An edit or a delete (`events.ts`) is named
/// after the kind the same way a new entry is, from the same table, so a
/// reword cannot drift.
export function kindLabel(
  kind: string,
  language: Language = 'en',
): string | undefined {
  return kindWords(language, kind)?.label
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
  const { language } = context
  // By own property: `constructor` is a kind no table has, and a plain
  // object would answer for it with a function that has no lines.
  const known = Object.hasOwn(kinds, kind) ? kinds[kind] : undefined
  const label = kindLabel(kind, language)
  const vehicle = oneLine(context.vehicleName, NAME_LIMIT)
  const author = oneLine(context.author, NAME_LIMIT)
  const note = oneLine(entry.notes, NOTE_LIMIT)
  return present([
    line(
      known && label ? `${known.icon} ${label}` : kind,
      vehicle,
      author && strings(language).by(author),
    ),
    ...(known?.lines(entry, context) ?? []),
    note && `"${note}"`,
  ]).join('\n')
}
