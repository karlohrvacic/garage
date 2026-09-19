import { assertEquals, assertStringIncludes } from 'jsr:@std/assert@1'
import { fakeClient, type RecordedQuery } from '../_test/fake_supabase.ts'
import { type Row, table } from '../_test/tables.ts'
import { drain, subscribed } from './outbox.ts'
import type { Hook } from './webhooks.ts'

const AT = new Date('2026-09-19T10:00:00.000Z')

const later = (ms: number) => new Date(AT.getTime() + ms)
const MINUTE = 60_000

const hook = (extra: Partial<Hook> = {}): Hook => ({
  id: 'w1',
  url: 'https://home.example/hook',
  secret: 's3cret',
  events: ['entry.created'],
  format: 'auto',
  vehicle_ids: null,
  language: 'en',
  active: true,
  ...extra,
})

Deno.test('a hook is subscribed by event and by car', () => {
  assertEquals(subscribed(hook(), 'entry.created', 'v1'), true)
  assertEquals(subscribed(hook(), 'member.left', 'v1'), false)
  assertEquals(
    subscribed(hook({ vehicle_ids: ['v2'] }), 'entry.created', 'v1'),
    false,
  )
  assertEquals(
    subscribed(hook({ vehicle_ids: ['v1'] }), 'entry.created', 'v1'),
    true,
  )
  assertEquals(
    subscribed(
      hook({ events: ['member.joined'], vehicle_ids: ['v2'] }),
      'member.joined',
      null,
    ),
    true,
    'a garage event has no car to filter on',
  )
  assertEquals(
    subscribed(
      hook({ events: ['reminder.due'], vehicle_ids: ['v2'] }),
      'test.ping',
      'v1',
    ),
    true,
    'the test button reaches every hook, whatever it listens for',
  )
  assertEquals(
    subscribed(hook({ active: false }), 'test.ping', null),
    false,
    'but not one that is switched off',
  )
})

interface Faults {
  /// How many writes to the deliveries table fail first, the way a
  /// connection dropped mid-request does.
  writes?: number
  /// How many reads of the hooks table fail first.
  hookReads?: number
}

/// A database with the outbox rows and hooks given, and a deliveries table
/// that remembers what was inserted and updated.
function world(hooks: Hook[], outbox: Row[], faults: Faults = {}) {
  const deliveries: Row[] = []
  const hookRows = hooks.map((h) => ({ ...h, household_id: 'h1' }))
  let ids = 0
  let refusedWrites = faults.writes ?? 0
  let refusedHookReads = faults.hookReads ?? 0
  const hooksTable = table(hookRows)
  const deliveriesTable = table(deliveries, () => ({
    id: `d${++ids}`,
    attempts: 0,
    next_attempt_at: AT.toISOString(),
    last_status: null,
    delivered_at: null,
    given_up_at: null,
    created_at: AT.toISOString(),
  }), {
    unique: ['outbox_id', 'webhook_id'],
    joins: { webhooks: (row) => hookRows.find((h) => h.id === row.webhook_id) },
  })
  const admin = fakeClient({
    tables: {
      webhook_outbox: table(outbox),
      webhooks: (query: RecordedQuery) => {
        if (query.operation === 'select' && refusedHookReads > 0) {
          refusedHookReads -= 1
          return { error: { message: 'connection reset' } }
        }
        return hooksTable(query)
      },
      webhook_deliveries: (query: RecordedQuery) => {
        if (query.operation === 'upsert' && refusedWrites > 0) {
          refusedWrites -= 1
          return { error: { message: 'connection reset' } }
        }
        return deliveriesTable(query)
      },
    },
  })
  return { admin, deliveries }
}

const builders = {
  'entry.created': () =>
    Promise.resolve({
      body: '{"event":"entry.created"}',
      message: (language: string) => `hello ${language}`,
    }),
}

type Call = { url: string; headers: Record<string, string>; body: string }

function calling(respond: (url: string) => Response) {
  const calls: Call[] = []
  const fetch = ((url: string, init: RequestInit) => {
    calls.push({
      url,
      headers: init.headers as Record<string, string>,
      body: init.body as string,
    })
    return Promise.resolve(respond(url))
  }) as unknown as typeof globalThis.fetch
  return { calls, fetch }
}

