import { assertEquals } from 'jsr:@std/assert@1'
import { entryKinds, makeHandler } from './handler.ts'
import { sign } from '../_shared/webhooks.ts'
import {
  fakeClient,
  type RecordedQuery,
  stubEnv,
} from '../_test/fake_supabase.ts'

stubEnv()

const AT = new Date('2026-08-17T10:00:00.000Z')

interface Call {
  url: string
  headers: Record<string, string>
  body: string
}

type Row = Record<string, unknown>
type Tables = NonNullable<
  NonNullable<Parameters<typeof fakeClient>[0]>['tables']
>

/// A handler wired to a recording fetch, so a delivery can be inspected
/// without a server on the other end.
///
/// The handler believes nothing a payload says about a row except its id: it
/// reads the row back and sends that. So the honest case has two halves — the
/// row is in its table, and a copy of it is posted — and `log` does both. A
/// forgery is a test that stores one row and posts another, with `insert`.
///
/// The shared fake answers every query on a table with the same rows, which
/// cannot tell "this row, by id" from "this car's history". For the entry
/// tables alone, an `eq('id', …)` is honoured here. A test that gives a table
/// as a function is answering for itself, and is left to.
function handlerWith(
  tables: Tables,
  respond: (url: string) => Response | Promise<Response> = () =>
    new Response('', { status: 200 }),
) {
  const stored: Record<string, Row[]> = {}
  const entryTables: Tables = {}
  for (const table of Object.keys(entryKinds)) {
    const given = tables[table]
    if (typeof given === 'function') {
      continue
    }
    entryTables[table] = (query: RecordedQuery) => {
      const rows = [...((given ?? []) as Row[]), ...(stored[table] ?? [])]
      const byId = query.filters.find((filter) =>
        filter.method === 'eq' && filter.args[0] === 'id'
      )
      return byId ? rows.filter((row) => row.id === byId.args[1]) : rows
    }
  }
  const client = fakeClient({ tables: { ...tables, ...entryTables } })
  const calls: Call[] = []
  const handler = makeHandler({
    createClient: () => client,
    now: () => AT,
    fetch: ((url: string, init: RequestInit) => {
      calls.push({
        url,
        headers: init.headers as Record<string, string>,
        body: init.body as string,
      })
      return Promise.resolve(respond(url))
    }) as unknown as typeof fetch,
  })
  /// What the trigger does: the row goes into its table, and is posted.
  const log = (table: string, row: Row) => {
    ;(stored[table] ??= []).push(row)
    return handler(insert(table, row))
  }
  return { handler, client, calls, log }
}

const insert = (table: string, record: Record<string, unknown> | null) =>
  new Request('http://localhost/dispatch-webhooks', {
    method: 'POST',
    body: JSON.stringify({ type: 'INSERT', table, record, old_record: null }),
  })

const oneHook = {
  vehicles: [{ household_id: 'h1' }],
  webhooks: [
    {
      id: 'w1',
      url: 'https://home.example/hook',
      secret: 's3cret',
      events: ['entry.created'],
    },
  ],
}

Deno.test('only POST is accepted', async () => {
  const { handler } = handlerWith(oneHook)

  const response = await handler(
    new Request('http://localhost/dispatch-webhooks', { method: 'GET' }),
  )

  assertEquals(response.status, 405)
})

Deno.test('an insert into a known entry table is delivered', async () => {
  const { log, calls } = handlerWith(oneHook)

  const response = await log('fuel_entries', { id: 'f1', vehicle_id: 'v1' })

  assertEquals(await response.json(), { delivered: 1 })
  assertEquals(calls.length, 1)
  assertEquals(calls[0].url, 'https://home.example/hook')
})

