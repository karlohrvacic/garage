import { assertEquals } from 'jsr:@std/assert@1'
import {
  kindWords,
  languageOf,
  nameOf,
  type Strings,
  strings,
} from './chat_i18n.ts'

Deno.test('an unknown language is English', () => {
  assertEquals(languageOf('en'), 'en')
  assertEquals(languageOf('hr'), 'hr')
  assertEquals(languageOf('it'), 'it')
  assertEquals(languageOf('de'), 'en')
  assertEquals(languageOf(null), 'en')
  assertEquals(languageOf(undefined), 'en')
})

/// Every leaf of one table, by its path: `kinds.fuel.label`, `dueIn`.
function leaves(
  value: unknown,
  path = '',
): Map<string, 'string' | 'function'> {
  const found = new Map<string, 'string' | 'function'>()
  if (typeof value === 'string') {
    found.set(path, 'string')
    return found
  }
  if (typeof value === 'function') {
    found.set(path, 'function')
    return found
  }
  for (const [key, inner] of Object.entries(value as object)) {
    for (const [leaf, type] of leaves(inner, path ? `${path}.${key}` : key)) {
      found.set(leaf, type)
    }
  }
  return found
}

Deno.test('every string English has, Croatian and Italian have', () => {
  const en = leaves(strings('en'))
  assertEquals(en.size > 30, true, 'the table is being read')
  for (const language of ['hr', 'it'] as const) {
    const other = leaves(strings(language))
    assertEquals([...other.keys()].sort(), [...en.keys()].sort(), language)
    for (const [leaf, type] of en) {
      assertEquals(other.get(leaf), type, `${language}.${leaf}`)
    }
  }
})

function pluck(table: Strings, path: string): unknown {
  return path.split('.').reduce<unknown>(
    (value, key) => (value as Record<string, unknown>)[key],
    table,
  )
}

/// What a leaf says, a function given a name and a place to say it with.
function spoken(table: Strings, leaf: string): string {
  const value = pluck(table, leaf)
  return typeof value === 'function'
    ? String(value('Ana', 'INA'))
    : String(value)
}

Deno.test('no string is empty, and none is left in English by mistake', () => {
  // A unit is the same word everywhere. Nothing else may be.
  const sameEverywhere = new Set(['minutes', 'hoursMinutes'])
  const english = new Map(
    [...leaves(strings('en')).keys()].map((leaf) => [
      leaf,
      spoken(strings('en'), leaf),
    ]),
  )
  for (const language of ['hr', 'it'] as const) {
    for (const leaf of leaves(strings(language)).keys()) {
      const text = spoken(strings(language), leaf)
      assertEquals(text.trim() !== '', true, `${language}.${leaf} is empty`)
      if (!sameEverywhere.has(leaf)) {
        assertEquals(
          text !== english.get(leaf),
          true,
          `${language}.${leaf} is English: "${text}"`,
        )
      }
    }
  }
})

Deno.test('a service, a category or a purpose is named in the language', () => {
  // What `names.json` says, which is what the ARB files say.
  assertEquals(nameOf('en', 'service_oil_change'), 'Oil change')
  assertEquals(nameOf('hr', 'service_oil_change'), 'Zamjena ulja')
  assertEquals(nameOf('it', 'service_oil_change'), "Cambio dell'olio")
  assertEquals(nameOf('it', 'parking'), 'Parcheggio')
  assertEquals(nameOf('hr', 'vehicle_sale'), 'Prodaja vozila')
  assertEquals(nameOf('en', 'business'), 'Business')
  assertEquals(nameOf('hr', 'business'), 'Poslovno')
  assertEquals(nameOf('it', 'private'), 'Privato')
})

Deno.test("a household's own key falls back to words", () => {
  // In no list, in no language: the key is all there is to show, as in the
  // app. The words are English, because the key was written in English.
  assertEquals(nameOf('hr', 'service_roof_rack'), 'Roof rack')
  assertEquals(nameOf('it', 'service_dpf_clean'), 'DPF clean')
  assertEquals(nameOf('en', 'income_protection'), 'Income protection')
})

// `constructor` passes the column's own check, `^[a-z0-9_]+$`, and a plain
// object has one whether or not the file does.
Deno.test('a key that names something every object has is still just a word', () => {
  assertEquals(nameOf('hr', 'constructor'), 'Constructor')
  assertEquals(nameOf('en', 'toString'), 'ToString')
})

