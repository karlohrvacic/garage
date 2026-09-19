import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from 'jsr:@std/assert@1'
import { fakeClient, type RecordedQuery } from '../_test/fake_supabase.ts'
import type { OutboxRow } from '../_shared/outbox.ts'
import {
  reminderBody,
  type ReminderDue,
  reminderMessage,
} from '../_shared/reminder_event.ts'
import { kindLabel } from './chat_message.ts'
import { builders, entryKinds } from './events.ts'

// One builder per event: what each turns an outbox row into, the generic body
// a receiver is signed and the lines a chat service shows. How rows are read,
// queued, posted and retried is the drain's business (`outbox_test.ts`).

const AT = '2026-09-19T10:00:00.000Z'

type Row = Record<string, unknown>
type Tables = NonNullable<
  NonNullable<Parameters<typeof fakeClient>[0]>['tables']
>

const row = (event: string, payload: Row): OutboxRow => ({
  id: 'o1',
  household_id: 'h1',
  event,
  payload,
  created_at: AT,
})

/// An entry trigger's payload (migration 0079, `dispatch_entry_webhook`).
const entry = (
  table: string,
  op: 'INSERT' | 'UPDATE' | 'DELETE',
  record: Row,
  old_record: Row | null = null,
): Row => ({ table, op, vehicle_id: record.vehicle_id, record, old_record })

// A garage as the builders find it in production: a car with a name, a
// household with units and a currency, a member with a profile, and a log.
const clio = {
  id: 'v1',
  household_id: 'h1',
  nickname: 'Clio',
  fuel_type_key: 'fuel_petrol',
  secondary_fuel_type_key: null,
}

/// The tank before `fillUp`, 702 km earlier.
const earlierTank = {
  id: 'f1',
  entry_date: '2026-02-01',
  odometer_km: 48978,
  volume_l: 45,
  full_tank: true,
  missed_fill: false,
  fuel_type_key: null,
}

const garage = (tables: Tables = {}) =>
  fakeClient({
    tables: {
      vehicles: [clio],
      households: [
        {
          id: 'h1',
          currency_code: 'EUR',
          distance_unit: 'km',
          volume_unit: 'liter',
        },
      ],
      profiles: [{ user_id: 'u1', display_name: 'Ana' }],
      fuel_entries: [earlierTank],
      ...tables,
    },
  })

/// A `fuel_entries` row as `to_jsonb(new)` writes it.
const fillUp = {
  id: 'f2',
  vehicle_id: 'v1',
  entry_date: '2026-02-14',
  odometer_km: 49680,
  volume_l: 42.8,
  price_per_l: 1.4068,
  total: 60.21,
  full_tank: true,
  missed_fill: false,
  fuel_type_key: null,
  station: 'INA Zagreb',
  notes: 'Motorway all the way',
  created_by: 'u1',
}

const insurance = {
  id: 'c1',
  vehicle_id: 'v1',
  entry_date: '2026-02-14',
  category: 'insurance',
  amount: 312,
  odometer_km: 49680,
  notes: 'Renewed for a year',
  created_by: 'u1',
}

const isHistory = (query: RecordedQuery) => query.table === 'fuel_entries'

const build = async (
  admin: ReturnType<typeof fakeClient>,
  event: string,
  payload: Row,
  language = 'en',
) => {
  const built = await builders[event](admin, row(event, payload))
  if (!built) {
    throw new Error(`${event} built nothing`)
  }
  return { body: JSON.parse(built.body), message: built.message(language) }
}

Deno.test('every event the triggers write has a builder', () => {
  assertEquals(Object.keys(builders).sort(), [
    'entry.created',
    'entry.deleted',
    'entry.updated',
    'member.joined',
    'member.left',
    'reminder.due',
    'test.ping',
    'vehicle.added',
    'vehicle.archived',
    'vehicle.handed_over',
    'vehicle.lent',
    'vehicle.restored',
    'vehicle.returned',
  ])
})

Deno.test('every entry kind the app writes has a mapping', () => {
  // A new entry table that reaches the trigger but not this map delivers
  // nothing, with no error anywhere. This is the list as of the tyre and
  // income work.
  assertEquals(Object.keys(entryKinds).sort(), [
    'cost_entries',
    'fuel_entries',
    'income_entries',
    'odometer_entries',
    'service_entries',
    'trip_entries',
  ])
})

