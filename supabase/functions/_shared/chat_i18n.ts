import names from './names.json' with { type: 'json' }
import { humanise } from './chat_text.ts'

// The words a chat message is made of, in the languages the app speaks.
//
// A hook says which language its channel reads (`webhooks.language`), and
// the drain asks the builder for the text once per language. The words are
// written here by hand and kept short: a message is a label, a car, a name
// and a few figures. The names of services, categories and a trip's purpose
// are the app's own, taken from its ARB files through `names.json`, which
// `test/ci/chat_names_test.dart` generates and holds to the ARBs. Figures
// and dates follow the language's locale.
//
// Nothing here genders a person. Croatian and Italian would have to choose
// a form for "logged by Ana" or "Ana joined", and a display name says
// nothing about which; so the person is named after the car with no verb,
// and a verb that had to agree is replaced by a noun. What must agree with
// a noun the message does carry — "Trošak uređen", "Spesa modificata" — is
// written out per kind.

export type Language = 'en' | 'hr' | 'it'

/// The hook's `language` column, or English for anything that is not one of
/// the three: the column is checked, but a builder is a function of a string
/// and must not throw over one.
export function languageOf(value: unknown): Language {
  return value === 'hr' || value === 'it' ? value : 'en'
}

/// The entry kinds `dispatch-webhooks/events.ts` names a receiver.
export type EntryKind =
  | 'fuel'
  | 'service'
  | 'cost'
  | 'odometer'
  | 'trip'
  | 'income'

export interface KindWords {
  /// What the kind is called on the first line of a new entry: "Fill-up".
  label: string
  /// The first line of an edit and of a delete: "Fill-up edited". A
  /// participle that agrees with the noun in Croatian and Italian, so one
  /// per kind rather than one word.
  edited: string
  deleted: string
}

export interface Strings {
  /// BCP 47, for `Intl`: figures and dates.
  locale: string
  kinds: Record<EntryKind, KindWords>
  /// Who logged a new entry, after the car: "by Ana".
  by: (name: string) => string
  /// Who logged an entry that was then edited or deleted by somebody the
  /// row does not name: "logged by Ana".
  loggedBy: (name: string) => string
  /// Where the tank was filled, and where the work was done.
  atStation: (place: string) => string
  atShop: (place: string) => string
  /// A figure and the road it was measured over: "6.1 l/100km over 702 km".
  over: (figure: string, distance: string) => string
  /// Half a route: only where it started, or only where it went.
  from: (place: string) => string
  to: (place: string) => string
  driver: (name: string) => string
  carAdded: string
  carArchived: string
  carRestored: string
  handedOver: string
  lentOut: string
  /// To whom and until when, whichever of the two is known; null for neither.
  lentTo: (name: string | null, until: string | null) => string | null
  returned: string
  returnedBy: (name: string) => string
  joined: (name: string) => string
  left: (name: string) => string
  /// A member whose profile is gone.
  somebody: string
  dueToday: string
  dueIn: (days: number) => string
  test: string
  minutes: (minutes: number) => string
  hoursMinutes: (hours: number, minutes: string) => string
}

const words = (...parts: (string | null | false)[]) =>
  parts.filter((part): part is string => typeof part === 'string').join(' ') ||
  null

const en: Strings = {
  locale: 'en-GB',
  kinds: {
    fuel: {
      label: 'Fill-up',
      edited: 'Fill-up edited',
      deleted: 'Fill-up deleted',
    },
    service: {
      label: 'Service',
      edited: 'Service edited',
      deleted: 'Service deleted',
    },
    cost: { label: 'Cost', edited: 'Cost edited', deleted: 'Cost deleted' },
    odometer: {
      label: 'Odometer reading',
      edited: 'Odometer reading edited',
      deleted: 'Odometer reading deleted',
    },
    trip: { label: 'Trip', edited: 'Trip edited', deleted: 'Trip deleted' },
    income: {
      label: 'Income',
      edited: 'Income edited',
      deleted: 'Income deleted',
    },
  },
  by: (name) => `by ${name}`,
  loggedBy: (name) => `logged by ${name}`,
  atStation: (place) => `at ${place}`,
  atShop: (place) => `at ${place}`,
  over: (figure, distance) => `${figure} over ${distance}`,
  from: (place) => `from ${place}`,
  to: (place) => `to ${place}`,
  driver: (name) => `driver ${name}`,
  carAdded: 'Car added',
  carArchived: 'Car archived',
  carRestored: 'Car restored',
  handedOver: 'Handed over',
  lentOut: 'Lent out',
  lentTo: (name, until) =>
    words(name && `to ${name}`, until && `until ${until}`),
  returned: 'Returned',
  returnedBy: (name) => `from ${name}`,
  joined: (name) => `${name} joined the garage`,
  left: (name) => `${name} left the garage`,
  somebody: 'Somebody',
  dueToday: 'Due today',
  dueIn: (days) => `Due in ${days} ${days === 1 ? 'day' : 'days'}`,
  test: 'Test from Garage',
  minutes: (minutes) => `${minutes} min`,
  hoursMinutes: (hours, minutes) => `${hours} h ${minutes} min`,
}

/// Croatian counts days in two written forms here: 1 dan, otherwise dana —
/// with 21, 31… as 1 again and 11 not, the rule the app's ARB plurals
/// follow. (The few-form, 2 to 4, is spelled the same as the many-form.)
function hrDays(days: number): string {
  return days % 10 === 1 && days % 100 !== 11 ? 'dan' : 'dana'
}