Deno.test('the due line counts days in the language', () => {
  assertEquals(strings('en').dueIn(1), 'Due in 1 day')
  assertEquals(strings('en').dueIn(7), 'Due in 7 days')
  assertEquals(strings('en').dueToday, 'Due today')
  // Croatian: 1 dan, 2 to 4 dana, 5 and up dana; 21 is 1 again and 11 is not,
  // the same rule as the app's plurals.
  assertEquals(strings('hr').dueIn(1), 'Dospijeva za 1 dan')
  assertEquals(strings('hr').dueIn(3), 'Dospijeva za 3 dana')
  assertEquals(strings('hr').dueIn(7), 'Dospijeva za 7 dana')
  assertEquals(strings('hr').dueIn(11), 'Dospijeva za 11 dana')
  assertEquals(strings('hr').dueIn(21), 'Dospijeva za 21 dan')
  assertEquals(strings('hr').dueIn(30), 'Dospijeva za 30 dana')
  assertEquals(strings('hr').dueToday, 'Dospijeva danas')
  assertEquals(strings('it').dueIn(1), 'Scade tra 1 giorno')
  assertEquals(strings('it').dueIn(7), 'Scade tra 7 giorni')
  assertEquals(strings('it').dueToday, 'Scade oggi')
})

// Croatian and Italian agree a participle with the noun: a fill-up is edited
// one way and a cost another. English has one word, so one table per kind
// keeps the three in step.
Deno.test('an edit and a delete are named after the kind, in its gender', () => {
  assertEquals(kindWords('en', 'fuel'), {
    label: 'Fill-up',
    edited: 'Fill-up edited',
    deleted: 'Fill-up deleted',
  })
  assertEquals(kindWords('hr', 'fuel'), {
    label: 'Točenje',
    edited: 'Točenje uređeno',
    deleted: 'Točenje obrisano',
  })
  assertEquals(kindWords('hr', 'cost')?.edited, 'Trošak uređen')
  assertEquals(kindWords('it', 'cost')?.edited, 'Spesa modificata')
  assertEquals(kindWords('it', 'trip')?.deleted, 'Viaggio eliminato')
  assertEquals(kindWords('en', 'mystery'), undefined)
  assertEquals(kindWords('en', 'constructor'), undefined)
})

Deno.test('who did what is said without a gender', () => {
  const hr = strings('hr')
  const it = strings('it')
  // The person after the car, no verb: a Croatian verb would have to choose.
  assertEquals(hr.by('Ana'), 'Ana')
  assertEquals(it.by('Ana'), 'Ana')
  assertEquals(strings('en').by('Ana'), 'by Ana')
  assertEquals(hr.loggedBy('Ana'), 'unos: Ana')
  assertEquals(it.loggedBy('Ana'), 'voce di Ana')
  assertEquals(hr.joined('Ana'), 'Ana je sada dio garaže')
  assertEquals(hr.left('Ana'), 'Ana više nije dio garaže')
  assertEquals(it.joined('Ana'), 'Ana ora fa parte del garage')
  assertEquals(it.left('Ana'), 'Ana non fa più parte del garage')
  assertEquals(hr.driver('Marko'), 'vozi Marko')
  assertEquals(it.driver('Marko'), 'alla guida: Marko')
})

Deno.test('Italian says "ad" before a word that starts with a', () => {
  const it = strings('it')
  assertEquals(it.to('Ancona'), 'ad Ancona')
  assertEquals(it.to('ancona'), 'ad ancona')
  assertEquals(it.to('Split'), 'a Split')
  assertEquals(it.lentTo('Ana', null), 'ad Ana')
  assertEquals(it.lentTo('Marco', null), 'a Marco')
})

Deno.test('a loan says to whom and until when, in whichever of the two is known', () => {
  const en = strings('en')
  assertEquals(en.lentTo('Ana', '1 Oct 2026'), 'to Ana until 1 Oct 2026')
  assertEquals(en.lentTo(null, '1 Oct 2026'), 'until 1 Oct 2026')
  assertEquals(en.lentTo('Ana', null), 'to Ana')
  assertEquals(en.lentTo(null, null), null)
  const hr = strings('hr')
  assertEquals(hr.lentTo('Ana', '1. lis 2026.'), 'Ana · do 1. lis 2026.')
  assertEquals(hr.lentTo(null, '1. lis 2026.'), 'do 1. lis 2026.')
  assertEquals(hr.returnedBy('Ana'), 'Ana')
  const it = strings('it')
  assertEquals(it.lentTo('Ana', '1 ott 2026'), 'ad Ana fino al 1 ott 2026')
  assertEquals(it.lentTo('Marco', null), 'a Marco')
  assertEquals(it.returnedBy('Ana'), 'da Ana')
})

Deno.test("the locale is the language's own", () => {
  assertEquals(strings('en').locale, 'en-GB')
  assertEquals(strings('hr').locale, 'hr-HR')
  assertEquals(strings('it').locale, 'it-IT')
})