// An edit or a delete is named after the kind the way a new entry is, from
// the one place the names are kept, so a reword cannot drift.
Deno.test('every entry kind has a label to be edited or deleted under', () => {
  for (const kind of Object.values(entryKinds)) {
    assertEquals(typeof kindLabel(kind), 'string', kind)
  }
  assertEquals(kindLabel('fuel'), 'Fill-up')
  assertEquals(kindLabel('fuel', 'hr'), 'Točenje')
  assertEquals(kindLabel('nonsense'), undefined)
})

Deno.test('entry.created reads as it always did', async () => {
  const { body, message } = await build(
    garage(),
    'entry.created',
    entry('fuel_entries', 'INSERT', {
      id: 'f1',
      vehicle_id: 'v1',
      volume_l: 40,
      created_by: 'u1',
    }),
  )

  // A receiver written against the first five keys must not notice the rest
  // arriving. JSON does not promise an order, and people parse it as if it
  // did.
  assertEquals(Object.keys(body), [
    'event',
    'kind',
    'vehicle_id',
    'entry',
    'at',
    'vehicle_name',
    'currency',
    'economy',
  ])
  assertEquals(body.event, 'entry.created')
  assertEquals(body.kind, 'fuel')
  assertEquals(body.vehicle_id, 'v1')
  assertEquals(body.vehicle_name, 'Clio')
  assertEquals(body.currency, 'EUR')
  assertEquals(message.split('\n')[0], '⛽ Fill-up · Clio · by Ana')
})

// The row was written and the drain came round to it: `at` is the first of
// those, which a lost poke puts five minutes before the second.
Deno.test('the time on the body is the time the event was written', async () => {
  const { body } = await build(
    garage(),
    'entry.created',
    entry('cost_entries', 'INSERT', insurance),
  )

  assertEquals(body.at, AT)
})

Deno.test('entry.updated carries the row before and after', async () => {
  const { body, message } = await build(
    garage(),
    'entry.updated',
    entry(
      'fuel_entries',
      'UPDATE',
      { id: 'f1', vehicle_id: 'v1', volume_l: 41 },
      { id: 'f1', vehicle_id: 'v1', volume_l: 40 },
    ),
  )

  assertEquals(body.event, 'entry.updated')
  assertEquals(body.kind, 'fuel')
  assertEquals(body.entry.volume_l, 41)
  assertEquals(body.previous.volume_l, 40)
  assertEquals(Object.keys(body), [
    'event',
    'kind',
    'vehicle_id',
    'entry',
    'previous',
    'at',
    'vehicle_name',
    'currency',
  ])
  assertEquals(message, '✏️ Fill-up edited · Clio\n41 l')
})

// The row knows who logged it and nothing about who changed it, so the line
// says the one thing it knows. "by Ana" on an edit would read as the editor.
Deno.test('an edit or a delete names who logged the row, as that', async () => {
  const edited = await build(
    garage(),
    'entry.updated',
    entry('cost_entries', 'UPDATE', { ...insurance, amount: 320 }, insurance),
  )
  assertEquals(
    edited.message.split('\n')[0],
    '✏️ Cost edited · Clio · logged by Ana',
  )

  const deleted = await build(
    garage(),
    'entry.deleted',
    entry('cost_entries', 'DELETE', insurance),
  )
  assertEquals(
    deleted.message,
    [
      '🗑️ Cost deleted · Clio · logged by Ana',
      'Insurance · €312.00 · 49,680 km',
      '"Renewed for a year"',
    ].join('\n'),
  )
})

Deno.test('entry.deleted carries the row as it was', async () => {
  const { body, message } = await build(
    garage(),
    'entry.deleted',
    entry('cost_entries', 'DELETE', {
      id: 'c1',
      vehicle_id: 'v1',
      amount: 12,
      category: 'parking',
    }),
  )

  assertEquals(body.event, 'entry.deleted')
  assertEquals(body.kind, 'cost')
  assertEquals(body.entry.amount, 12)
  assertEquals('previous' in body, false)
  assertEquals('economy' in body, false)
  assertEquals(message, '🗑️ Cost deleted · Clio\nParking · €12.00')
})

Deno.test('a table the dispatcher does not know builds nothing', async () => {
  const built = await builders['entry.created'](
    garage(),
    row('entry.created', {
      table: 'secrets',
      op: 'INSERT',
      vehicle_id: 'v1',
      record: {},
    }),
  )

  assertEquals(built, null)
})