/// What a home server that is off looks like from here: the fetch rejects,
/// and there is no status to record but 0.
const unreachable = (): Response => {
  throw new TypeError('connection refused')
}

const pending = (payload: Row = { vehicle_id: 'v1' }): Row[] => [{
  id: 'o1',
  household_id: 'h1',
  event: 'entry.created',
  payload,
  created_at: AT.toISOString(),
  processed_at: null,
}]

/// [count] events, queued in one go.
const burst = (count: number): Row[] =>
  Array.from({ length: count }, (_, i) => ({
    ...pending()[0],
    id: `o${i}`,
  }))

/// A delivery row as the database would hold it, for a table seeded
/// directly rather than through the outbox.
const queued = (id: string, webhookId: string): Row => ({
  id,
  outbox_id: `o-${id}`,
  webhook_id: webhookId,
  household_id: 'h1',
  event: 'entry.created',
  body: '{}',
  message: 'hello',
  attempts: 0,
  next_attempt_at: AT.toISOString(),
  last_status: null,
  delivered_at: null,
  given_up_at: null,
  created_at: AT.toISOString(),
})

const pauses = (admin: ReturnType<typeof fakeClient>) =>
  admin.queries.filter((q) =>
    q.table === 'webhooks' && q.operation === 'update' &&
    (q.payload as { active?: boolean }).active === false
  )

const deliveryUpdates = (admin: ReturnType<typeof fakeClient>) =>
  admin.queries.filter((q) =>
    q.table === 'webhook_deliveries' && q.operation === 'update'
  )

const outboxUpdates = (admin: ReturnType<typeof fakeClient>) =>
  admin.queries.filter((q) =>
    q.table === 'webhook_outbox' && q.operation === 'update'
  )

const hookRecords = (admin: ReturnType<typeof fakeClient>) =>
  admin.queries
    .filter((q) =>
      q.table === 'webhooks' && q.operation === 'update' &&
      'last_delivery_status' in (q.payload as Row)
    )
    .map((q): Row => ({
      hook: q.filters.find((f) => f.method === 'eq')?.args[1],
      ...(q.payload as Row),
    }))

Deno.test('an outbox row becomes one delivery per subscribed hook, then is posted', async () => {
  const { admin, deliveries } = world(
    [hook(), hook({ id: 'w2', events: ['reminder.due'] })],
    pending(),
  )
  const { calls, fetch } = calling(() => new Response('', { status: 200 }))

  const report = await drain(admin, { admin, fetch, now: () => AT }, builders)

  assertEquals(report, { queued: 1, delivered: 1, failed: 0 })
  assertEquals(deliveries.length, 1)
  assertEquals(deliveries[0].webhook_id, 'w1')
  assertEquals(deliveries[0].message, 'hello en')
  assertEquals(calls.length, 1)
  assertEquals(calls[0].headers['X-Garage-Delivery'], 'd1')
  assertEquals(deliveries[0].delivered_at, AT.toISOString())
  assertEquals(deliveries[0].attempts, 1)
  assertEquals(
    hookRecords(admin),
    [{
      hook: 'w1',
      last_delivery_at: AT.toISOString(),
      last_delivery_status: 200,
    }],
    'the hook says when it was last called and what came back',
  )
})

// A sale writes the car returned and then handed over in one transaction, and
// the receiver must hear them in that order. And a poke and the cron can drain
// at once: both read the row before either marks it, so the write has to be
// one the second of them can make without a second delivery.
Deno.test('the queue reads oldest first and writes what a racing drain cannot double', async () => {
  const { admin } = world([hook()], pending())
  const { fetch } = calling(() => new Response('', { status: 200 }))

  await drain(admin, { admin, fetch, now: () => AT }, builders)

  const read = admin.queries.find((q) =>
    q.table === 'webhook_outbox' && q.operation === 'select'
  )
  assertEquals(
    read?.filters.find((f) => f.method === 'order')?.args,
    ['created_at', { ascending: true }],
  )
  const write = admin.queries.find((q) => q.table === 'webhook_deliveries')
  assertEquals(write?.operation, 'upsert')
  assertEquals(write?.options, {
    onConflict: 'outbox_id,webhook_id',
    ignoreDuplicates: true,
  })
})