Deno.test('the payload names the kind, the car, and when', async () => {
  const { log, calls } = handlerWith(oneHook)

  await log('fuel_entries', { id: 'f1', vehicle_id: 'v1', volume_l: 40 })

  assertEquals(JSON.parse(calls[0].body), {
    event: 'entry.created',
    kind: 'fuel',
    vehicle_id: 'v1',
    entry: { id: 'f1', vehicle_id: 'v1', volume_l: 40 },
    at: AT.toISOString(),
    vehicle_name: null,
    currency: null,
    economy: null,
  })
})

// A receiver written against the first five keys must not notice the rest
// arriving. JSON does not promise an order, and people parse it as if it did.
Deno.test('what was added to the payload was added after what was there', async () => {
  const { log, calls } = handlerWith(oneHook)

  await log('fuel_entries', { id: 'f1', vehicle_id: 'v1', volume_l: 40 })

  assertEquals(Object.keys(JSON.parse(calls[0].body)), [
    'event',
    'kind',
    'vehicle_id',
    'entry',
    'at',
    'vehicle_name',
    'currency',
    'economy',
  ])
})

Deno.test('every call is signed with the hook own secret', async () => {
  const { log, calls } = handlerWith(oneHook)

  await log('fuel_entries', { id: 'f1', vehicle_id: 'v1' })

  assertEquals(
    calls[0].headers['X-Garage-Signature'],
    await sign('s3cret', calls[0].body),
    'the signature is what lets a receiver tell a real call from anything ' +
      'else that has found its URL',
  )
  assertEquals(calls[0].headers['X-Garage-Event'], 'entry.created')
})

Deno.test('an update or a delete is not an entry being created', async () => {
  for (const type of ['UPDATE', 'DELETE']) {
    // The row is there to be read, so it is the event that stops this.
    const row = { id: 'f1', vehicle_id: 'v1' }
    const { handler, calls } = handlerWith({ ...oneHook, fuel_entries: [row] })

    const response = await handler(
      new Request('http://localhost/dispatch-webhooks', {
        method: 'POST',
        body: JSON.stringify({
          type,
          table: 'fuel_entries',
          record: row,
          old_record: null,
        }),
      }),
    )

    assertEquals(await response.json(), { delivered: 0 })
    assertEquals(calls, [], `${type} should deliver nothing`)
  }
})

Deno.test('a table nobody mapped is ignored rather than guessed at', async () => {
  const { handler, calls } = handlerWith(oneHook)

  const response = await handler(
    insert('attachments', { id: 'a1', vehicle_id: 'v1' }),
  )

  assertEquals(await response.json(), { delivered: 0 })
  assertEquals(calls, [])
})

Deno.test('every entry kind the app writes has a mapping', () => {
  // The silent half of the three-places rule in the file header: a new entry
  // table that reaches the trigger but not this map delivers nothing, with no
  // error anywhere. This is the list as of the tyre and income work.
  assertEquals(Object.keys(entryKinds).sort(), [
    'cost_entries',
    'fuel_entries',
    'income_entries',
    'odometer_entries',
    'service_entries',
    'trip_entries',
  ])
})

Deno.test('a row with no vehicle has no household, so nothing is sent', async () => {
  const { handler, calls } = handlerWith(oneHook)

  const response = await handler(insert('fuel_entries', { id: 'f1' }))

  assertEquals(await response.json(), { delivered: 0 })
  assertEquals(calls, [])
})

Deno.test('a vehicle that cannot be resolved sends nothing', async () => {
  const { log, calls } = handlerWith({
    vehicles: [],
    webhooks: oneHook.webhooks,
  })

  const response = await log('fuel_entries', { id: 'f1', vehicle_id: 'gone' })

  assertEquals(await response.json(), { delivered: 0 })
  assertEquals(
    calls,
    [],
    'without a household there is nothing to scope hooks to, and guessing ' +
      'would leak one household activity to another',
  )
})