Deno.test('an entry whose car is gone builds nothing', async () => {
  // Deleted between the trigger and the drain. Without the car there is no
  // name and no fuel to read the row by, and nothing to say about it.
  const built = await builders['entry.created'](
    garage({ vehicles: [] }),
    row('entry.created', entry('fuel_entries', 'INSERT', fillUp)),
  )

  assertEquals(built, null)
})

// Gone and unreadable are different answers. Built into nothing, a row is
// marked processed and the event is lost; thrown, it waits for the next
// drain. A database that blinked is the second.
Deno.test('a car that cannot be read keeps the row for the next drain', async () => {
  const refused = () => ({ error: { message: 'connection reset' } })
  const thrown = () => {
    throw new TypeError('network')
  }
  for (const vehicles of [refused, thrown]) {
    await assertRejects(() =>
      builders['entry.created'](
        garage({ vehicles }),
        row('entry.created', entry('fuel_entries', 'INSERT', fillUp)),
      )
    )
    await assertRejects(() =>
      builders['vehicle.lent'](
        garage({ vehicles }),
        row('vehicle.lent', { vehicle_id: 'v1', record: pass }),
      )
    )
  }
})

Deno.test('the body names the car, the currency and the tank', async () => {
  const { body } = await build(
    garage(),
    'entry.created',
    entry('fuel_entries', 'INSERT', fillUp),
  )

  assertEquals(body.vehicle_name, 'Clio')
  assertEquals(body.currency, 'EUR')
  // Canonical, like everything else in the body: litres per 100 km over
  // kilometres, whatever the household reads. 42.8 l over 702 km.
  assertEquals(body.economy, {
    l_per_100km: 42.8 / 702 * 100,
    distance_km: 702,
    volume_l: 42.8,
  })
  assertEquals(
    body.entry,
    fillUp,
    'the row itself is sent as the trigger wrote it',
  )
})

Deno.test('only a fill-up has an economy to speak of', async () => {
  const admin = garage()

  const { body } = await build(
    admin,
    'entry.created',
    entry('cost_entries', 'INSERT', insurance),
  )

  assertEquals('economy' in body, false)
  assertEquals(body.currency, 'EUR')
  assertEquals(admin.queries.some(isHistory), false)
})

// An edit changes the figure the app shows, and the app is where the current
// figure is; a delete has no tank to close. Neither asks for the history.
Deno.test('an edit or a delete carries no economy and asks for no history', async () => {
  const changes = {
    'entry.updated': entry('fuel_entries', 'UPDATE', fillUp, fillUp),
    'entry.deleted': entry('fuel_entries', 'DELETE', fillUp),
  }
  for (const [event, payload] of Object.entries(changes)) {
    const admin = garage()

    const { body } = await build(admin, event, payload)

    assertEquals('economy' in body, false, event)
    assertEquals(admin.queries.some(isHistory), false, event)
  }
})

Deno.test('the earlier fill-ups are asked for narrowly', async () => {
  const admin = garage()

  await build(admin, 'entry.created', entry('fuel_entries', 'INSERT', fillUp))

  const history = admin.queries.find(isHistory)!
  assertEquals(
    history.select,
    'id, entry_date, odometer_km, volume_l, full_tank, missed_fill, ' +
      'fuel_type_key',
  )
  assertEquals(
    history.filters.filter((f) => f.method !== 'select').map((f) => [
      f.method,
      ...f.args,
    ]),
    [
      ['eq', 'vehicle_id', 'v1'],
      // The trigger fires after the insert, so the new row is already there.
      ['neq', 'id', 'f2'],
      // Nothing past the new reading can be part of a span that ends at it.
      ['lte', 'odometer_km', 49680],
      // The chain's own order, reversed, so the limit drops the farthest row
      // first and can never take a fill out of the middle of a span.
      ['order', 'odometer_km', { ascending: false }],
      ['order', 'entry_date', { ascending: false }],
      ['order', 'full_tank', { ascending: true }],
      ['limit', 60],
    ],
  )
})

Deno.test('a fill that closes no span asks for no history', async () => {
  for (
    const record of [
      { ...fillUp, full_tank: false },
      { ...fillUp, missed_fill: true },
      // A row too thin to be a fuel row at all.
      { id: 'f3', vehicle_id: 'v1', volume_l: 40 },
    ]
  ) {
    const admin = garage()

    const { body } = await build(
      admin,
      'entry.created',
      entry('fuel_entries', 'INSERT', record),
    )

    assertEquals(body.economy, null)
    assertEquals(admin.queries.some(isHistory), false)
  }
})