// A place name is not declined: "na INA Zagreb", as the app's own Croatian
// writes it. A person is named after the car, and a verb that would have to
// agree with them is left out or replaced by a noun.
const hr: Strings = {
  locale: 'hr-HR',
  kinds: {
    fuel: {
      label: 'Točenje',
      edited: 'Točenje uređeno',
      deleted: 'Točenje obrisano',
    },
    service: {
      label: 'Servis',
      edited: 'Servis uređen',
      deleted: 'Servis obrisan',
    },
    cost: {
      label: 'Trošak',
      edited: 'Trošak uređen',
      deleted: 'Trošak obrisan',
    },
    odometer: {
      label: 'Stanje kilometraže',
      edited: 'Stanje kilometraže uređeno',
      deleted: 'Stanje kilometraže obrisano',
    },
    trip: {
      label: 'Putovanje',
      edited: 'Putovanje uređeno',
      deleted: 'Putovanje obrisano',
    },
    income: {
      label: 'Prihod',
      edited: 'Prihod uređen',
      deleted: 'Prihod obrisan',
    },
  },
  by: (name) => name,
  loggedBy: (name) => `unos: ${name}`,
  atStation: (place) => `na ${place}`,
  atShop: (place) => `u ${place}`,
  over: (figure, distance) => `${figure} na ${distance}`,
  from: (place) => `polazak ${place}`,
  to: (place) => `odredište ${place}`,
  driver: (name) => `vozi ${name}`,
  carAdded: 'Novi auto',
  carArchived: 'Auto arhiviran',
  carRestored: 'Auto vraćen iz arhive',
  handedOver: 'Predano',
  lentOut: 'Posuđeno',
  lentTo: (name, until) =>
    [name, until && `do ${until}`].filter(Boolean).join(' · ') || null,
  returned: 'Vraćeno',
  returnedBy: (name) => name,
  joined: (name) => `${name} je sada dio garaže`,
  left: (name) => `${name} više nije dio garaže`,
  somebody: 'Netko',
  dueToday: 'Dospijeva danas',
  dueIn: (days) => `Dospijeva za ${days} ${hrDays(days)}`,
  test: 'Test iz aplikacije Garage',
  minutes: (minutes) => `${minutes} min`,
  hoursMinutes: (hours, minutes) => `${hours} h ${minutes} min`,
}

/// "a" before a word that starts with one is "ad": "ad Ancona", "ad Ana".
const a = (word: string) => /^a/i.test(word) ? 'ad' : 'a'

// The car is "l'auto", feminine, as the app's own Italian has it where it
// speaks of one ("Prestata a te", "Restituita").
const it: Strings = {
  locale: 'it-IT',
  kinds: {
    fuel: {
      label: 'Rifornimento',
      edited: 'Rifornimento modificato',
      deleted: 'Rifornimento eliminato',
    },
    service: {
      label: 'Intervento',
      edited: 'Intervento modificato',
      deleted: 'Intervento eliminato',
    },
    cost: {
      label: 'Spesa',
      edited: 'Spesa modificata',
      deleted: 'Spesa eliminata',
    },
    odometer: {
      label: 'Lettura del contachilometri',
      edited: 'Lettura del contachilometri modificata',
      deleted: 'Lettura del contachilometri eliminata',
    },
    trip: {
      label: 'Viaggio',
      edited: 'Viaggio modificato',
      deleted: 'Viaggio eliminato',
    },
    income: {
      label: 'Entrata',
      edited: 'Entrata modificata',
      deleted: 'Entrata eliminata',
    },
  },
  by: (name) => name,
  loggedBy: (name) => `voce di ${name}`,
  atStation: (place) => `da ${place}`,
  atShop: (place) => `da ${place}`,
  over: (figure, distance) => `${figure} su ${distance}`,
  from: (place) => `da ${place}`,
  to: (place) => `${a(place)} ${place}`,
  driver: (name) => `alla guida: ${name}`,
  carAdded: 'Auto aggiunta',
  carArchived: 'Auto archiviata',
  carRestored: 'Auto ripristinata',
  handedOver: 'Ceduta',
  lentOut: 'Prestata',
  lentTo: (name, until) =>
    words(name && `${a(name)} ${name}`, until && `fino al ${until}`),
  returned: 'Restituita',
  returnedBy: (name) => `da ${name}`,
  joined: (name) => `${name} ora fa parte del garage`,
  left: (name) => `${name} non fa più parte del garage`,
  somebody: 'Qualcuno',
  dueToday: 'Scade oggi',
  dueIn: (days) => `Scade tra ${days} ${days === 1 ? 'giorno' : 'giorni'}`,
  test: "Test dall'app Garage",
  minutes: (minutes) => `${minutes} min`,
  hoursMinutes: (hours, minutes) => `${hours} h ${minutes} min`,
}

const tables: Record<Language, Strings> = { en, hr, it }

export function strings(language: Language): Strings {
  return tables[language]
}

/// The words for an entry kind, or undefined for a kind this does not know.
/// Looked up by own property: `constructor` is a kind no table has, and a
/// plain object would answer for it anyway.
export function kindWords(
  language: Language,
  kind: string,
): KindWords | undefined {
  const kinds = strings(language).kinds
  return Object.hasOwn(kinds, kind) ? kinds[kind as EntryKind] : undefined
}

const table = names as Record<Language, Record<string, string>>

/// The app's own name for a service type, a category or a trip's purpose,
/// in the language; a household's own key, in no list, as words.
///
/// By own property, for the same reason as [kindWords]: a category is a key
/// that passed `^[a-z0-9_]+$`, and `constructor` does.
export function nameOf(language: Language, key: string): string {
  const named = table[language]
  return Object.hasOwn(named, key) ? named[key] : humanise(key)
}