Deno.test('a deliveries write that fails leaves the event for the next drain', async () => {
  const { admin, deliveries } = world([hook()], pending(), { writes: 1 })
  const { fetch } = calling(() => new Response('', { status: 200 }))
  const deps = { admin, fetch, now: () => AT }

  const first = await drain(admin, deps, builders)

  assertEquals(first.queued, 0)
  assertEquals(deliveries.length, 0)
  assertEquals(outboxUpdates(admin), [], 'not marked processed, so not lost')

  const second = await drain(admin, deps, builders)

  assertEquals(second, { queued: 1, delivered: 1, failed: 0 })
  assertEquals(deliveries.length, 1)
})

Deno.test('a hooks read that fails leaves the event for the next drain', async () => {
  const { admin, deliveries } = world([hook()], pending(), { hookReads: 1 })
  const { fetch } = calling(() => new Response('', { status: 200 }))
  const deps = { admin, fetch, now: () => AT }

  const first = await drain(admin, deps, builders)

  assertEquals(first.queued, 0)
  assertEquals(deliveries.length, 0, 'unread is not unsubscribed')
  assertEquals(outboxUpdates(admin), [])

  const second = await drain(admin, deps, builders)

  assertEquals(second, { queued: 1, delivered: 1, failed: 0 })
})

/// Runs [body] with `console.error` captured, and hands it what was logged.
async function logging(
  body: (logged: unknown[][]) => Promise<void>,
): Promise<void> {
  const logged: unknown[][] = []
  const original = console.error
  console.error = (...args: unknown[]) => {
    logged.push(args)
  }
  try {
    await body(logged)
  } finally {
    console.error = original
  }
}

// A builder reads the car, the garage and the author, and any of those reads
// can fail; the text it writes can throw too. Either way the row waits for
// the next drain, and the rows behind it, other households' among them, do
// not wait with it.
const brokenBuilders = {
  'a builder that fails': () => Promise.reject(new Error('vehicles: timeout')),
  'a message that cannot be written': () =>
    Promise.resolve({
      body: '{}',
      message: (): string => {
        throw new RangeError('no such language')
      },
    }),
}

for (const [how, broken] of Object.entries(brokenBuilders)) {
  Deno.test(`${how} is logged, and the row behind it still queues`, async () => {
    const { admin, deliveries } = world(
      [hook({ events: ['entry.created', 'entry.updated'] })],
      [
        { ...pending()[0], id: 'o1', event: 'entry.updated' },
        { ...pending()[0], id: 'o2', event: 'entry.created' },
      ],
    )
    const { fetch } = calling(() => new Response('', { status: 200 }))
    const failing = { ...builders, 'entry.updated': broken }

    await logging(async (logged) => {
      const report = await drain(
        admin,
        { admin, fetch, now: () => AT },
        failing,
      )

      assertEquals(report, { queued: 1, delivered: 1, failed: 0 })
      assertEquals(deliveries.length, 1)
      assertEquals(deliveries[0].outbox_id, 'o2')
      assertEquals(
        outboxUpdates(admin).map((q) =>
          q.filters.find((f) => f.method === 'eq')?.args[1]
        ),
        ['o2'],
        'the row that could not be built waits for the next drain',
      )
      assertEquals(logged.length, 1)
      assertStringIncludes(String(logged[0][0]), 'o1')
    })
  })
}

Deno.test("the message is written in the hook's language", async () => {
  const { admin, deliveries } = world([hook({ language: 'hr' })], pending())
  const { fetch } = calling(() => new Response('', { status: 200 }))

  await drain(admin, { admin, fetch, now: () => AT }, builders)

  assertEquals(deliveries[0].message, 'hello hr')
})