Deno.test('a chat target is told what a person would want to know', async () => {
  const admin = garage()

  const { message } = await build(
    admin,
    'entry.created',
    entry('fuel_entries', 'INSERT', fillUp),
  )

  assertEquals(
    message,
    [
      '⛽ Fill-up · Clio · by Ana',
      '42.8 l at INA Zagreb · €60.21 (€1.407/l)',
      '6.1 l/100km over 702 km · 49,680 km',
      '"Motorway all the way"',
    ].join('\n'),
  )
  // "by Ana" is whoever the row says created it, and nobody else.
  const profile = admin.queries.find((q) => q.table === 'profiles')!
  assertEquals(
    profile.filters.filter((f) => f.method === 'eq').map((f) => f.args),
    [['user_id', 'u1']],
  )
  // The units are the garage's the row was written in, which the outbox row
  // names: a car sold between the trigger and the drain is still announced
  // in the seller's currency, to the seller's hooks.
  const household = admin.queries.find((q) => q.table === 'households')!
  assertEquals(
    household.filters.filter((f) => f.method === 'eq').map((f) => f.args),
    [['id', 'h1']],
  )
})

Deno.test('a household on miles and gallons is told in miles and gallons', async () => {
  const { message } = await build(
    garage({
      households: [
        { currency_code: 'GBP', distance_unit: 'mi', volume_unit: 'uk_gallon' },
      ],
    }),
    'entry.created',
    entry('fuel_entries', 'INSERT', fillUp),
  )

  assertEquals(message.split('\n').slice(1, 3), [
    '9.41 gal at INA Zagreb · £60.21 (£6.395/gal)',
    '46.3 mpg over 436 mi · 30,870 mi',
  ])
})

Deno.test('an electric car is told in kilowatt-hours', async () => {
  const { message } = await build(
    garage({
      vehicles: [{ ...clio, fuel_type_key: 'fuel_electric' }],
      fuel_entries: [{ ...earlierTank, odometer_km: 49380 }],
    }),
    'entry.created',
    entry('fuel_entries', 'INSERT', {
      ...fillUp,
      volume_l: 54,
      price_per_l: 0.39,
    }),
  )

  // 54 kWh over 49680 - 49380 = 300 km is 18 kWh per 100 km.
  assertEquals(message.split('\n').slice(1, 3), [
    '54 kWh at INA Zagreb · €60.21 (€0.390/kWh)',
    '18.0 kWh/100km over 300 km · 49,680 km',
  ])
})

// A plug-in hybrid kept as petrol with electricity as its second fuel. This
// asks the fill, because a charge is kilowatt-hours whatever the car mainly
// burns, and so does the app (`EnergyType.forEntry`). The two used to differ;
// pinned so that they go on agreeing.
Deno.test('a charge on a car that mainly burns petrol is still kilowatt-hours', async () => {
  const plugIn = () =>
    garage({
      vehicles: [{ ...clio, secondary_fuel_type_key: 'fuel_electric' }],
      fuel_entries: [
        {
          ...earlierTank,
          id: 'e1',
          odometer_km: 49480,
          volume_l: 9,
          fuel_type_key: 'fuel_electric',
        },
      ],
    })
  const lines = async (record: Row) => {
    const { message } = await build(
      plugIn(),
      'entry.created',
      entry('fuel_entries', 'INSERT', record),
    )
    return message.split('\n').slice(1, 3)
  }

  // 12 kWh over 49680 - 49480 = 200 km is 6 kWh per 100 km.
  assertEquals(
    await lines({
      ...fillUp,
      volume_l: 12,
      price_per_l: 0.35,
      total: 4.2,
      fuel_type_key: 'fuel_electric',
    }),
    [
      '12 kWh at INA Zagreb · €4.20 (€0.350/kWh)',
      '6.0 kWh/100km over 200 km · 49,680 km',
    ],
  )
  // Petrol into the same car is litres, and the charge before it is no part
  // of a petrol span: with no earlier petrol tank there is no figure.
  assertEquals(await lines({ ...fillUp, fuel_type_key: 'fuel_petrol' }), [
    '42.8 l at INA Zagreb · €60.21 (€1.407/l)',
    '49,680 km',
  ])
})

