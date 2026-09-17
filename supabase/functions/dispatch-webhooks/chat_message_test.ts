import { assertEquals } from 'jsr:@std/assert@1'
import {
  chatMessage,
  economyText,
  type MessageContext,
  type Units,
  unitsFrom,
} from './chat_message.ts'
import fixture from '../../../test/fixtures/economy_spans.json' with {
  type: 'json',
}

const euros: Units = { currency: 'EUR', distance: 'km', volume: 'liter' }

const clio = (context: Partial<MessageContext> = {}): MessageContext => ({
  vehicleName: 'Clio',
  author: 'Ana',
  units: euros,
  electric: false,
  economy: null,
  ...context,
})

/// 42.8 l over 702 km: the tank `economy_spans.json` works to the last digit.
const tank = {
  litresPer100Km: 42.8 / 702 * 100,
  distanceKm: 702,
  volumeL: 42.8,
}

const fillUp = {
  volume_l: 42.8,
  station: 'INA Zagreb',
  total: 60.21,
  price_per_l: 1.4068,
  odometer_km: 49680,
  notes: 'Motorway all the way',
}

Deno.test('a fill-up reads as a few lines, not a row', () => {
  assertEquals(
    chatMessage('fuel', fillUp, clio({ economy: tank })),
    [
      '⛽ Fill-up · Clio · by Ana',
      '42.8 l at INA Zagreb · €60.21 (€1.407/l)',
      '6.1 l/100km over 702 km · 49,680 km',
      '"Motorway all the way"',
    ].join('\n'),
  )
})

Deno.test('a fill-up that closes no span says nothing about consumption', () => {
  assertEquals(
    chatMessage('fuel', fillUp, clio()).split('\n')[2],
    '49,680 km',
  )
})

Deno.test('what is missing is left out rather than left blank', () => {
  assertEquals(chatMessage('fuel', {}, clio()), '⛽ Fill-up · Clio · by Ana')
  assertEquals(
    chatMessage('fuel', { volume_l: 40 }, clio({ author: null })),
    '⛽ Fill-up · Clio\n40 l',
  )
  assertEquals(
    chatMessage('cost', {}, clio({ vehicleName: null, author: null })),
    '🧾 Cost',
  )
})

Deno.test('a price with no total still reads as a price', () => {
  assertEquals(
    chatMessage('fuel', { volume_l: 40, price_per_l: 1.5 }, clio())
      .split('\n')[1],
    '40 l · €1.500/l',
  )
})

Deno.test('a cost names its category, the money and the reading', () => {
  assertEquals(
    chatMessage('cost', {
      category: 'insurance',
      amount: 312,
      odometer_km: 49680,
      notes: 'Renewed for a year',
    }, clio()),
    [
      '🧾 Cost · Clio · by Ana',
      'Insurance · €312.00 · 49,680 km',
      '"Renewed for a year"',
    ].join('\n'),
  )
})

Deno.test('a service lists the work, the shop and the bill', () => {
  assertEquals(
    chatMessage('service', {
      service_type_keys: ['service_oil_change', 'service_air_filter'],
      shop: 'Auto Servis Horvat',
      cost: 128.4,
      odometer_km: 58900,
      notes: 'Next one at 73,900',
    }, clio()),
    [
      '🔧 Service · Clio · by Ana',
      'Oil change, Air filter · at Auto Servis Horvat · €128.40 · 58,900 km',
      '"Next one at 73,900"',
    ].join('\n'),
  )
})

Deno.test('a trip says where, how far, how long, why and who', () => {
  assertEquals(
    chatMessage('trip', {
      from_place: 'Zagreb',
      to_place: 'Split',
      distance_km: 410,
      minutes: 245,
      purpose: 'business',
      driver: 'Marko',
    }, clio()),
    [
      '🚗 Trip · Clio · by Ana',
      'Zagreb → Split · 410 km · 4 h 05 min · business · driver Marko',
    ].join('\n'),
  )
})