Deno.test('a failure is retried a minute later, then ten, then sixty, then given up', async () => {
  const { admin, deliveries } = world([hook()], pending())
  const { calls, fetch } = calling(() => new Response('', { status: 503 }))
  let now = AT
  const deps = { admin, fetch, now: () => now }

  await drain(admin, deps, builders)
  assertEquals(deliveries[0].attempts, 1)
  assertEquals(deliveries[0].next_attempt_at, later(MINUTE).toISOString())
  assertEquals(deliveries[0].last_status, 503)
  assertEquals(hookRecords(admin)[0].last_delivery_status, 503)

  now = later(MINUTE / 2)
  await drain(admin, deps, builders)
  assertEquals(calls.length, 1, 'not due yet')

  // Each wait is counted from the attempt that failed, not from the first.
  now = later(MINUTE)
  await drain(admin, deps, builders)
  assertEquals(
    deliveries[0].next_attempt_at,
    later(MINUTE + 10 * MINUTE).toISOString(),
  )
  now = later(11 * MINUTE)
  await drain(admin, deps, builders)
  assertEquals(
    deliveries[0].next_attempt_at,
    later(11 * MINUTE + 60 * MINUTE).toISOString(),
  )
  now = later(71 * MINUTE)
  await drain(admin, deps, builders)
  assertEquals(deliveries[0].attempts, 4)
  assertEquals(deliveries[0].given_up_at, now.toISOString())
  assertEquals(calls.length, 4)

  now = later(24 * 60 * MINUTE)
  await drain(admin, deps, builders)
  assertEquals(calls.length, 4, 'given up means given up')
})

Deno.test('a retry sends the same bytes under the same delivery id', async () => {
  const { admin } = world([hook()], pending())
  let status = 503
  const { calls, fetch } = calling(() => new Response('', { status }))
  let now = AT
  const deps = { admin, fetch, now: () => now }

  await drain(admin, deps, builders)
  status = 200
  now = later(MINUTE)
  await drain(admin, deps, builders)

  assertEquals(calls.length, 2)
  assertEquals(calls[0].body, calls[1].body)
  assertEquals(
    calls[0].headers['X-Garage-Signature'],
    calls[1].headers['X-Garage-Signature'],
  )
  assertEquals(
    calls[0].headers['X-Garage-Delivery'],
    calls[1].headers['X-Garage-Delivery'],
  )
})

// A drain can die between the post and the record of it — the platform's
// wall clock, a crash. Written before the post, the attempt is spent either
// way, so a receiver that is up but slow is not called five times for four.
Deno.test('a delivery is claimed, with its next wait, before it is posted', async () => {
  const { admin, deliveries } = world([hook()], pending())
  let seen: Row | undefined
  let updatesBefore = -1
  const fetch = (() => {
    seen = { ...deliveries[0] }
    updatesBefore = deliveryUpdates(admin).length
    return Promise.resolve(new Response('', { status: 200 }))
  }) as unknown as typeof globalThis.fetch

  await drain(admin, { admin, fetch, now: () => AT }, builders)

  assertEquals(seen?.attempts, 1)
  assertEquals(seen?.next_attempt_at, later(MINUTE).toISOString())
  assertEquals(seen?.delivered_at, null)
  assertEquals(updatesBefore, 1, 'the claim, and nothing else yet')
  const claim = deliveryUpdates(admin)[0]
  assertEquals(
    claim.filters.filter((f) => f.method === 'eq').map((f) => f.args),
    [['id', 'd1'], ['attempts', 0]],
    'claimed only from the state it was read in',
  )
  assertEquals(deliveries[0].delivered_at, AT.toISOString())
  assertEquals(deliveries[0].given_up_at, null)
})