// The app gives `FuelEconomy.compute` a main fuel only for a car that takes
// two, and this has to hand over the same thing or the chains split
// differently. See `economyPointsProvider`.
Deno.test('a car on two fuels measures the one that went in', async () => {
  const log = [
    // Logged before the second tank existed, so it names no fuel: petrol.
    { ...earlierTank, id: 'p1', odometer_km: 49180 },
    {
      ...earlierTank,
      id: 'l1',
      odometer_km: 49400,
      volume_l: 50,
      fuel_type_key: 'fuel_lpg',
    },
  ]
  const petrol = entry('fuel_entries', 'INSERT', {
    ...fillUp,
    volume_l: 25,
    fuel_type_key: 'fuel_petrol',
  })

  const biFuel = await build(
    garage({
      vehicles: [{ ...clio, secondary_fuel_type_key: 'fuel_lpg' }],
      fuel_entries: log,
    }),
    'entry.created',
    petrol,
  )
  // 25 l of petrol over 49680 - 49180 = 500 km. The LPG is the other chain's.
  assertEquals(biFuel.body.economy, {
    l_per_100km: 5,
    distance_km: 500,
    volume_l: 25,
  })

  // The same log on a car that says it takes one fuel: the app keeps the
  // unnamed fill and the petrol one apart, so there is no span to report.
  const oneFuel = await build(
    garage({ fuel_entries: log }),
    'entry.created',
    petrol,
  )
  assertEquals(oneFuel.body.economy, null)
})

// Everything looked up beyond the car is decoration on a notification that
// used to arrive without it. None of it may be the reason one does not.
Deno.test('a lookup that fails thins the message and still builds', async () => {
  const refused = () => ({ error: { message: 'permission denied' } })
  const thrown = () => {
    throw new TypeError('network')
  }
  for (const failing of [refused, thrown]) {
    const { body, message } = await build(
      garage({
        households: failing,
        profiles: failing,
        fuel_entries: failing,
      }),
      'entry.created',
      entry('fuel_entries', 'INSERT', fillUp),
    )

    assertEquals(body.currency, null)
    assertEquals(body.economy, null)
    assertEquals(
      message,
      [
        '⛽ Fill-up · Clio',
        '42.8 l at INA Zagreb · 60.21 (1.407/l)',
        '49,680 km',
        '"Motorway all the way"',
      ].join('\n'),
    )
  }
})

// A vehicle row as `to_jsonb(new)` writes it, keys the receiver is not sent
// included.
const clioRow = {
  id: 'v1',
  household_id: 'h1',
  nickname: 'Clio',
  make: 'Renault',
  model: 'Clio',
  year: 2019,
  vin: 'VF1RJA00000000000',
  plate: 'ZG-1234-AB',
  fuel_type_key: 'fuel_petrol',
  secondary_fuel_type_key: null,
  purchase_price: 9000,
  archived: false,
}

Deno.test('vehicle.added names the car without its plate or VIN', async () => {
  const { body, message } = await build(garage(), 'vehicle.added', {
    vehicle_id: 'v1',
    record: clioRow,
  })

  assertEquals(body, {
    event: 'vehicle.added',
    vehicle_id: 'v1',
    vehicle_name: 'Clio',
    vehicle: {
      id: 'v1',
      nickname: 'Clio',
      make: 'Renault',
      model: 'Clio',
      year: 2019,
      fuel_type_key: 'fuel_petrol',
      secondary_fuel_type_key: null,
    },
    at: AT,
  })
  assertEquals(message, '🚙 Car added · Clio')
})

Deno.test('vehicle.archived and vehicle.restored name the car and no more', async () => {
  const archived = await build(garage(), 'vehicle.archived', {
    vehicle_id: 'v1',
    record: { ...clioRow, archived: true },
  })
  assertEquals(archived.body, {
    event: 'vehicle.archived',
    vehicle_id: 'v1',
    vehicle_name: 'Clio',
    at: AT,
  })
  assertEquals(archived.message, '📦 Car archived · Clio')

  const restored = await build(garage(), 'vehicle.restored', {
    vehicle_id: 'v1',
    record: clioRow,
  })
  assertEquals(restored.body.event, 'vehicle.restored')
  assertEquals(restored.message, '📦 Car restored · Clio')
})

Deno.test('a vehicle event is named from the row, and from the table when the row has no name', async () => {
  const admin = garage()

  const fromRow = await build(admin, 'vehicle.archived', {
    vehicle_id: 'v1',
    record: clioRow,
  })
  assertEquals(fromRow.body.vehicle_name, 'Clio')
  assertEquals(admin.queries, [], 'the row said, so nothing was asked')

  const fromTable = await build(admin, 'vehicle.archived', {
    vehicle_id: 'v1',
    record: {},
  })
  assertEquals(fromTable.body.vehicle_name, 'Clio')
  assertEquals(admin.queries.map((q) => q.table), ['vehicles'])
})

