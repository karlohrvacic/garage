import { assertEquals } from 'jsr:@std/assert@1'
import { fakeClient } from '../_test/fake_supabase.ts'
import { deliver, type Hook, sign } from './webhooks.ts'

const AT = new Date('2026-08-17T10:00:00.000Z')

const BODY = '{"event":"test.event","vehicle_id":"v1"}'
const MESSAGE = '🔔 Something · Clio'

const generic: Hook = {
  id: 'w1',
  url: 'https://home.example/hook',
  secret: 's3cret',
  events: ['test.event'],
}

const discord: Hook = {
  id: 'w2',
  url: 'https://discord.com/api/webhooks/1/a',
  secret: 'another',
  events: ['test.event'],
  format: 'auto',
}

interface Call {
  url: string
  init: RequestInit
  headers: Record<string, string>
}

/// Delivery wired to a recording fetch and the shared fake, so what went over
/// the wire and what was written back can both be looked at.
function deliveryWith(
  respond: (url: string) => Response | Promise<Response> = () =>
    new Response('', { status: 200 }),
) {
  const admin = fakeClient()
  const calls: Call[] = []
  const deps = {
    admin,
    now: () => AT,
    fetch: ((url: string, init: RequestInit) => {
      calls.push({
        url,
        init,
        headers: init.headers as Record<string, string>,
      })
      return Promise.resolve(respond(url))
    }) as unknown as typeof fetch,
  }
  return { deps, admin, calls }
}

const recorded = (admin: ReturnType<typeof fakeClient>) =>
  admin.queries
    .filter((query) => query.operation === 'update')
    .map((query) => ({
      table: query.table,
      hook: query.filters.find((filter) => filter.method === 'eq')?.args,
      payload: query.payload,
    }))
    .sort((a, b) => String(a.hook).localeCompare(String(b.hook)))

// RFC 4231, test case 2, which is also what the snippet in the public docs
// prints: `hmac.new(b"Jefe", body, hashlib.sha256).hexdigest()`. A receiver
// verifies with its own library, so the only signature worth sending is the
// one every library agrees on.
Deno.test('the signature is the HMAC-SHA256 a receiver computes, in hex', async () => {
  assertEquals(
    await sign('Jefe', 'what do ya want for nothing?'),
    '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
  )
})

Deno.test('each hook is posted once, told the event, and signed', async () => {
  const { deps, calls } = deliveryWith()

  const delivered = await deliver(
    deps,
    'test.event',
    [generic, discord],
    BODY,
    MESSAGE,
  )

  assertEquals(delivered, 2)
  assertEquals(
    calls.map((call) => call.url),
    [generic.url, discord.url],
    'one attempt each, in the order they were given',
  )
  for (const call of calls) {
    assertEquals(call.init.method, 'POST')
    assertEquals(call.headers['X-Garage-Event'], 'test.event')
    assertEquals(call.init.signal instanceof AbortSignal, true)
  }
  assertEquals(
    calls[0].headers['X-Garage-Signature'],
    await sign('s3cret', BODY),
  )
})

// A chat service ignores the header, and a receiver that checks it is by
// definition a generic one — so what is signed is always the generic body,
// whatever this particular hook was sent.
Deno.test('a chat service gets its own shape, under the generic signature', async () => {
  const { deps, calls } = deliveryWith()

  await deliver(deps, 'test.event', [generic, discord], BODY, MESSAGE)

  assertEquals(calls[0].init.body, BODY)
  assertEquals(calls[0].headers['Content-Type'], 'application/json')
  assertEquals(JSON.parse(calls[1].init.body as string), {
    content: MESSAGE,
    allowed_mentions: { parse: [] },
    flags: 4,
  })
  assertEquals(
    calls[1].headers['X-Garage-Signature'],
    await sign('another', BODY),
  )
})

Deno.test('how each call went is written on its own hook', async () => {
  const { deps, admin } = deliveryWith((url) =>
    // A 204 may not carry a body, not even an empty one.
    url === generic.url
      ? new Response(null, { status: 204 })
      : new Response('', { status: 500 })
  )

  const delivered = await deliver(
    deps,
    'test.event',
    [generic, discord],
    BODY,
    MESSAGE,
  )

  assertEquals(delivered, 1, 'only an answer in the 200s is a delivery')
  assertEquals(recorded(admin), [
    {
      table: 'webhooks',
      hook: ['id', 'w1'],
      payload: {
        last_delivery_at: AT.toISOString(),
        last_delivery_status: 204,
      },
    },
    {
      table: 'webhooks',
      hook: ['id', 'w2'],
      payload: {
        last_delivery_at: AT.toISOString(),
        last_delivery_status: 500,
      },
    },
  ])
})

// Status 0 is what the app shows as "the last call did not get through".
Deno.test('a receiver that cannot be reached is recorded as 0, and the rest still go', async () => {
  const { deps, admin, calls } = deliveryWith((url) => {
    if (url === generic.url) throw new TypeError('connection refused')
    return new Response('', { status: 200 })
  })

  const delivered = await deliver(
    deps,
    'test.event',
    [generic, discord],
    BODY,
    MESSAGE,
  )

  assertEquals(delivered, 1)
  assertEquals(calls.length, 2, 'one attempt each, and no retry')
  assertEquals(
    recorded(admin).map((update) => update.payload),
    [
      { last_delivery_at: AT.toISOString(), last_delivery_status: 0 },
      { last_delivery_at: AT.toISOString(), last_delivery_status: 200 },
    ],
  )
})

// The daily reminder run calls every garage's hooks before it pushes. Called
// one after another, a handful of receivers that are switched off would hold
// the pushes up by ten seconds each.
Deno.test('a slow receiver does not hold up the next one', async () => {
  let secondCalled = () => {}
  const second = new Promise<void>((resolve) => secondCalled = resolve)
  const { deps } = deliveryWith(async (url) => {
    if (url === generic.url) {
      // Answers only once the next hook has been called. Sent one at a time,
      // it would wait forever, and Deno fails a test left waiting on nothing.
      await second
    } else {
      secondCalled()
    }
    return new Response('', { status: 200 })
  })

  assertEquals(
    await deliver(deps, 'test.event', [generic, discord], BODY, MESSAGE),
    2,
  )
})

Deno.test('nobody to call is nothing sent and nothing written', async () => {
  const { deps, admin, calls } = deliveryWith()

  assertEquals(await deliver(deps, 'test.event', [], BODY, MESSAGE), 0)
  assertEquals(calls, [])
  assertEquals(admin.queries, [])
})