Deno.test('hooks are looked up for that vehicle household only', async () => {
  const { log, client } = handlerWith(oneHook)

  await log('fuel_entries', { id: 'f1', vehicle_id: 'v1' })

  const lookup = client.queries.find((q) => q.table === 'webhooks')!
  assertEquals(
    lookup.filters.filter((f) => f.method === 'eq').map((f) => f.args),
    [['household_id', 'h1'], ['active', true]],
  )
})

Deno.test('a hook not subscribed to the event is skipped', async () => {
  const { log, calls } = handlerWith({
    vehicles: [{ household_id: 'h1' }],
    webhooks: [
      {
        id: 'w1',
        url: 'https://home.example/hook',
        secret: 's',
        events: ['something.else'],
      },
    ],
  })

  const response = await log('fuel_entries', { id: 'f1', vehicle_id: 'v1' })

  assertEquals(await response.json(), { delivered: 0 })
  assertEquals(calls, [])
})

Deno.test('a receiver that is switched off is recorded, not retried', async () => {
  const { log, client, calls } = handlerWith(oneHook, () => {
    throw new TypeError('connection refused')
  })

  const response = await log('fuel_entries', { id: 'f1', vehicle_id: 'v1' })

  assertEquals(await response.json(), { delivered: 0 })
  assertEquals(calls.length, 1, 'one attempt, and only one')

  const update = client.queries.find((q) => q.operation === 'update')!
  assertEquals(update.table, 'webhooks')
  assertEquals(update.payload, {
    last_delivery_at: AT.toISOString(),
    last_delivery_status: 0,
    // Status 0 is what the app shows as "the last call did not get through";
    // swallowing the throw without recording it would leave a household
    // staring at a hook that looks healthy and delivers nothing.
  })
})

Deno.test('a receiver that answers with an error is recorded with its status', async () => {
  const { log, client } = handlerWith(
    oneHook,
    () => new Response('nope', { status: 500 }),
  )

  const response = await log('fuel_entries', { id: 'f1', vehicle_id: 'v1' })

  assertEquals(await response.json(), { delivered: 0 })
  const update = client.queries.find((q) => q.operation === 'update')!
  assertEquals(
    (update.payload as { last_delivery_status: number }).last_delivery_status,
    500,
  )
})

Deno.test('one failing hook does not stop the next one', async () => {
  const { log, calls } = handlerWith(
    {
      vehicles: [{ household_id: 'h1' }],
      webhooks: [
        {
          id: 'w1',
          url: 'https://down.example/hook',
          secret: 's',
          events: ['entry.created'],
        },
        {
          id: 'w2',
          url: 'https://up.example/hook',
          secret: 's',
          events: ['entry.created'],
        },
      ],
    },
    (url) => {
      if (url.includes('down')) throw new TypeError('connection refused')
      return new Response('', { status: 200 })
    },
  )

  const response = await log('fuel_entries', { id: 'f1', vehicle_id: 'v1' })

  assertEquals(await response.json(), { delivered: 1 })
  assertEquals(calls.length, 2)
})

// The 400 that started this: a Discord webhook rejects any body without
// `content`, so every delivery to one failed while the dispatcher reported
// having posted correctly — which it had.
Deno.test('a Discord hook receives what Discord accepts', async () => {
  const { log, calls } = handlerWith({
    vehicles: [{ household_id: 'h1', nickname: 'Golf' }],
    webhooks: [
      {
        id: 'w1',
        url: 'https://discord.com/api/webhooks/123/abc',
        secret: 's3cret',
        events: ['entry.created'],
      },
    ],
  })

  await log('fuel_entries', {
    id: 'f1',
    vehicle_id: 'v1',
    volume_l: 42,
    total: 65.4,
  })

  const sent = JSON.parse(calls[0].body)
  assertEquals(Object.keys(sent), ['content', 'allowed_mentions', 'flags'])
  assertEquals(sent.content, '⛽ Fill-up · Golf\n42 l · 65.40')
})