Deno.test('vehicle.handed_over says which car left, and not where to', async () => {
  const { body, message } = await build(garage(), 'vehicle.handed_over', {
    vehicle_id: 'v1',
    record: clioRow,
    to_household_id: 'h2',
  })

  assertEquals(body, {
    event: 'vehicle.handed_over',
    vehicle_id: 'v1',
    vehicle_name: 'Clio',
    at: AT,
  })
  assertEquals(message, '🤝 Handed over · Clio')
})

/// A `vehicle_guest_passes` row as `to_jsonb(new)` writes it, once redeemed.
const pass = {
  id: 'p1',
  vehicle_id: 'v1',
  code: 'ABCD-EFGH',
  label: 'Ivan',
  created_by: 'u2',
  starts_at: null,
  expires_at: '2026-10-01T00:00:00+00:00',
  revoked_at: null,
  returned_at: null,
  redeemed_by: 'u1',
  redeemed_at: '2026-09-19T09:00:00+00:00',
  can_log_fuel: true,
  can_log_trips: true,
  can_log_costs: false,
  can_view_history: true,
  can_view_prices: false,
}

Deno.test('vehicle.lent says who has it, until when, and what they may do', async () => {
  const { body, message } = await build(garage(), 'vehicle.lent', {
    vehicle_id: 'v1',
    record: pass,
  })

  assertEquals(body, {
    event: 'vehicle.lent',
    vehicle_id: 'v1',
    vehicle_name: 'Clio',
    borrower: 'Ana',
    until: '2026-10-01T00:00:00+00:00',
    permissions: {
      can_log_fuel: true,
      can_log_trips: true,
      can_log_costs: false,
      can_view_history: true,
      can_view_prices: false,
    },
    at: AT,
  })
  // The pass's code is the key to the car and is not sent.
  assertEquals(JSON.stringify(body).includes('ABCD'), false)
  assertEquals(message, '🔑 Lent out · Clio · to Ana until 1 Oct 2026')
})

Deno.test('a borrower with no profile is still a loan', async () => {
  const { body, message } = await build(
    garage({ profiles: [] }),
    'vehicle.lent',
    { vehicle_id: 'v1', record: pass },
  )

  assertEquals(body.borrower, null)
  assertEquals(message, '🔑 Lent out · Clio · until 1 Oct 2026')
})

// Given back by the borrower (0068) or withdrawn by the owner: the row says
// which in `returned_at` or `revoked_at`, and the event says only that the
// loan is over and whose it was.
Deno.test('vehicle.returned names the borrower, however the loan ended', async () => {
  for (
    const ended of [
      { returned_at: '2026-09-25T18:00:00+00:00' },
      { revoked_at: '2026-09-25T18:00:00+00:00' },
    ]
  ) {
    const { body, message } = await build(garage(), 'vehicle.returned', {
      vehicle_id: 'v1',
      record: { ...pass, ...ended },
    })

    assertEquals(body, {
      event: 'vehicle.returned',
      vehicle_id: 'v1',
      vehicle_name: 'Clio',
      borrower: 'Ana',
      at: AT,
    })
    assertEquals(message, '🔑 Returned · Clio · from Ana')
  }
})

Deno.test('member.joined and member.left name the member', async () => {
  const joined = await build(garage(), 'member.joined', {
    user_id: 'u1',
    role: 'member',
  })
  assertEquals(joined.body, {
    event: 'member.joined',
    member: 'Ana',
    role: 'member',
    at: AT,
  })
  assertEquals(joined.message, '👋 Ana joined the garage')

  const left = await build(garage(), 'member.left', {
    user_id: 'u1',
    role: 'admin',
  })
  assertEquals(left.body, {
    event: 'member.left',
    member: 'Ana',
    role: 'admin',
    at: AT,
  })
  assertEquals(left.message, '👋 Ana left the garage')
})

// A deleted account takes its profile with it, and its membership row goes in
// the same transaction: the garage still hears that somebody left.
Deno.test('a member without a profile is still somebody', async () => {
  const { body, message } = await build(
    garage({ profiles: [] }),
    'member.left',
    { user_id: 'gone', role: 'member' },
  )

  assertEquals(body.member, null)
  assertEquals(message, '👋 Somebody left the garage')
})