Deno.test('a trip with a title leads with it, and half a route still reads', () => {
  const second = (entry: Record<string, unknown>) =>
    chatMessage('trip', entry, clio()).split('\n')[1]

  assertEquals(
    second({ title: 'Client visit', from_place: 'Zagreb', to_place: 'Split' }),
    'Client visit · Zagreb → Split',
  )
  assertEquals(second({ from_place: 'Zagreb' }), 'from Zagreb')
  assertEquals(second({ to_place: 'Split' }), 'to Split')
  assertEquals(second({ distance_km: 12.5, minutes: 45 }), '12.5 km · 45 min')
  // The app's own "1 h 05 min" shape, on the hour as well.
  assertEquals(second({ minutes: 120 }), '2 h 00 min')
})

Deno.test('income names its kind and the money', () => {
  assertEquals(
    chatMessage('income', {
      category: 'vehicle_sale',
      amount: 4500,
      odometer_km: 182300,
      notes: 'Sold to a neighbour',
    }, clio()),
    [
      '💶 Income · Clio · by Ana',
      'Vehicle sale · €4,500.00 · 182,300 km',
      '"Sold to a neighbour"',
    ].join('\n'),
  )
  assertEquals(
    chatMessage('income', { category: 'ride', amount: 15 }, clio())
      .split('\n')[1],
    'Ride · €15.00',
  )
})

Deno.test('an odometer reading is the reading', () => {
  assertEquals(
    chatMessage(
      'odometer',
      { odometer_km: 49680, notes: 'Before the trip' },
      clio(),
    ),
    [
      '🛣️ Odometer reading · Clio · by Ana',
      '49,680 km',
      '"Before the trip"',
    ].join('\n'),
  )
})

Deno.test('an unknown kind falls back to its own name', () => {
  assertEquals(
    chatMessage('mystery', { notes: 'hm' }, clio({ author: null })),
    'mystery · Clio\n"hm"',
  )
})

// How keys become words is `_shared/chat_text_test.ts`. This is the same
// trap reached through a message: `constructor` passes the column's own check,
// `^[a-z0-9_]+$`, and looked up in a plain object it finds Object's
// constructor.
Deno.test('a category that names something every object has is still just a word', () => {
  assertEquals(
    chatMessage('cost', { category: 'constructor', amount: 5 }, clio())
      .split('\n')[1],
    'Constructor · €5.00',
  )
})

Deno.test('a household on miles and US gallons reads in both', () => {
  const lines = chatMessage(
    'fuel',
    fillUp,
    clio({
      units: { currency: 'USD', distance: 'mi', volume: 'us_gallon' },
      economy: tank,
    }),
  ).split('\n')

  // 42.8 / 3.785411784 = 11.31 gal, and the price goes the other way:
  // 1.4068 * 3.785411784 = 5.325 a gallon.
  assertEquals(lines[1], '11.31 gal at INA Zagreb · US$60.21 (US$5.325/gal)')
  // 235.214583 / 6.0969 = 38.6 mpg; 702 / 1.609344 = 436 mi;
  // 49680 / 1.609344 = 30,870 mi.
  assertEquals(lines[2], '38.6 mpg over 436 mi · 30,870 mi')
})

Deno.test('and one on UK gallons gets the larger gallon', () => {
  const lines = chatMessage(
    'fuel',
    fillUp,
    clio({
      units: { currency: 'GBP', distance: 'mi', volume: 'uk_gallon' },
      economy: tank,
    }),
  ).split('\n')

  // 42.8 / 4.54609 = 9.41 gal; 1.4068 * 4.54609 = 6.395 a gallon;
  // 282.480936 / 6.0969 = 46.3 mpg.
  assertEquals(lines[1], '9.41 gal at INA Zagreb · £60.21 (£6.395/gal)')
  assertEquals(lines[2], '46.3 mpg over 436 mi · 30,870 mi')
})

