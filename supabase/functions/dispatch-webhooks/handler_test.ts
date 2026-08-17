import { assertEquals } from 'jsr:@std/assert@1'
import { entryKinds, makeHandler, sign } from './handler.ts'
import { fakeClient, stubEnv } from '../_test/fake_supabase.ts'

stubEnv()

const AT = new Date('2026-08-17T10:00:00.000Z')

interface Call {
  url: string
  headers: Record<string, string>
  body: string
}

/// A handler wired to a recording fetch, so a delivery can be inspected
/// without a server on the other end.
function handlerWith(
  tables: NonNullable<Parameters<typeof fakeClient>[0]>['tables'],
  respond: (url: string) => Response | Promise<Response> = () =>
    new Response('', { status: 200 }),
) {
  const client = fakeClient({ tables })
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
  return { handler, client, calls }
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
  const { handler, calls } = handlerWith(oneHook)

  const response = await handler(insert('fuel_entries', { vehicle_id: 'v1' }))

  assertEquals(await response.json(), { delivered: 1 })
  assertEquals(calls.length, 1)
  assertEquals(calls[0].url, 'https://home.example/hook')
})

Deno.test('the payload names the kind, the car, and when', async () => {
  const { handler, calls } = handlerWith(oneHook)

  await handler(insert('fuel_entries', { vehicle_id: 'v1', volume_l: 40 }))

  assertEquals(JSON.parse(calls[0].body), {
    event: 'entry.created',
    kind: 'fuel',
    vehicle_id: 'v1',
    entry: { vehicle_id: 'v1', volume_l: 40 },
    at: AT.toISOString(),
  })
})

Deno.test('every call is signed with the hook own secret', async () => {
  const { handler, calls } = handlerWith(oneHook)

  await handler(insert('fuel_entries', { vehicle_id: 'v1' }))

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
    const { handler, calls } = handlerWith(oneHook)

    const response = await handler(
      new Request('http://localhost/dispatch-webhooks', {
        method: 'POST',
        body: JSON.stringify({
          type,
          table: 'fuel_entries',
          record: { vehicle_id: 'v1' },
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

  const response = await handler(insert('attachments', { vehicle_id: 'v1' }))

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
  const { handler, calls } = handlerWith({
    vehicles: [],
    webhooks: oneHook.webhooks,
  })

  const response = await handler(insert('fuel_entries', { vehicle_id: 'gone' }))

  assertEquals(await response.json(), { delivered: 0 })
  assertEquals(
    calls,
    [],
    'without a household there is nothing to scope hooks to, and guessing ' +
      'would leak one household activity to another',
  )
})

Deno.test('hooks are looked up for that vehicle household only', async () => {
  const { handler, client } = handlerWith(oneHook)

  await handler(insert('fuel_entries', { vehicle_id: 'v1' }))

  const lookup = client.queries.find((q) => q.table === 'webhooks')!
  assertEquals(
    lookup.filters.filter((f) => f.method === 'eq').map((f) => f.args),
    [['household_id', 'h1'], ['active', true]],
  )
})

Deno.test('a hook not subscribed to the event is skipped', async () => {
  const { handler, calls } = handlerWith({
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

  const response = await handler(insert('fuel_entries', { vehicle_id: 'v1' }))

  assertEquals(await response.json(), { delivered: 0 })
  assertEquals(calls, [])
})

Deno.test('a receiver that is switched off is recorded, not retried', async () => {
  const { handler, client, calls } = handlerWith(oneHook, () => {
    throw new TypeError('connection refused')
  })

  const response = await handler(insert('fuel_entries', { vehicle_id: 'v1' }))

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
  const { handler, client } = handlerWith(
    oneHook,
    () => new Response('nope', { status: 500 }),
  )

  const response = await handler(insert('fuel_entries', { vehicle_id: 'v1' }))

  assertEquals(await response.json(), { delivered: 0 })
  const update = client.queries.find((q) => q.operation === 'update')!
  assertEquals(
    (update.payload as { last_delivery_status: number }).last_delivery_status,
    500,
  )
})

Deno.test('one failing hook does not stop the next one', async () => {
  const { handler, calls } = handlerWith(
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

  const response = await handler(insert('fuel_entries', { vehicle_id: 'v1' }))

  assertEquals(await response.json(), { delivered: 1 })
  assertEquals(calls.length, 2)
})
