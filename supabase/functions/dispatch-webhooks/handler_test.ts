import { assertEquals } from 'jsr:@std/assert@1'
import { makeHandler } from './handler.ts'
import { sign } from '../_shared/webhooks.ts'
import { fakeClient, stubEnv } from '../_test/fake_supabase.ts'
import { type Row, table } from '../_test/tables.ts'

// The dispatcher is a poke: any POST runs one pass of the drain over the
// outbox, and nothing in the request is read. The tests of what each event
// says are in `events_test.ts`; of how rows are queued, posted, retried and
// given up on, in `_shared/outbox_test.ts`. What is left to check here is
// that a poke drains, whatever it carries, and answers with the count.
//
// The tests that used to live here exercised the read-back trust model: a
// request named a row and the handler believed nothing else about it, reading
// the row from its table with the service-role client. The outbox replaces
// that model (decision 183): a request carries nothing at all, and the rows
// the drain reads were written by triggers, as service role, from the tables
// the changes were made to. There is no payload left to forge.

stubEnv()

const AT = new Date('2026-09-19T10:00:00.000Z')

interface Call {
  url: string
  headers: Record<string, string>
  body: string
}

const hook = {
  id: 'w1',
  household_id: 'h1',
  url: 'https://home.example/hook',
  secret: 's3cret',
  events: ['entry.created'],
  format: 'auto',
  vehicle_ids: null,
  language: 'en',
  active: true,
}

const fillUp = { id: 'f1', vehicle_id: 'v1', volume_l: 40, created_by: 'u1' }

/// A fill-up's outbox row, as `dispatch_entry_webhook` writes it.
const pendingFillUp: Row = {
  id: 'o1',
  household_id: 'h1',
  event: 'entry.created',
  payload: {
    table: 'fuel_entries',
    op: 'INSERT',
    vehicle_id: 'v1',
    record: fillUp,
    old_record: null,
  },
  created_at: AT.toISOString(),
  processed_at: null,
}

/// A handler over a garage with one hook and whatever is in the outbox, wired
/// to a recording fetch so a delivery can be inspected without a server on
/// the other end.
function handlerWith(outbox: Row[]) {
  const deliveries: Row[] = []
  let ids = 0
  const client = fakeClient({
    tables: {
      // Copied: the drain marks a row processed in place.
      webhook_outbox: table(outbox.map((row) => ({ ...row }))),
      webhooks: table([hook]),
      webhook_deliveries: table(deliveries, () => ({
        id: `d${++ids}`,
        attempts: 0,
        next_attempt_at: AT.toISOString(),
        last_status: null,
        delivered_at: null,
        given_up_at: null,
        created_at: AT.toISOString(),
      }), {
        unique: ['outbox_id', 'webhook_id'],
        joins: { webhooks: () => hook },
      }),
      vehicles: [{ id: 'v1', household_id: 'h1', nickname: 'Clio' }],
      households: [{ id: 'h1', currency_code: 'EUR' }],
      profiles: [{ user_id: 'u1', display_name: 'Ana' }],
    },
  })
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
      return Promise.resolve(new Response('', { status: 200 }))
    }) as unknown as typeof fetch,
  })
  return { handler, client, calls, deliveries }
}

const poke = (body?: string) =>
  new Request('http://localhost/dispatch-webhooks', { method: 'POST', body })

Deno.test('only POST is accepted', async () => {
  const { handler } = handlerWith([pendingFillUp])

  const response = await handler(
    new Request('http://localhost/dispatch-webhooks', { method: 'GET' }),
  )

  assertEquals(response.status, 405)
})

Deno.test('an empty poke drains what is in the outbox', async () => {
  const { handler, calls, deliveries } = handlerWith([pendingFillUp])

  const response = await handler(poke())

  assertEquals(response.status, 200)
  assertEquals(await response.json(), { queued: 1, delivered: 1, failed: 0 })
  assertEquals(calls.length, 1)
  assertEquals(calls[0].url, hook.url)
  assertEquals(calls[0].headers['X-Garage-Event'], 'entry.created')
  assertEquals(calls[0].headers['X-Garage-Delivery'], 'd1')
  assertEquals(
    calls[0].headers['X-Garage-Signature'],
    await sign(hook.secret, calls[0].body),
  )
  const sent = JSON.parse(calls[0].body)
  assertEquals(sent.event, 'entry.created')
  assertEquals(sent.kind, 'fuel')
  assertEquals(sent.vehicle_name, 'Clio')
  assertEquals(sent.entry, fillUp)
  assertEquals(deliveries[0].delivered_at, AT.toISOString())
})

// The triggers used to post the row itself here, and a trigger written before
// the outbox may still be doing so somewhere. It is a poke like any other:
// nothing in it is read, so nothing in it is believed.
Deno.test('the old database-webhook payload is a poke, and is not read', async () => {
  const { handler, calls } = handlerWith([pendingFillUp])

  const response = await handler(poke(JSON.stringify({
    type: 'INSERT',
    table: 'cost_entries',
    record: {
      id: 'forged',
      vehicle_id: 'v1',
      amount: 1,
      notes: 'Pay at https://evil.example',
    },
    old_record: null,
  })))

  assertEquals(await response.json(), { queued: 1, delivered: 1, failed: 0 })
  assertEquals(calls.length, 1, 'the row in the outbox, and nothing else')
  assertEquals(JSON.parse(calls[0].body).entry.id, 'f1')
  assertEquals(calls[0].body.includes('evil'), false)
})

Deno.test('a poke with nothing due answers with zeros', async () => {
  const { handler, calls } = handlerWith([])

  const response = await handler(poke('{}'))

  assertEquals(await response.json(), { queued: 0, delivered: 0, failed: 0 })
  assertEquals(calls, [])
})

Deno.test('a poke that is not even JSON still drains', async () => {
  const { handler, calls } = handlerWith([pendingFillUp])

  const response = await handler(poke('not json'))

  assertEquals(response.status, 200)
  assertEquals(calls.length, 1)
})