Deno.test('reminder.due is the reminder run event, read back from the row', async () => {
  const due: ReminderDue = {
    vehicleId: 'v1',
    vehicleName: 'Clio',
    keys: ['service_oil_change', 'service_air_filter'],
    dueDate: '2026-09-26',
    daysUntilDue: 7,
  }
  const admin = garage()

  const { body, message } = await build(
    admin,
    'reminder.due',
    // As the run wrote it and the database gave it back.
    JSON.parse(JSON.stringify(due)),
  )

  assertEquals(body, JSON.parse(reminderBody(due, new Date(AT))))
  assertEquals(message, reminderMessage(due))
  assertEquals(admin.queries, [], 'the run already looked everything up')
})

Deno.test('a swap keeps its direction through the row', async () => {
  const { body } = await build(garage(), 'reminder.due', {
    vehicleId: 'v1',
    vehicleName: 'Clio',
    keys: ['service_tire_swap_seasonal'],
    dueDate: '2026-11-15',
    daysUntilDue: 30,
    swapDirection: 'to_winter',
  })

  assertEquals(body.swap_direction, 'to_winter')
})

// The policy lets a member insert a ping with any payload they like. Nothing
// in it may reach the wire: the body is the event and the time and the message
// is fixed, whatever the row says.
Deno.test('test.ping is the smallest body there is, whatever the row carries', async () => {
  const { body, message } = await build(garage(), 'test.ping', {
    text: '<script>alert(1)</script>',
    vehicle_id: 'v1',
    at: '1999-01-01T00:00:00.000Z',
  })

  assertEquals(body, { event: 'test.ping', at: AT })
  assertEquals(message, '🔔 Test from Garage')
})

// The policy leaves a member the row's timestamp too. A builder that throws
// leaves its row unprocessed, and the drain reads the outbox oldest first
// across every garage: fifty such rows would be the whole batch, every time.
Deno.test('a ping whose time cannot be read is still built', async () => {
  const before = Date.now()

  const built = await builders['test.ping'](garage(), {
    ...row('test.ping', {}),
    created_at: '200000-01-01T00:00:00+00:00',
  })

  const at = new Date(JSON.parse(built!.body).at).getTime()
  assertEquals(at >= before && at <= Date.now(), true, 'now, not a throw')
})

// The name of a car is typed by a person, and a message with a line break in
// it reads as two. The same hardening an entry gets.
Deno.test('nothing typed can break a message or run it too long', async () => {
  const long = 'x'.repeat(5000)

  const { message } = await build(garage(), 'vehicle.added', {
    vehicle_id: 'v1',
    record: { ...clioRow, nickname: `Cl\nio ${long}` },
  })

  assertEquals(message.split('\n').length, 1)
  assertStringIncludes(message, '🚙 Car added · Cl io xxx')
  assertEquals(message.length < 200, true, `${message.length}`)
})

