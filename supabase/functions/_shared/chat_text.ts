// How a chat message is written, whichever function is writing it.
//
// Two functions tell a chat service something: `dispatch-webhooks` that an
// entry was logged, `push-due-reminders` that something falls due. A household
// reads both in the same channel, so they are written with the same pieces —
// the same English, the same name for a service, the same date — and neither
// may let what a person typed break the shape of a message or run it past
// what a service will accept.
//
// Deliberately plain and English. The edge functions have no access to the
// household's locale or to the app's ARB files, and a half-translated
// notification would be worse than a consistent one.

/// British English, for figures and dates alike.
export const LOCALE = 'en-GB'

/// Names — a station, a shop, a place, a driver, a car — are short or they are
/// a mistake. Bounded so the whole message is, because Discord refuses
/// anything past 2,000 characters and a refusal is a notification that never
/// arrives.
export const NAME_LIMIT = 80
/// The work done at one visit. A big service is seven or eight items; the
/// column is an array with no upper bound.
export const WORK_LIMIT = 400

/// Free text, made safe to put on one line of a message.
///
/// Nothing a person typed may break the shape: a line break inside a note
/// would turn one entry into what reads as several. Cut by character rather
/// than by UTF-16 unit, because half an emoji is a lone surrogate and some
/// receivers refuse a body that carries one.
export function oneLine(value: unknown, limit: number): string | null {
  if (typeof value !== 'string') {
    return null
  }
  const text = value.replace(/\s+/g, ' ').trim()
  if (text === '') {
    return null
  }
  const characters = [...text]
  return characters.length > limit
    ? `${characters.slice(0, limit).join('').trimEnd()}…`
    : text
}

/// Spellings a capital letter alone would get wrong.
///
/// A `Map`, not an object: a key is whatever matched `^[a-z0-9_]+$`, and
/// `constructor` does. Looked up in a plain object that finds the one every
/// object inherits, and the message reads "function Object() { [native code] }".
const SPELLINGS = new Map([
  ['ac', 'AC'],
  ['adblue', 'AdBlue'],
  ['dpf', 'DPF'],
])

/// A language-neutral key as words: `service_oil_change` is "Oil change".
///
/// Only a service type has a prefix — it says which table the key is from,
/// which the message's first line has already said. Cost and income
/// categories carry none (`CostCategories`, `IncomeCategories`), so none is
/// looked for: stripping `income_` would turn a household's
/// `income_protection` premium into "Protection". A household's own service
/// type has no entry in any list and needs none — `service_types` stores a key
/// and nothing else, so the key is all there is to show, here as in the app.
export function humanise(key: string): string {
  const text = key
    .replace(/^service_(?=.)/, '')
    .split('_')
    .filter((word) => word !== '')
    .map((word) => SPELLINGS.get(word) ?? word)
    .join(' ')
  return text.charAt(0).toUpperCase() + text.slice(1)
}

export type Part = string | null | undefined | false

export const present = (parts: Part[]) =>
  parts.filter((part): part is string =>
    typeof part === 'string' && part !== ''
  )

/// Parts of one line, with whatever is missing left out rather than left
/// blank. Null when nothing is left, so the line goes too.
export const line = (...parts: Part[]) => present(parts).join(' · ') || null

/// A `YYYY-MM-DD` day as a person writes it: "4 Nov 2026". Null for anything
/// that is not such a day, so it is left off the line rather than guessed at.
export function calendarDay(day: unknown): string | null {
  if (typeof day !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(day)) {
    return null
  }
  const date = new Date(day)
  // JavaScript reads 31 February as 3 March rather than refusing it, so the
  // day has to come back out as it went in.
  if (
    Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== day
  ) {
    return null
  }
  return new Intl.DateTimeFormat(LOCALE, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    // The day was read as midnight in UTC. In any zone west of that it is
    // still the evening before.
    timeZone: 'UTC',
  }).format(date)
}