Deno.test('a Telegram hook receives text, keeping chat_id in the URL', async () => {
  const { log, calls } = handlerWith({
    vehicles: [{ household_id: 'h1', nickname: 'Golf' }],
    webhooks: [
      {
        id: 'w1',
        url: 'https://api.telegram.org/bot123:abc/sendMessage?chat_id=7',
        secret: 's3cret',
        events: ['entry.created'],
      },
    ],
  })

  await log('trip_entries', { id: 't1', vehicle_id: 'v1', distance_km: 188 })

  assertEquals(Object.keys(JSON.parse(calls[0].body)), ['text'])
  assertEquals(
    calls[0].url,
    'https://api.telegram.org/bot123:abc/sendMessage?chat_id=7',
  )
})

// The contract this feature was built for is untouched: a household's own
// service still gets the signed JSON, and the signature still covers it.
Deno.test('a generic receiver still gets the signed payload', async () => {
  const { log, calls } = handlerWith(oneHook)

  await log('fuel_entries', { id: 'f1', vehicle_id: 'v1', volume_l: 40 })

  const sent = JSON.parse(calls[0].body)
  assertEquals(sent.event, 'entry.created')
  assertEquals(sent.kind, 'fuel')
  assertEquals(
    calls[0].headers['X-Garage-Signature'],
    await sign('s3cret', calls[0].body),
  )
})

// A garage as the handler finds it in production: a car with a name, a
// household with units and a currency, a member with a profile, and a log.
const clio = {
  household_id: 'h1',
  nickname: 'Clio',
  fuel_type_key: 'fuel_petrol',
  secondary_fuel_type_key: null,
}

const garage = {
  vehicles: [clio],
  households: [
    { currency_code: 'EUR', distance_unit: 'km', volume_unit: 'liter' },
  ],
  profiles: [{ display_name: 'Ana' }],
  // The tank before the one below, 702 km earlier.
  fuel_entries: [
    {
      id: 'f1',
      entry_date: '2026-02-01',
      odometer_km: 48978,
      volume_l: 45,
      full_tank: true,
      missed_fill: false,
      fuel_type_key: null,
    },
  ],
}

/// A `fuel_entries` row as `to_jsonb(new)` posts it.
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

/// The history read, as against the read of the one row a payload names.
const isHistory = (query: RecordedQuery) =>
  query.table === 'fuel_entries' && query.select !== '*'

const hookAt = (url: string) => [
  { id: 'w1', url, secret: 's3cret', events: ['entry.created'] },
]
const generic = hookAt('https://home.example/hook')
const discord = hookAt('https://discord.com/api/webhooks/123/abc')

Deno.test('the payload names the car, the currency and the tank', async () => {
  const { log, calls } = handlerWith({ ...garage, webhooks: generic })

  await log('fuel_entries', fillUp)

  const sent = JSON.parse(calls[0].body)
  assertEquals(sent.vehicle_name, 'Clio')
  assertEquals(sent.currency, 'EUR')
  // Canonical, like everything else in the body: litres per 100 km over
  // kilometres, whatever the household reads. 42.8 l over 702 km.
  assertEquals(sent.economy, {
    l_per_100km: 42.8 / 702 * 100,
    distance_km: 702,
    volume_l: 42.8,
  })
  assertEquals(sent.entry, fillUp, 'the row itself is sent as it was stored')
  assertEquals(
    calls[0].headers['X-Garage-Signature'],
    await sign('s3cret', calls[0].body),
    'the signature covers the body that was sent, new fields and all',
  )
})

Deno.test('only a fill-up has an economy to speak of', async () => {
  const { log, client, calls } = handlerWith({
    ...garage,
    webhooks: generic,
  })

  await log('cost_entries', { id: 'c1', vehicle_id: 'v1', amount: 312 })

  const sent = JSON.parse(calls[0].body)
  assertEquals('economy' in sent, false)
  assertEquals(sent.currency, 'EUR')
  assertEquals(client.queries.some((q) => q.table === 'fuel_entries'), false)
  assertEquals(client.queries.some(isHistory), false)
})