Deno.test('a trip is measured in the household distance too', () => {
  assertEquals(
    chatMessage(
      'trip',
      { distance_km: 410 },
      clio({ units: { ...euros, distance: 'mi' } }),
    ).split('\n')[1],
    // 410 / 1.609344 = 254.76
    '254.8 mi',
  )
})

Deno.test('an electric car charges in kilowatt-hours, whatever the household pours', () => {
  const charge = {
    volume_l: 54,
    station: 'Ionity Zagreb',
    total: 21.06,
    price_per_l: 0.39,
    odometer_km: 12300,
  }
  const span = { litresPer100Km: 18, distanceKm: 300, volumeL: 54 }

  assertEquals(
    chatMessage('fuel', charge, clio({ electric: true, economy: span })),
    [
      '⛽ Fill-up · Clio · by Ana',
      '54 kWh at Ionity Zagreb · €21.06 (€0.390/kWh)',
      '18.0 kWh/100km over 300 km · 12,300 km',
    ].join('\n'),
  )

  // Gallons do not apply to a battery, and the figure is never turned into
  // mpg: it stays "per 100", over miles. 18 * 1.609344 = 28.97.
  const imperial = chatMessage(
    'fuel',
    charge,
    clio({
      electric: true,
      economy: span,
      units: { currency: 'GBP', distance: 'mi', volume: 'uk_gallon' },
    }),
  ).split('\n')
  assertEquals(imperial[1], '54 kWh at Ionity Zagreb · £21.06 (£0.390/kWh)')
  assertEquals(imperial[2], '29.0 kWh/100mi over 186 mi · 7,643 mi')
})

// The constants behind those lines are a second copy of the ones in
// `lib/core/format/unit_format.dart`. The fixture's `readings` are what both
// copies are held to; `economy_fixture_test.dart` runs the same cases through
// the app's formatter.
for (const reading of fixture.readings.cases) {
  Deno.test(`fixture: ${reading.name}`, () => {
    assertEquals(
      economyText(
        reading.l_per_100km,
        unitsFrom({
          distance_unit: reading.distance_unit,
          volume_unit: reading.volume_unit,
        }),
        reading.electric,
      ),
      reading.expected,
    )
  })
}

// At a decimal half the two platforms' formatters part ways, and the app is
// the one a household has in its hand. These are the app's own output,
// recorded; `economy_fixture_test.dart` asserts the same list against it.
for (const reading of fixture.readings.halves) {
  Deno.test(`fixture, as the app rounds: ${reading.name}`, () => {
    assertEquals(
      economyText(
        reading.l_per_100km,
        unitsFrom({
          distance_unit: reading.distance_unit,
          volume_unit: reading.volume_unit,
        }),
        reading.electric,
      ),
      reading.expected,
    )
  })
}

Deno.test('money and volume round the way the app rounds them', () => {
  const second = (entry: Record<string, unknown>, electric = false) =>
    chatMessage('fuel', entry, clio({ electric })).split('\n')[1]

  // What `UnitFormat.formatMoney(x, decimals: 3)` prints for each, run to
  // find out: 1.0005 is "€1.000" where JavaScript's Intl says 1.001, and
  // 0.3505 is "€0.351" where `toFixed` says 0.350.
  assertEquals(second({ price_per_l: 1.0005 }), '€1.000/l')
  assertEquals(second({ price_per_l: 0.3505 }, true), '€0.351/kWh')
  // And `formatVolume(42.805)` is "42.80 l", where Intl alone says 42.81.
  assertEquals(second({ volume_l: 42.805 }), '42.8 l')
})

Deno.test('a figure of nothing is not a figure', () => {
  assertEquals(economyText(0, euros, false), null)
})