// A batch is read at one moment and posted over the next many seconds, ten
// per receiver that is slow. Stamped with the moment the batch was read, the
// last row's delivery would read as earlier than it was, and its wait would
// be counted from before its attempt.
Deno.test('the clock is read per row, not once for the batch', async () => {
  const { admin, deliveries } = world([hook()], [])
  deliveries.push(queued('d1', 'w1'), queued('d2', 'w1'))
  // A second passes at every look.
  let looks = 0
  let lastLook = AT
  const now = () => {
    lastLook = later(looks++ * 1000)
    return lastLook
  }
  const claimedAt: Date[] = []
  const fetch = (() => {
    claimedAt.push(lastLook)
    return Promise.resolve(new Response('', { status: 503 }))
  }) as unknown as typeof globalThis.fetch

  await drain(admin, { admin, fetch, now }, builders)

  assertEquals(claimedAt.length, 2)
  assertEquals(claimedAt[1] > claimedAt[0], true)
  for (const [i, claimed] of claimedAt.entries()) {
    assertEquals(
      deliveries[i].next_attempt_at,
      new Date(claimed.getTime() + MINUTE).toISOString(),
      `a minute from its own claim, row ${i + 1}`,
    )
  }
  const stamped = hookRecords(admin).map((r) => r.last_delivery_at as string)
  assertEquals(stamped[0] > claimedAt[0].toISOString(), true, 'after the post')
  assertEquals(stamped[1] > stamped[0], true, 'and later for the later row')
})

Deno.test('the fourth attempt is given up on when claimed, and taken back if it lands', async () => {
  const { admin, deliveries } = world([hook()], pending())
  let status = 503
  let seen: Row | undefined
  const fetch = (() => {
    seen = { ...deliveries[0] }
    return Promise.resolve(new Response('', { status }))
  }) as unknown as typeof globalThis.fetch
  let now = AT
  const deps = { admin, fetch, now: () => now }

  for (const round of [0, MINUTE, 11 * MINUTE]) {
    now = later(round)
    await drain(admin, deps, builders)
  }
  status = 200
  now = later(71 * MINUTE)
  await drain(admin, deps, builders)

  assertEquals(seen?.attempts, 4)
  assertEquals(seen?.given_up_at, now.toISOString(), 'given up before the post')
  assertEquals(deliveries[0].given_up_at, null, 'and not after it landed')
  assertEquals(deliveries[0].delivered_at, now.toISOString())
})

Deno.test('two drains at once post a delivery once', async () => {
  const { admin, deliveries } = world([hook()], pending())
  const { calls, fetch } = calling(() => new Response('', { status: 200 }))
  const deps = { admin, fetch, now: () => AT }

  // A poke and the cron, in flight together.
  const [a, b] = await Promise.all([
    drain(admin, deps, builders),
    drain(admin, deps, builders),
  ])

  assertEquals(deliveries.length, 1, 'the index keeps the queue to one row')
  assertEquals(calls.length, 1, 'and the claim keeps the post to one')
  assertEquals(a.delivered + b.delivered, 1)
  assertEquals(deliveries[0].attempts, 1)
})

/// Every retry a delivery gets: the drains at which the first attempt and the
/// three retries fall due.
const ROUNDS = [0, MINUTE, 11 * MINUTE, 71 * MINUTE]

Deno.test('a hook whose last twenty deliveries were given up on is paused', async () => {
  const { admin, deliveries } = world([hook()], burst(20))
  const { fetch } = calling(() => new Response('', { status: 503 }))
  let now = AT
  const deps = { admin, fetch, now: () => now }

  for (const round of ROUNDS.slice(0, -1)) {
    now = later(round)
    await drain(admin, deps, builders)
    assertEquals(pauses(admin), [], 'still retrying, so not yet dead')
  }
  now = later(ROUNDS[3])
  await drain(admin, deps, builders)

  assertEquals(
    deliveries.every((d) => d.given_up_at === now.toISOString()),
    true,
  )
  const paused = pauses(admin)
  assertEquals(paused.length, 1)
  assertEquals((paused[0].payload as Row).paused_reason, 'failing')
  const pausedAt = admin.queries.indexOf(paused[0])
  const givenUpBefore = admin.queries.slice(0, pausedAt).filter((q) =>
    q.table === 'webhook_deliveries' && q.operation === 'update' &&
    typeof (q.payload as Row).given_up_at === 'string'
  )
  assertEquals(
    givenUpBefore.length,
    20,
    'the twentieth given-up delivery trips the pause, not the first',
  )
})

Deno.test('nineteen given up on are not yet a dead hook', async () => {
  const { admin, deliveries } = world([hook()], burst(19))
  const { fetch } = calling(() => new Response('', { status: 503 }))
  let now = AT
  const deps = { admin, fetch, now: () => now }

  for (const round of ROUNDS) {
    now = later(round)
    await drain(admin, deps, builders)
  }

  assertEquals(deliveries.every((d) => d.given_up_at !== null), true)
  assertEquals(pauses(admin), [])
})