Deno.test('the earlier fill-ups are asked for narrowly', async () => {
  const { log, client } = handlerWith({ ...garage, webhooks: generic })

  await log('fuel_entries', fillUp)

  const history = client.queries.find(isHistory)!
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
    const { log, client, calls } = handlerWith({
      ...garage,
      webhooks: generic,
    })

    await log('fuel_entries', record)

    assertEquals(JSON.parse(calls[0].body).economy, null)
    assertEquals(client.queries.some(isHistory), false)
  }
})

// Most households have no webhook, and every entry any of them logs comes
// through here. Those must cost a vehicle and a hook lookup, not five queries.
Deno.test('a household with nothing to call is not looked up any further', async () => {
  for (
    const webhooks of [
      [],
      [{ id: 'w1', url: 'https://x.example', secret: 's', events: ['other'] }],
    ]
  ) {
    const { log, client, calls } = handlerWith({ ...garage, webhooks })

    const response = await log('fuel_entries', fillUp)

    assertEquals(await response.json(), { delivered: 0 })
    assertEquals(calls, [])
    assertEquals(client.queries.map((q) => q.table), ['vehicles', 'webhooks'])
  }
})

Deno.test('a chat target is told what a person would want to know', async () => {
  const { log, client, calls } = handlerWith({
    ...garage,
    webhooks: discord,
  })

  await log('fuel_entries', fillUp)

  assertEquals(
    JSON.parse(calls[0].body).content,
    [
      '⛽ Fill-up · Clio · by Ana',
      '42.8 l at INA Zagreb · €60.21 (€1.407/l)',
      '6.1 l/100km over 702 km · 49,680 km',
      '"Motorway all the way"',
    ].join('\n'),
  )
  // "by Ana" is whoever the row says created it, and nobody else.
  const profile = client.queries.find((q) => q.table === 'profiles')!
  assertEquals(
    profile.filters.filter((f) => f.method === 'eq').map((f) => f.args),
    [['user_id', 'u1']],
  )
  const household = client.queries.find((q) => q.table === 'households')!
  assertEquals(
    household.filters.filter((f) => f.method === 'eq').map((f) => f.args),
    [['id', 'h1']],
  )
})

Deno.test('a household on miles and gallons is told in miles and gallons', async () => {
  const { log, calls } = handlerWith({
    ...garage,
    households: [
      { currency_code: 'GBP', distance_unit: 'mi', volume_unit: 'uk_gallon' },
    ],
    webhooks: discord,
  })

  await log('fuel_entries', fillUp)

  assertEquals(JSON.parse(calls[0].body).content.split('\n').slice(1, 3), [
    '9.41 gal at INA Zagreb · £60.21 (£6.395/gal)',
    '46.3 mpg over 436 mi · 30,870 mi',
  ])
})

Deno.test('an electric car is told in kilowatt-hours', async () => {
  const { log, calls } = handlerWith({
    ...garage,
    vehicles: [{ ...clio, fuel_type_key: 'fuel_electric' }],
    fuel_entries: [{ ...garage.fuel_entries[0], odometer_km: 49380 }],
    webhooks: discord,
  })

  await log('fuel_entries', { ...fillUp, volume_l: 54, price_per_l: 0.39 })

  // 54 kWh over 49680 - 49380 = 300 km is 18 kWh per 100 km.
  assertEquals(JSON.parse(calls[0].body).content.split('\n').slice(1, 3), [
    '54 kWh at INA Zagreb · €60.21 (€0.390/kWh)',
    '18.0 kWh/100km over 300 km · 49,680 km',
  ])
})