Deno.test('a note is trimmed, kept on one line, and cut at 200 characters', () => {
  const last = (notes: string) =>
    chatMessage('odometer', { notes }, clio()).split('\n').at(-1)

  assertEquals(last('  Tyres\nlook\r\n\tworn  '), '"Tyres look worn"')
  assertEquals(last('a'.repeat(200)), `"${'a'.repeat(200)}"`)
  assertEquals(last('a'.repeat(201)), `"${'a'.repeat(200)}…"`)
  // Cut between characters, never through one: half an emoji is a lone
  // surrogate, and some receivers refuse a body that carries one.
  assertEquals(last('a'.repeat(199) + '🚗🚗'), `"${'a'.repeat(199)}🚗…"`)
})

Deno.test('a note of nothing but spaces is no note', () => {
  assertEquals(
    chatMessage('odometer', { odometer_km: 5, notes: ' \n ' }, clio()),
    '🛣️ Odometer reading · Clio · by Ana\n5 km',
  )
})

Deno.test('no free text can break a line, wherever it was typed', () => {
  assertEquals(
    chatMessage(
      'service',
      { service_type_keys: ['service_battery'], shop: 'Auto\nServis' },
      clio({ vehicleName: 'Cl\nio', author: ' Ana\t' }),
    ),
    '🔧 Service · Cl io · by Ana\nBattery · at Auto Servis',
  )
})

Deno.test('no entry can write a message too long to deliver', () => {
  // Discord refuses content past 2,000 characters, and a refusal is a
  // notification that never arrives. Every free-text column is unbounded in
  // the schema, and so is the list of work done at a visit.
  const long = 'x'.repeat(5000)
  const entries: [string, Record<string, unknown>][] = [
    ['fuel', { ...fillUp, station: long, notes: long }],
    ['service', {
      service_type_keys: Array.from({ length: 300 }, (_, i) => `service_x${i}`),
      shop: long,
      notes: long,
    }],
    ['trip', {
      title: long,
      from_place: long,
      to_place: long,
      driver: long,
      purpose: long,
      notes: long,
    }],
    // A category is a key, and a key is as long as whoever wrote it liked.
    ['cost', { category: long, amount: 5, odometer_km: 5, notes: long }],
    ['income', { category: long, amount: 5, odometer_km: 5, notes: long }],
    ['odometer', { odometer_km: 5, notes: long }],
  ]

  for (const [kind, entry] of entries) {
    const message = chatMessage(
      kind,
      entry,
      clio({ vehicleName: long, author: long, economy: tank }),
    )
    assertEquals(message.length < 2000, true, `${kind}: ${message.length}`)
  }
})

Deno.test('money without a currency is still a number', () => {
  const second = (currency: string | null) =>
    chatMessage(
      'cost',
      { amount: 1312.5 },
      clio({ units: { ...euros, currency } }),
    )
      .split('\n')[1]

  assertEquals(second(null), '1,312.50')
  // Well-formed but unknown to anyone: the code stands in for the symbol.
  assertEquals(second('XYZ'), 'XYZ 1,312.50')
  // The column only promises three characters, and `Intl` throws on three
  // that are not letters. A household must not lose its notifications to that.
  assertEquals(second('E1!'), '1,312.50 E1!')
})

Deno.test('units come from the household row, and default to metric', () => {
  assertEquals(
    unitsFrom({
      currency_code: 'GBP',
      distance_unit: 'mi',
      volume_unit: 'uk_gallon',
    }),
    { currency: 'GBP', distance: 'mi', volume: 'uk_gallon' },
  )
  // The app's own fallbacks: anything that is not `mi` is kilometres, and
  // anything that is not a gallon is litres.
  assertEquals(unitsFrom(null), {
    currency: null,
    distance: 'km',
    volume: 'liter',
  })
  assertEquals(unitsFrom({ distance_unit: 'furlong', volume_unit: 'pint' }), {
    currency: null,
    distance: 'km',
    volume: 'liter',
  })
})