// The reason it is given-up deliveries that count and not failed attempts: an
// import writes a hundred entries in a minute, and the home server that
// receives them may be rebooting at the time.
Deno.test('a receiver that is down for a minute is retried, not paused', async () => {
  const { admin, deliveries } = world([hook()], burst(20))
  let status = 503
  const { fetch } = calling(() => new Response('', { status }))
  let now = AT
  const deps = { admin, fetch, now: () => now }

  await drain(admin, deps, builders)
  status = 200
  now = later(MINUTE)
  const report = await drain(admin, deps, builders)

  assertEquals(report, { queued: 0, delivered: 20, failed: 0 })
  assertEquals(deliveries.every((d) => d.delivered_at !== null), true)
  assertEquals(pauses(admin), [])
})

Deno.test('a receiver that is off costs one timeout per drain', async () => {
  const { admin, deliveries } = world([hook()], burst(2))
  const { calls, fetch } = calling(unreachable)
  let now = AT
  const deps = { admin, fetch, now: () => now }

  const report = await drain(admin, deps, builders)

  assertEquals(calls.length, 1)
  assertEquals(report, { queued: 2, delivered: 0, failed: 1 })
  assertEquals(deliveries[0].attempts, 1)
  assertEquals(
    deliveries[0].last_status,
    0,
    'a receiver that cannot be reached is recorded as 0',
  )
  assertEquals(deliveries[0].next_attempt_at, later(MINUTE).toISOString())
  assertEquals(deliveries[1].attempts, 0, 'no attempt spent on the other')
  assertEquals(deliveries[1].last_status, null)
  assertEquals(
    deliveries[1].next_attempt_at,
    later(MINUTE).toISOString(),
    'but it waits with the one that failed',
  )

  now = later(MINUTE)
  await drain(admin, deps, builders)
  assertEquals(calls.length, 2, 'one more, the next time round')
  assertEquals(deliveries[0].next_attempt_at, later(11 * MINUTE).toISOString())
  assertEquals(
    deliveries[1].next_attempt_at,
    later(11 * MINUTE).toISOString(),
    'as long as the failed row waits: a flat minute would have the backlog due at every cron drain',
  )
})

Deno.test('a dead hook does not hold up a live one', async () => {
  const live = hook({ id: 'w2', url: 'https://up.example/hook' })
  const { admin, deliveries } = world([hook(), live], [])
  deliveries.push(
    queued('dead-1', 'w1'),
    queued('dead-2', 'w1'),
    queued('dead-3', 'w1'),
    queued('live-1', 'w2'),
  )
  const { calls, fetch } = calling((url) =>
    url === live.url ? new Response('', { status: 200 }) : unreachable()
  )

  const report = await drain(admin, { admin, fetch, now: () => AT }, builders)

  assertEquals(report, { queued: 0, delivered: 1, failed: 1 })
  assertEquals(
    calls.map((c) => c.url),
    [hook().url, live.url],
    'one timeout for the dead one, and the live one is not behind it',
  )
  assertEquals(deliveries[3].delivered_at, AT.toISOString())
  assertEquals(deliveries[1].next_attempt_at, later(MINUTE).toISOString())
  assertEquals(deliveries[2].next_attempt_at, later(MINUTE).toISOString())
  assertEquals(deliveries[1].attempts, 0)
  assertEquals(deliveries[2].attempts, 0)
  const deferrals = deliveryUpdates(admin).filter((q) =>
    q.filters.some((f) => f.method === 'eq' && f.args[0] === 'webhook_id')
  )
  assertEquals(deferrals.length, 1, 'pushed back in one write')
  assertEquals(deferrals[0].payload, {
    next_attempt_at: later(MINUTE).toISOString(),
  })
  assertEquals(
    deferrals[0].filters.map((f) => [f.method, ...f.args]),
    [
      ['eq', 'webhook_id', 'w1'],
      ['is', 'delivered_at', null],
      ['is', 'given_up_at', null],
      ['lte', 'next_attempt_at', AT.toISOString()],
    ],
  )
})