// A plug-in hybrid kept as petrol with electricity as its second fuel. This
// asks the fill, because a charge is kilowatt-hours whatever the car mainly
// burns, and so does the app (`EnergyType.forEntry`). The two used to differ;
// pinned so that they go on agreeing.
Deno.test('a charge on a car that mainly burns petrol is still kilowatt-hours', async () => {
  const plugIn = {
    ...garage,
    vehicles: [{ ...clio, secondary_fuel_type_key: 'fuel_electric' }],
    fuel_entries: [
      {
        ...garage.fuel_entries[0],
        id: 'e1',
        odometer_km: 49480,
        volume_l: 9,
        fuel_type_key: 'fuel_electric',
      },
    ],
    webhooks: discord,
  }
  const lines = async (record: Record<string, unknown>) => {
    const { log, calls } = handlerWith(plugIn)
    await log('fuel_entries', record)
    return JSON.parse(calls[0].body).content.split('\n').slice(1, 3)
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
    { ...garage.fuel_entries[0], id: 'p1', odometer_km: 49180 },
    {
      ...garage.fuel_entries[0],
      id: 'l1',
      odometer_km: 49400,
      volume_l: 50,
      fuel_type_key: 'fuel_lpg',
    },
  ]
  const petrol = { ...fillUp, volume_l: 25, fuel_type_key: 'fuel_petrol' }

  const biFuel = handlerWith({
    ...garage,
    vehicles: [{ ...clio, secondary_fuel_type_key: 'fuel_lpg' }],
    fuel_entries: log,
    webhooks: generic,
  })
  await biFuel.log('fuel_entries', petrol)
  // 25 l of petrol over 49680 - 49180 = 500 km. The LPG is the other chain's.
  assertEquals(JSON.parse(biFuel.calls[0].body).economy, {
    l_per_100km: 5,
    distance_km: 500,
    volume_l: 25,
  })

  // The same log on a car that says it takes one fuel: the app keeps the
  // unnamed fill and the petrol one apart, so there is no span to report.
  const oneFuel = handlerWith({
    ...garage,
    fuel_entries: log,
    webhooks: generic,
  })
  await oneFuel.log('fuel_entries', petrol)
  assertEquals(JSON.parse(oneFuel.calls[0].body).economy, null)
})

// Everything added here is decoration on a notification that used to arrive
// without it. None of it may be the reason one does not arrive.
Deno.test('a lookup that fails thins the message and still sends it', async () => {
  const refused = () => ({ error: { message: 'permission denied' } })
  const { handler, calls } = handlerWith({
    vehicles: [clio],
    households: refused,
    profiles: refused,
    // The row itself can be read; the history before it cannot.
    fuel_entries: (query: RecordedQuery) =>
      isHistory(query) ? refused() : [fillUp],
    webhooks: [...generic, { ...discord[0], id: 'w2' }],
  })

  const response = await handler(insert('fuel_entries', fillUp))

  assertEquals(await response.json(), { delivered: 2 })
  const sent = JSON.parse(calls[0].body)
  assertEquals(sent.currency, null)
  assertEquals(sent.economy, null)
  assertEquals(
    JSON.parse(calls[1].body).content,
    [
      '⛽ Fill-up · Clio',
      '42.8 l at INA Zagreb · 60.21 (1.407/l)',
      '49,680 km',
      '"Motorway all the way"',
    ].join('\n'),
  )
})

Deno.test('and so does a lookup that throws', async () => {
  const { log, calls } = handlerWith({
    vehicles: [clio],
    households: () => {
      throw new TypeError('network')
    },
    webhooks: generic,
  })

  const response = await log('fuel_entries', fillUp)

  assertEquals(await response.json(), { delivered: 1 })
  assertEquals(JSON.parse(calls[0].body).currency, null)
})

// The trigger calls this function with the project's anon key, which ships in
// every copy of the app. So a request proves nothing about where it came from,
// and anybody who knows a vehicle's id can post an INSERT that never happened.
// What they cannot do is write to the table. The handler therefore takes two
// things from a payload — which table, which id — and reads the rest back.
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