// One body, and the chat text in whichever language each hook asked for:
// what the drain calls `message` with is the hook's `language` column.
Deno.test('a hook in Croatian or Italian is told in its own words', async () => {
  const fuel = entry('fuel_entries', 'INSERT', fillUp)
  assertEquals(
    (await build(garage(), 'entry.created', fuel, 'hr')).message,
    [
      '⛽ Točenje · Clio · Ana',
      '42,8 l na INA Zagreb · 60,21 € (1,407 €/l)',
      '6,1 l/100km na 702 km · 49.680 km',
      '"Motorway all the way"',
    ].join('\n'),
  )
  assertEquals(
    (await build(garage(), 'entry.created', fuel, 'it')).message.split(
      '\n',
    )[0],
    '⛽ Rifornimento · Clio · Ana',
  )

  // An edit is named after the kind in the kind's own gender, and the person
  // named is still the one who logged it, said without a verb that would
  // have to choose one for them.
  const edit = entry(
    'cost_entries',
    'UPDATE',
    { ...insurance, amount: 320 },
    insurance,
  )
  assertEquals(
    (await build(garage(), 'entry.updated', edit, 'hr')).message,
    '✏️ Trošak uređen · Clio · unos: Ana\nOsiguranje · 320,00 € · 49.680 km\n"Renewed for a year"',
  )
  assertEquals(
    (await build(garage(), 'entry.updated', edit, 'it')).message.split('\n')[0],
    '✏️ Spesa modificata · Clio · voce di Ana',
  )
  assertEquals(
    (await build(
      garage(),
      'entry.deleted',
      entry('cost_entries', 'DELETE', insurance),
      'hr',
    )).message.split('\n')[0],
    '🗑️ Trošak obrisan · Clio · unos: Ana',
  )

  const car = { vehicle_id: 'v1', record: clioRow }
  assertEquals(
    (await build(garage(), 'vehicle.added', car, 'hr')).message,
    '🚙 Novi auto · Clio',
  )
  assertEquals(
    (await build(garage(), 'vehicle.added', car, 'it')).message,
    '🚙 Auto aggiunta · Clio',
  )
  assertEquals(
    (await build(garage(), 'vehicle.archived', car, 'hr')).message,
    '📦 Auto arhiviran · Clio',
  )
  assertEquals(
    (await build(garage(), 'vehicle.restored', car, 'it')).message,
    '📦 Auto ripristinata · Clio',
  )
  assertEquals(
    (await build(garage(), 'vehicle.handed_over', car, 'hr')).message,
    '🤝 Predano · Clio',
  )
  assertEquals(
    (await build(garage(), 'vehicle.handed_over', car, 'it')).message,
    '🤝 Ceduta · Clio',
  )

  // The day is written as the reader writes one, and the borrower is named
  // with no preposition that would have to decline the name.
  const loan = { vehicle_id: 'v1', record: pass }
  assertEquals(
    (await build(garage(), 'vehicle.lent', loan, 'hr')).message,
    '🔑 Posuđeno · Clio · Ana · do 1. lis 2026.',
  )
  assertEquals(
    (await build(garage(), 'vehicle.lent', loan, 'it')).message,
    '🔑 Prestata · Clio · ad Ana fino al 1 ott 2026',
  )
  assertEquals(
    (await build(garage({ profiles: [] }), 'vehicle.lent', loan, 'hr')).message,
    '🔑 Posuđeno · Clio · do 1. lis 2026.',
  )
  const back = { vehicle_id: 'v1', record: { ...pass, returned_at: AT } }
  assertEquals(
    (await build(garage(), 'vehicle.returned', back, 'hr')).message,
    '🔑 Vraćeno · Clio · Ana',
  )
  assertEquals(
    (await build(garage(), 'vehicle.returned', back, 'it')).message,
    '🔑 Restituita · Clio · da Ana',
  )

  const member = { user_id: 'u1', role: 'member' }
  assertEquals(
    (await build(garage(), 'member.joined', member, 'hr')).message,
    '👋 Ana je sada dio garaže',
  )
  assertEquals(
    (await build(garage(), 'member.left', member, 'hr')).message,
    '👋 Ana više nije dio garaže',
  )
  assertEquals(
    (await build(garage(), 'member.joined', member, 'it')).message,
    '👋 Ana ora fa parte del garage',
  )
  assertEquals(
    (await build(garage(), 'member.left', member, 'it')).message,
    '👋 Ana non fa più parte del garage',
  )
  assertEquals(
    (await build(
      garage({ profiles: [] }),
      'member.left',
      { user_id: 'gone' },
      'hr',
    )).message,
    '👋 Netko više nije dio garaže',
  )
  assertEquals(
    (await build(
      garage({ profiles: [] }),
      'member.joined',
      { user_id: 'gone' },
      'it',
    )).message,
    '👋 Qualcuno ora fa parte del garage',
  )

  const due = {
    vehicleId: 'v1',
    vehicleName: 'Clio',
    keys: ['service_oil_change', 'service_air_filter'],
    dueDate: '2026-09-26',
    daysUntilDue: 7,
  }
  assertEquals(
    (await build(garage(), 'reminder.due', due, 'hr')).message,
    '🔔 Dospijeva za 7 dana · Clio\nZamjena ulja, Filtar zraka · 26. ruj 2026.',
  )
  assertEquals(
    (await build(garage(), 'reminder.due', due, 'it')).message,
    "🔔 Scade tra 7 giorni · Clio\nCambio dell'olio, Filtro dell'aria · 26 set 2026",
  )

  assertEquals(
    (await build(garage(), 'test.ping', {}, 'hr')).message,
    '🔔 Test iz aplikacije Garage',
  )
  assertEquals(
    (await build(garage(), 'test.ping', {}, 'it')).message,
    "🔔 Test dall'app Garage",
  )
})

// The column is checked, and the drain reads it; but a builder is a function
// of a string, and a string it does not know is English rather than a throw.
Deno.test('a language the builders do not know reads as English', async () => {
  const { message } = await build(garage(), 'test.ping', {}, 'de')
  assertEquals(message, '🔔 Test from Garage')
})