// `postDelivery` guards the fetch and nothing before it: a secret that cannot
// key an HMAC — a member can save an empty one — throws in `sign`. Left to
// propagate, one such hook would end every drain for every household, four
// times over, once its row was claimed and due.
Deno.test('a hook whose secret cannot sign does not cost the others their drain', async () => {
  const other = hook({ id: 'w2', url: 'https://up.example/hook' })
  const { admin, deliveries } = world([hook({ secret: '' }), other], pending())
  const { calls, fetch } = calling(() => new Response('', { status: 200 }))

  await logging(async (logged) => {
    const report = await drain(admin, { admin, fetch, now: () => AT }, builders)

    assertEquals(report, { queued: 2, delivered: 1, failed: 1 })
    assertEquals(calls.map((c) => c.url), [other.url], 'the other still goes')
    assertEquals(deliveries[0].webhook_id, 'w1')
    assertEquals(deliveries[0].attempts, 1, 'a failed attempt, recorded')
    assertEquals(deliveries[0].last_status, 0)
    assertEquals(deliveries[0].next_attempt_at, later(MINUTE).toISOString())
    assertEquals(deliveries[1].delivered_at, AT.toISOString())
    assertEquals(
      hookRecords(admin).map((r) => [r.hook, r.last_delivery_status]),
      [['w1', 0], ['w2', 200]],
    )
    assertEquals(logged.length, 1)
    assertStringIncludes(String(logged[0][0]), 'd1')
  })
})

Deno.test('a paused hook is queued nothing', async () => {
  const { admin, deliveries } = world([hook({ active: false })], pending())
  const { fetch } = calling(() => new Response('', { status: 200 }))

  await drain(admin, { admin, fetch, now: () => AT }, builders)

  assertEquals(deliveries.length, 0)
})

Deno.test("a paused hook's due rows are not read, and wait for it", async () => {
  const { admin, deliveries } = world([hook()], pending())
  const { calls, fetch } = calling(() => new Response('', { status: 200 }))
  const deps = { admin, fetch, now: () => AT }

  await drain(admin, deps, builders)
  assertEquals(calls.length, 1)

  // A second event, queued and then not posted because a member paused the
  // hook in between.
  deliveries.push(queued('d-late', 'w1'))
  await admin.from('webhooks').update({ active: false }).eq('id', 'w1')
  const before = admin.queries.length
  await drain(admin, deps, builders)
  assertEquals(calls.length, 1, 'nothing is posted to a paused hook')
  assertEquals(deliveries[1].attempts, 0, 'and the row is left as it was')
  const due = admin.queries
    .slice(before)
    .find((q) => q.table === 'webhook_deliveries' && q.operation === 'select')
  assertStringIncludes(due?.select ?? '', 'webhooks!inner(active)')
  assertEquals(
    due?.filters.find((f) => f.args[0] === 'webhooks.active'),
    { method: 'eq', args: ['webhooks.active', true] },
    'left out of the batch rather than read and skipped',
  )
  assertEquals(
    admin.queries.slice(before).filter((q) =>
      q.table === 'webhooks' && q.operation === 'select'
    ),
    [],
    'so the hook is not even looked up',
  )

  await admin.from('webhooks').update({ active: true }).eq('id', 'w1')
  await drain(admin, deps, builders)
  assertEquals(calls.length, 2, 'resumed, it gets what was waiting')
})

Deno.test('an event no builder knows is processed and delivers nothing', async () => {
  const { admin, deliveries } = world(
    [hook({ events: ['nonsense.event'] })],
    [{ ...pending()[0], event: 'nonsense.event' }],
  )
  const { fetch } = calling(() => new Response('', { status: 200 }))

  const report = await drain(admin, { admin, fetch, now: () => AT }, builders)

  assertEquals(report.queued, 0)
  assertEquals(deliveries.length, 0)
  const processed = admin.queries.find((q) =>
    q.table === 'webhook_outbox' && q.operation === 'update'
  )
  assertEquals(
    (processed?.payload as { processed_at: string }).processed_at,
    AT.toISOString(),
  )
})