Deno.test('a forged payload sends the stored row, not what it claims', async () => {
  const { handler, client, calls } = handlerWith({
    ...garage,
    cost_entries: [insurance],
    webhooks: [...generic, { ...discord[0], id: 'w2' }],
  })

  await handler(
    insert('cost_entries', {
      ...insurance,
      amount: 1,
      category: 'fine',
      notes: 'Pay the rest at https://evil.example today',
      created_by: 'somebody-else',
    }),
  )

  assertEquals(JSON.parse(calls[0].body).entry, insurance)
  assertEquals(
    JSON.parse(calls[1].body).content,
    [
      '🧾 Cost · Clio · by Ana',
      'Insurance · €312.00 · 49,680 km',
      '"Renewed for a year"',
    ].join('\n'),
  )
  // "by Ana" is whoever the stored row says, too.
  const profile = client.queries.find((q) => q.table === 'profiles')!
  assertEquals(
    profile.filters.filter((f) => f.method === 'eq').map((f) => f.args),
    [['user_id', 'u1']],
  )
})

Deno.test('the row is asked for by id, and only once somebody is listening', async () => {
  const { log, client } = handlerWith({ ...garage, webhooks: generic })

  await log('cost_entries', insurance)

  const read = client.queries.find((q) => q.table === 'cost_entries')!
  assertEquals(read.select, '*')
  assertEquals(
    read.filters.filter((f) => f.method === 'eq').map((f) => f.args),
    [['id', 'c1']],
  )
  assertEquals(
    client.queries.map((q) => q.table).indexOf('cost_entries') >
      client.queries.map((q) => q.table).indexOf('webhooks'),
    true,
  )
})

Deno.test('a payload naming a row that does not exist sends nothing', async () => {
  const { handler, client, calls } = handlerWith({
    ...garage,
    cost_entries: [insurance],
    webhooks: generic,
  })

  const response = await handler(
    insert('cost_entries', { ...insurance, id: 'never-inserted' }),
  )

  assertEquals(await response.json(), { delivered: 0 })
  assertEquals(calls, [])
  assertEquals(
    client.queries.some((q) => q.operation === 'update'),
    false,
    'nothing was attempted, so the hook has no failed delivery to show for it',
  )
})

Deno.test('nor does a payload that names no row at all', async () => {
  const { handler, client, calls } = handlerWith({
    ...garage,
    cost_entries: [insurance],
    webhooks: generic,
  })
  const { id: _, ...anonymous } = insurance

  const response = await handler(insert('cost_entries', anonymous))

  assertEquals(await response.json(), { delivered: 0 })
  assertEquals(calls, [])
  assertEquals(client.queries, [], 'there is nothing to look up')
})

// The one that would leak. The hooks called are those of the household that
// owns the vehicle the payload names; the row sent is the one the id names. If
// the two are allowed to differ, anybody can have one household's fill-ups
// delivered to another household's Discord — their own, say.
Deno.test('a row that belongs to another vehicle sends nothing', async () => {
  const { handler, calls } = handlerWith({
    ...garage,
    cost_entries: [{ ...insurance, vehicle_id: 'somebody-elses-car' }],
    webhooks: generic,
  })

  const response = await handler(insert('cost_entries', insurance))

  assertEquals(await response.json(), { delivered: 0 })
  assertEquals(calls, [])
})

// The opposite of every other lookup here. Those are decoration, and a failure
// leaves them out. This one is the evidence: without it all that is left is
// the payload's word, and falling back to that would make "cause the read to
// fail" a way to be believed.
Deno.test('a row that cannot be read sends nothing, rather than the payload', async () => {
  const failures = [
    () => ({ error: { message: 'permission denied' } }),
    () => {
      throw new TypeError('network')
    },
  ]
  for (const cost_entries of failures) {
    const { handler, calls } = handlerWith({
      ...garage,
      cost_entries,
      webhooks: generic,
    })

    const response = await handler(insert('cost_entries', insurance))

    assertEquals(await response.json(), { delivered: 0 })
    assertEquals(calls, [])
  }
})
