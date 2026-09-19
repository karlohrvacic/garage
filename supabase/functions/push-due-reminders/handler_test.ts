import { assertEquals } from 'jsr:@std/assert@1'
import {
  addMonths,
  bundleIntoVisits,
  dayDiff,
  furthestReading,
  isoDay,
  isServiceRole,
  makeHandler,
  REMINDER_LEAD_DAYS,
} from './handler.ts'
import {
  fakeClient,
  type RecordedQuery,
  stubEnv,
} from '../_test/fake_supabase.ts'
import { type Row, table } from '../_test/tables.ts'
import { sign } from '../_shared/webhooks.ts'

const SERVICE_KEY = 'service-key'
const TODAY = new Date('2026-08-17T10:00:00.000Z')

stubEnv({
  SUPABASE_SERVICE_ROLE_KEY: SERVICE_KEY,
  FCM_SERVICE_ACCOUNT: JSON.stringify({
    client_email: 'push@garage.iam.gserviceaccount.com',
    private_key: 'unused, the exchange is stubbed',
    project_id: 'garage-test',
  }),
})

/// A JWT with no signature worth the name. The gateway verifies the signature
/// before this code runs, so the function only reads the role out of it — and
/// that is exactly what these check.
function tokenFor(role: string): string {
  const payload = btoa(JSON.stringify({ role }))
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '')
  return `header.${payload}.signature`
}

interface Sent {
  url: string
  body: string
  headers: Record<string, string>
}

type Tables = NonNullable<
  NonNullable<Parameters<typeof fakeClient>[0]>['tables']
>

/// A handler over [tables], with the webhook outbox the run writes to and the
/// deliveries the drain writes from it, both starting empty and both
/// remembering what was written. Hooks given as rows are answered by filter,
/// as the drain asks for them: by garage, and by id.
function handlerWith(
  tables: Tables,
  respond: (url: string) => Response = () =>
    new Response('{}', { status: 200 }),
  now: Date = TODAY,
) {
  const outbox: Row[] = []
  const deliveries: Row[] = []
  const hooks = Array.isArray(tables.webhooks) ? tables.webhooks as Row[] : []
  let ids = 0
  const client = fakeClient({
    tables: {
      webhook_outbox: table(outbox, () => ({
        id: `o${++ids}`,
        created_at: now.toISOString(),
        processed_at: null,
      })),
      webhook_deliveries: table(deliveries, () => ({
        id: `d${++ids}`,
        attempts: 0,
        next_attempt_at: now.toISOString(),
        last_status: null,
        delivered_at: null,
        given_up_at: null,
        created_at: now.toISOString(),
      }), {
        unique: ['outbox_id', 'webhook_id'],
        joins: {
          webhooks: (row) => hooks.find((h) => h.id === row.webhook_id),
        },
      }),
      ...tables,
      ...(Array.isArray(tables.webhooks) && { webhooks: table(hooks) }),
    },
  })
  const sent: Sent[] = []
  /// Every exchange of the service account for an FCM token.
  const exchanges: string[] = []
  const handler = makeHandler({
    createClient: () => client,
    now: () => now,
    fcmAccessToken: (serviceAccount) => {
      exchanges.push(serviceAccount.client_email)
      return Promise.resolve('fcm-access-token')
    },
    fetch: ((url: string, init: RequestInit) => {
      sent.push({
        url,
        body: init.body as string,
        headers: init.headers as Record<string, string>,
      })
      return Promise.resolve(respond(url))
    }) as unknown as typeof fetch,
  })
  return { handler, client, sent, exchanges, outbox, deliveries }
}

const run = (authorization: string | null = tokenFor('service_role')) =>
  new Request('http://localhost/push-due-reminders', {
    method: 'POST',
    headers: authorization ? { Authorization: `Bearer ${authorization}` } : {},
  })

/// A dated one-off falling exactly [days] from TODAY.
function oneOffIn(days: number) {
  const date = new Date(TODAY)
  date.setUTCDate(date.getUTCDate() + days)
  return {
    id: `r-${days}`,
    vehicle_id: 'v1',
    service_type_key: 'service_registration',
    interval_km: null,
    interval_months: null,
    one_time: true,
    due_date: isoDay(date),
  }
}

const garage = {
  vehicles: [{ id: 'v1', nickname: 'Golf', household_id: 'h1' }],
  household_members: [{ household_id: 'h1', user_id: 'u1' }],
  device_tokens: [{ token: 'device-1', user_id: 'u1' }],
}

Deno.test('only a service-role caller may start a push run', () => {
  assertEquals(isServiceRole(`Bearer ${tokenFor('service_role')}`), true)
  assertEquals(
    isServiceRole(`Bearer ${tokenFor('anon')}`),
    false,
    'every copy of the app holds an anon token; it must not be able to make ' +
      'the project notify everybody',
  )
  assertEquals(isServiceRole(`Bearer ${tokenFor('authenticated')}`), false)
  assertEquals(isServiceRole(null), false)
  assertEquals(isServiceRole('Bearer not-a-jwt'), false)
  assertEquals(isServiceRole('Bearer a.!!!not-base64!!!.c'), false)
})

Deno.test('the injected service-role key is accepted as itself', () => {
  // Older projects inject a JWT here, newer ones an `sb_secret_…` string that
  // is not a JWT at all. Both have to work, which is why the value is compared
  // as well as decoded.
  assertEquals(isServiceRole(`Bearer ${SERVICE_KEY}`), true)
})

Deno.test('a calendar day is the day in UTC', () => {
  assertEquals(isoDay(new Date('2026-08-17T23:59:59.000Z')), '2026-08-17')
  assertEquals(isoDay(new Date('2026-08-17T00:00:00.000Z')), '2026-08-17')
})

Deno.test('a day difference counts calendar days, not elapsed hours', () => {
  const late = new Date('2026-08-17T23:00:00.000Z')
  const early = new Date('2026-08-18T01:00:00.000Z')

  assertEquals(
    dayDiff(late, early),
    1,
    'two hours apart, but a different day, and the schedule is about days',
  )
  assertEquals(dayDiff(TODAY, new Date('2026-09-16T00:00:00.000Z')), 30)
  assertEquals(dayDiff(TODAY, new Date('2026-08-10T00:00:00.000Z')), -7)
})

Deno.test('adding months lands on the same day of the month', () => {
  assertEquals(
    isoDay(addMonths(new Date('2026-01-15T00:00:00.000Z'), 6)),
    '2026-07-15',
  )
})

Deno.test('adding months to a day the target month lacks rolls forward', () => {
  // 31 January plus one month has no 31 February, and JavaScript answers
  // 3 March. Recorded rather than corrected: a service interval landing a
  // couple of days late is harmless, and this is what the code does.
  assertEquals(
    isoDay(addMonths(new Date('2026-01-31T00:00:00.000Z'), 1)),
    '2026-03-03',
  )
})

Deno.test('two items due on the same car and day become one visit', () => {
  const dueDate = new Date('2026-09-16T00:00:00.000Z')

  const visits = bundleIntoVisits([
    { vehicleId: 'v1', key: 'service_oil_change', dueDate },
    { vehicleId: 'v1', key: 'service_air_filter', dueDate },
  ])

  assertEquals(visits.length, 1)
  assertEquals(visits[0].keys, ['service_oil_change', 'service_air_filter'])
})

Deno.test('the same item twice does not repeat itself in a visit', () => {
  const dueDate = new Date('2026-09-16T00:00:00.000Z')

  const visits = bundleIntoVisits([
    { vehicleId: 'v1', key: 'service_oil_change', dueDate },
    { vehicleId: 'v1', key: 'service_oil_change', dueDate },
  ])

  assertEquals(visits[0].keys, ['service_oil_change'])
})

Deno.test('different cars and different days stay separate visits', () => {
  const day = new Date('2026-09-16T00:00:00.000Z')
  const other = new Date('2026-09-17T00:00:00.000Z')

  const visits = bundleIntoVisits([
    { vehicleId: 'v1', key: 'a', dueDate: day },
    { vehicleId: 'v2', key: 'a', dueDate: day },
    { vehicleId: 'v1', key: 'a', dueDate: other },
  ])

  assertEquals(visits.length, 3)
})

Deno.test('only POST starts a run', async () => {
  const { handler } = handlerWith({})

  const response = await handler(
    new Request('http://localhost/push-due-reminders', { method: 'GET' }),
  )

  assertEquals(response.status, 405)
})

Deno.test('an anon caller is refused before anything is read', async () => {
  const { handler, client } = handlerWith(garage)

  const response = await handler(run(tokenFor('anon')))

  assertEquals(response.status, 403)
  assertEquals(client.queries, [])
})

Deno.test('a run with nothing due sends nothing', async () => {
  const { handler, sent } = handlerWith({ reminder_rules: [], ...garage })

  const response = await handler(run())

  assertEquals(await response.json(), { pushed: 0 })
  assertEquals(sent, [])
})

Deno.test('a dated one-off is pushed at each lead, and only then', async () => {
  for (const lead of REMINDER_LEAD_DAYS) {
    const { handler, sent } = handlerWith({
      reminder_rules: [oneOffIn(lead)],
      ...garage,
    })

    const response = await handler(run())

    assertEquals(await response.json(), { pushed: 1, stale: 0 })
    assertEquals(sent.length, 1, `${lead} days out should push`)
  }

  for (const quiet of [29, 8, 1, 0]) {
    const { handler, sent } = handlerWith({
      reminder_rules: [oneOffIn(quiet)],
      ...garage,
    })

    const response = await handler(run())

    assertEquals(
      await response.json(),
      { pushed: 0 },
      `${quiet} days out is not a lead day and must stay quiet`,
    )
    assertEquals(sent, [])
  }
})

Deno.test('the message carries keys, not sentences', async () => {
  const { handler, sent } = handlerWith({
    reminder_rules: [oneOffIn(30)],
    ...garage,
  })

  await handler(run())

  const message = JSON.parse(sent[0].body).message
  assertEquals(message.token, 'device-1')
  assertEquals(message.data, {
    type: 'reminder_due',
    vehicle_id: 'v1',
    service_type_keys: 'service_registration',
    due_date: isoDay(new Date('2026-09-16T00:00:00.000Z')),
    days_until_due: '30',
    vehicle_nickname: 'Golf',
  })
  // The server has no idea what language the phone reads. If a sentence ever
  // appears in this payload, the Croatian half of the app has been lost.
  assertEquals(
    JSON.stringify(message.data).includes(' '),
    false,
    'no prose belongs in a push payload',
  )
})

Deno.test('one car with two things due the same day gets one notification', async () => {
  const dated = (key: string) => ({
    ...oneOffIn(30),
    id: key,
    service_type_key: key,
  })
  const { handler, sent } = handlerWith({
    reminder_rules: [dated('service_registration'), dated('service_insurance')],
    ...garage,
  })

  const response = await handler(run())

  assertEquals(await response.json(), { pushed: 1, stale: 0 })
  assertEquals(sent.length, 1, 'bundling exists so a visit is one nudge')
  assertEquals(
    JSON.parse(sent[0].body).message.data.service_type_keys,
    'service_registration,service_insurance',
  )
})

Deno.test('every member of the household is notified, not just the author', async () => {
  const { handler, sent } = handlerWith({
    reminder_rules: [oneOffIn(30)],
    vehicles: garage.vehicles,
    household_members: [
      { household_id: 'h1', user_id: 'u1' },
      { household_id: 'h1', user_id: 'u2' },
    ],
    device_tokens: [
      { token: 'device-1', user_id: 'u1' },
      { token: 'device-2', user_id: 'u2' },
    ],
  })

  const response = await handler(run())

  assertEquals(await response.json(), { pushed: 2, stale: 0 })
  assertEquals(
    sent.map((s) => JSON.parse(s.body).message.token).sort(),
    ['device-1', 'device-2'],
    'a shared garage that only told one person would be the whole point lost',
  )
})

Deno.test('a token FCM no longer knows is forgotten', async () => {
  const { handler, client } = handlerWith(
    { reminder_rules: [oneOffIn(30)], ...garage },
    () => new Response('{}', { status: 404 }),
  )

  const response = await handler(run())

  assertEquals(await response.json(), { pushed: 0, stale: 1 })
  const deletion = client.queries.find((q) => q.operation === 'delete')!
  assertEquals(deletion.table, 'device_tokens')
  assertEquals(
    deletion.filters.find((f) => f.method === 'in')?.args,
    ['token', ['device-1']],
    'an uninstalled app leaves a token behind; keeping it forever means ' +
      'every future run pays for a phone that will never answer',
  )
})

Deno.test('a failure to read the rules is reported, not treated as nothing due', async () => {
  const { handler } = handlerWith({
    reminder_rules: () => ({ error: { message: 'statement timeout' } }),
    ...garage,
  })

  const response = await handler(run())

  assertEquals(response.status, 500)
  assertEquals(await response.json(), { error: 'statement timeout' })
})

// The seasonal tyre swap was the one rule the server got wrong in both
// directions: it projected the date from a six-month interval anchored on
// whenever the last swap was logged, and it had never heard of all-season
// tyres. Wherever push is configured the client stops scheduling dated
// reminders entirely, so these were the *only* notifications a household got.
const swapRule = {
  id: 'r-swap',
  vehicle_id: 'v1',
  service_type_key: 'service_tire_swap_seasonal',
  interval_km: null,
  interval_months: 6,
  one_time: false,
  due_date: null,
}

/// Thirty days before Croatia's 15 November, which is when the first of the
/// two nudges is due.
const MONTH_BEFORE_WINTER = new Date('2026-10-16T10:00:00.000Z')

function swapTables(
  countryCode: string,
  tyres: { season: string; retired_at: string | null }[] = [],
) {
  return {
    ...garage,
    households: [{ id: 'h1', country_code: countryCode }],
    reminder_rules: [swapRule],
    service_entries: [
      {
        vehicle_id: 'v1',
        entry_date: '2026-06-20',
        odometer_km: 50000,
        service_type_keys: ['service_tire_swap_seasonal'],
      },
    ],
    tyre_sets: tyres.map((set) => ({ vehicle_id: 'v1', ...set })),
  }
}

Deno.test('the swap is pushed on the statutory date, not the interval', async () => {
  const { handler, sent } = handlerWith(
    swapTables('HR'),
    () => new Response('{}', { status: 200 }),
    MONTH_BEFORE_WINTER,
  )

  await handler(run())

  assertEquals(sent.length, 1)
  const data = JSON.parse(sent[0].body).message.data
  assertEquals(data.due_date, '2026-11-15')
  assertEquals(data.days_until_due, '30')
})

Deno.test('the push says which way the swap goes', async () => {
  // The device handles a push in a background isolate with no provider
  // container, so it cannot look the country up for itself.
  const { handler, sent } = handlerWith(
    swapTables('HR'),
    () => new Response('{}', { status: 200 }),
    MONTH_BEFORE_WINTER,
  )

  await handler(run())

  assertEquals(
    JSON.parse(sent[0].body).message.data.swap_direction,
    'to_winter',
  )
})

Deno.test('a household on all-season tyres is not told to swap', async () => {
  const { handler, sent } = handlerWith(
    swapTables('HR', [{ season: 'all_season', retired_at: null }]),
    () => new Response('{}', { status: 200 }),
    MONTH_BEFORE_WINTER,
  )

  await handler(run())

  assertEquals(sent.length, 0)
})

Deno.test('a household with a winter set still is', async () => {
  const { handler, sent } = handlerWith(
    swapTables('HR', [{ season: 'winter', retired_at: null }]),
    () => new Response('{}', { status: 200 }),
    MONTH_BEFORE_WINTER,
  )

  await handler(run())

  assertEquals(sent.length, 1)
})

Deno.test('the country decides the date', async () => {
  // Slovenia comes out of winter on 15 March; 30 days before that is
  // 13 February, so on 16 October there is nothing yet to say.
  const { handler, sent } = handlerWith(
    swapTables('SI'),
    () => new Response('{}', { status: 200 }),
    new Date('2027-02-13T10:00:00.000Z'),
  )

  await handler(run())

  assertEquals(sent.length, 1)
  const data = JSON.parse(sent[0].body).message.data
  assertEquals(data.due_date, '2027-03-15')
  assertEquals(data.swap_direction, 'to_summer')
})

Deno.test('a country with no verified window falls back to the interval', async () => {
  // Germany's obligation follows the road's condition. The interval says
  // 20 December, so the month's notice is 20 November.
  const { handler, sent } = handlerWith(
    swapTables('DE'),
    () => new Response('{}', { status: 200 }),
    new Date('2026-11-20T10:00:00.000Z'),
  )

  await handler(run())

  assertEquals(sent.length, 1)
  const data = JSON.parse(sent[0].body).message.data
  assertEquals(data.due_date, '2026-12-20')
  assertEquals(
    data.swap_direction,
    undefined,
    'no window means no direction to name',
  )
})

Deno.test('a swap bundled with other work keeps the visit title', () => {
  const visits = bundleIntoVisits([
    {
      vehicleId: 'v1',
      key: 'service_tire_swap_seasonal',
      dueDate: new Date('2026-11-15T00:00:00.000Z'),
      swapDirection: 'to_winter',
    },
    {
      vehicleId: 'v1',
      key: 'service_oil_change',
      dueDate: new Date('2026-11-15T00:00:00.000Z'),
    },
  ])

  assertEquals(visits.length, 1)
  assertEquals(
    visits[0].swapDirection,
    undefined,
    'naming a two-item visit after one item would hide the other',
  )
})

// `reminder.due`: every webhook has been subscribed to it since the table was
// created, and nothing sent it. The daily run is what knows something is due,
// so it tells the hooks as well as the phones — on the same days, about the
// same visits. It tells them the way every event is told: one outbox row per
// visit, for the garage that owns the car, and a drain of the outbox
// (`_shared/outbox.ts`) that posts what the row became.
const HOOK_URL = 'https://home.example/hook'
const FCM_URL =
  'https://fcm.googleapis.com/v1/projects/garage-test/messages:send'

const hook = (overrides: Record<string, unknown> = {}) => ({
  household_id: 'h1',
  id: 'w1',
  url: HOOK_URL,
  secret: 's3cret',
  events: ['entry.created', 'reminder.due'],
  format: 'auto',
  vehicle_ids: null,
  language: 'en',
  active: true,
  ...overrides,
})

const toHooks = (sent: Sent[]) => sent.filter((s) => s.url !== FCM_URL)
const toPhones = (sent: Sent[]) => sent.filter((s) => s.url === FCM_URL)

/// A run on a project with no Firebase at all: the secret is not set.
async function withoutFirebase(run: () => Promise<void>) {
  const secret = Deno.env.get('FCM_SERVICE_ACCOUNT')!
  Deno.env.delete('FCM_SERVICE_ACCOUNT')
  try {
    await run()
  } finally {
    Deno.env.set('FCM_SERVICE_ACCOUNT', secret)
  }
}

Deno.test('a visit due in a week is posted to the garage webhook, signed', async () => {
  const { handler, sent, outbox, deliveries } = handlerWith({
    reminder_rules: [oneOffIn(7)],
    ...garage,
    webhooks: [hook()],
  })

  const response = await handler(run())

  assertEquals(await response.json(), { pushed: 1, stale: 0, delivered: 1 })
  // Written as an event first, the way a trigger writes one, and then
  // drained: the row, the delivery it became, and the call.
  assertEquals(outbox.length, 1)
  assertEquals(outbox[0].household_id, 'h1')
  assertEquals(outbox[0].event, 'reminder.due')
  assertEquals(outbox[0].payload, {
    // The key the drain's car filter reads on every row, beside the fields
    // the builder reads.
    vehicle_id: 'v1',
    vehicleId: 'v1',
    vehicleName: 'Golf',
    keys: ['service_registration'],
    dueDate: '2026-08-24',
    daysUntilDue: 7,
    swapDirection: undefined,
  })
  assertEquals(outbox[0].processed_at, TODAY.toISOString())
  assertEquals(deliveries.length, 1)
  assertEquals(deliveries[0].outbox_id, outbox[0].id)
  assertEquals(deliveries[0].webhook_id, 'w1')
  assertEquals(deliveries[0].delivered_at, TODAY.toISOString())
  const posted = toHooks(sent)
  assertEquals(posted.length, 1, 'one visit, one hook, one call')
  assertEquals(posted[0].url, HOOK_URL)
  assertEquals(posted[0].headers['X-Garage-Delivery'], deliveries[0].id)
  assertEquals(
    posted[0].body,
    JSON.stringify({
      event: 'reminder.due',
      vehicle_id: 'v1',
      vehicle_name: 'Golf',
      due: ['service_registration'],
      due_date: '2026-08-24',
      days_until_due: 7,
      at: TODAY.toISOString(),
    }),
  )
  assertEquals(posted[0].headers['X-Garage-Event'], 'reminder.due')
  assertEquals(
    posted[0].headers['X-Garage-Signature'],
    await sign('s3cret', posted[0].body),
  )
})

Deno.test('the month notice goes to the hooks too, and only on lead days', async () => {
  const month = handlerWith({
    reminder_rules: [oneOffIn(30)],
    ...garage,
    webhooks: [hook()],
  })
  await month.handler(run())
  assertEquals(
    toHooks(month.sent).map((s) => JSON.parse(s.body).days_until_due),
    [30],
  )

  for (const quiet of [29, 8, 1, 0]) {
    const { handler, sent } = handlerWith({
      reminder_rules: [oneOffIn(quiet)],
      ...garage,
      webhooks: [hook()],
    })

    await handler(run())

    assertEquals(sent, [], `${quiet} days out is not a lead day`)
  }
})

Deno.test('each visit is its own event', async () => {
  const { handler, sent } = handlerWith({
    reminder_rules: [oneOffIn(30), oneOffIn(7)],
    ...garage,
    webhooks: [hook()],
  })

  const response = await handler(run())

  assertEquals((await response.json()).delivered, 2)
  assertEquals(
    toHooks(sent).map((s) => JSON.parse(s.body).due_date).sort(),
    ['2026-08-24', '2026-09-16'],
  )
})

Deno.test('a hook that did not subscribe to reminders hears nothing', async () => {
  const { handler, sent, client, outbox } = handlerWith({
    reminder_rules: [oneOffIn(7)],
    ...garage,
    webhooks: [hook({ events: ['entry.created'] })],
  })

  const response = await handler(run())

  assertEquals(
    await response.json(),
    { pushed: 1, stale: 0 },
    'a run that called no hook reports what it always did',
  )
  assertEquals(toHooks(sent), [])
  assertEquals(outbox, [], 'nobody listening, so nothing is written')
  assertEquals(client.queries.some((q) => q.operation === 'update'), false)
})

// A hook may watch one car of the garage. Its reminders are that car's, at
// the row — the run writes nothing for a car nobody watches — and at the
// drain, which reads the same key off every row it fans out.
Deno.test('a hook that watches another car hears nothing about this one', async () => {
  const theirs = 'https://other-car.example/hook'
  const { handler, sent, outbox } = handlerWith({
    reminder_rules: [oneOffIn(7)],
    ...garage,
    webhooks: [
      hook({ vehicle_ids: ['v2'], url: theirs }),
      hook({ id: 'w2', vehicle_ids: ['v1'] }),
    ],
  })

  await handler(run())

  assertEquals(toHooks(sent).map((s) => s.url), [HOOK_URL])

  const nobody = handlerWith({
    reminder_rules: [oneOffIn(7)],
    ...garage,
    webhooks: [hook({ vehicle_ids: ['v2'], url: theirs })],
  })
  await nobody.handler(run())
  assertEquals(nobody.outbox, [])
  assertEquals(outbox.length, 1)
})

// A webhook belongs to a garage. A guest with a pass to the car is not part
// of that garage, and neither is anybody else's hook.
Deno.test('another garage hook hears nothing about this garage car', async () => {
  const neighbour = 'https://neighbour.example/hook'
  const { handler, sent, client } = handlerWith({
    reminder_rules: [oneOffIn(7)],
    ...garage,
    webhooks: [
      hook({ id: 'w2', household_id: 'h2', url: neighbour }),
      hook(),
    ],
  })

  await handler(run())

  assertEquals(toHooks(sent).map((s) => s.url), [HOOK_URL])
  const lookup = client.queries.find((q) => q.table === 'webhooks')!
  assertEquals(
    lookup.filters
      .filter((f) => f.method !== 'select')
      .map((f) => [f.method, ...f.args]),
    [
      ['in', 'household_id', ['h1']],
      ['eq', 'active', true],
    ],
    'only the garages with something due, and only hooks that are switched on',
  )
})

Deno.test('two garages due the same day each hear about their own car', async () => {
  const theirs = 'https://neighbour.example/hook'
  const { handler, sent } = handlerWith({
    reminder_rules: [oneOffIn(7), {
      ...oneOffIn(7),
      id: 'r2',
      vehicle_id: 'v2',
    }],
    vehicles: [
      ...garage.vehicles,
      { id: 'v2', nickname: 'Clio', household_id: 'h2' },
    ],
    household_members: garage.household_members,
    device_tokens: garage.device_tokens,
    webhooks: [hook(), hook({ id: 'w2', household_id: 'h2', url: theirs })],
  })

  await handler(run())

  const heard = toHooks(sent).map((s) => [s.url, JSON.parse(s.body).vehicle_id])
  assertEquals(
    heard.sort(),
    [[HOOK_URL, 'v1'], [theirs, 'v2']].sort(),
  )
})

Deno.test('a run with nothing due does not look for hooks', async () => {
  const { handler, client } = handlerWith({
    reminder_rules: [oneOffIn(8)],
    ...garage,
    webhooks: [hook()],
  })

  await handler(run())

  assertEquals(client.queries.some((q) => q.table === 'webhooks'), false)
})

Deno.test('without Firebase the hooks are still told, and no push is tried', async () => {
  await withoutFirebase(async () => {
    const { handler, sent, client, exchanges } = handlerWith({
      reminder_rules: [oneOffIn(7)],
      ...garage,
      webhooks: [hook()],
    })

    const response = await handler(run())

    assertEquals(response.status, 200)
    assertEquals(await response.json(), {
      pushed: 0,
      delivered: 1,
      push_skipped: 'FCM_SERVICE_ACCOUNT secret not configured',
    })
    assertEquals(sent.map((s) => s.url), [HOOK_URL])
    assertEquals(exchanges, [], 'no token was asked for')
    assertEquals(
      client.queries.some((q) =>
        q.table === 'device_tokens' || q.table === 'household_members'
      ),
      false,
      'nobody is looked up for a push that cannot be sent',
    )
  })
})

// It used to answer 500 before reading anything. A project with no Firebase is
// a project that has not turned push on, which is not an error — but it still
// says so, because a phone that stopped scheduling its own reminders is
// waiting on exactly this.
Deno.test('without Firebase and nothing due, the run says pushes are off', async () => {
  await withoutFirebase(async () => {
    const { handler, sent } = handlerWith({
      reminder_rules: [oneOffIn(8)],
      ...garage,
      webhooks: [hook()],
    })

    const response = await handler(run())

    assertEquals(response.status, 200)
    assertEquals(await response.json(), {
      pushed: 0,
      push_skipped: 'FCM_SERVICE_ACCOUNT secret not configured',
    })
    assertEquals(sent, [])
  })
})

Deno.test('with Firebase the hooks are told first, then the phones', async () => {
  const { handler, sent, exchanges } = handlerWith({
    reminder_rules: [oneOffIn(7)],
    ...garage,
    webhooks: [hook()],
  })

  const response = await handler(run())

  assertEquals(await response.json(), { pushed: 1, stale: 0, delivered: 1 })
  assertEquals(sent.map((s) => s.url), [HOOK_URL, FCM_URL])
  assertEquals(exchanges.length, 1)
  assertEquals(
    JSON.parse(toPhones(sent)[0].body).message.data.type,
    'reminder_due',
  )
})

Deno.test('a failed delivery is recorded, and the phones are still told', async () => {
  const failures: [string, () => Response, number][] = [
    ['switched off', () => {
      throw new TypeError('connection refused')
    }, 0],
    ['refusing', () => new Response('nope', { status: 500 }), 500],
  ]
  for (const [name, fail, status] of failures) {
    const { handler, sent, client, deliveries } = handlerWith(
      { reminder_rules: [oneOffIn(7)], ...garage, webhooks: [hook()] },
      (url) => url === HOOK_URL ? fail() : new Response('{}', { status: 200 }),
    )

    const response = await handler(run())

    assertEquals(
      await response.json(),
      { pushed: 1, stale: 0, delivered: 0 },
      name,
    )
    assertEquals(toPhones(sent).length, 1, `${name}: the push still went`)
    const update = client.queries.find((q) =>
      q.table === 'webhooks' && q.operation === 'update'
    )!
    assertEquals(
      update.filters.find((f) => f.method === 'eq')?.args,
      ['id', 'w1'],
    )
    assertEquals(update.payload, {
      last_delivery_at: TODAY.toISOString(),
      last_delivery_status: status,
    }, name)
    // And the delivery waits for the next drain rather than being lost, as
    // it used to be: the run is daily, and a receiver down for a minute
    // would have missed the week's notice.
    assertEquals(deliveries[0].attempts, 1, name)
    assertEquals(deliveries[0].delivered_at, null, name)
    assertEquals(
      deliveries[0].next_attempt_at,
      new Date(TODAY.getTime() + 60_000).toISOString(),
      name,
    )
  }
})

// The run is daily and a lead day comes once: a row the outbox refused is a
// notice the hooks will not get, which is worth a line in the log. The phones
// are no business of the outbox's and are still told.
Deno.test('an outbox that refuses the row is said, and the phones are still told', async () => {
  const { handler, sent } = handlerWith({
    reminder_rules: [oneOffIn(7)],
    ...garage,
    webhooks: [hook()],
    webhook_outbox: () => ({ error: { message: 'connection reset' } }),
  })
  const logged: unknown[][] = []
  const original = console.error
  console.error = (...args: unknown[]) => {
    logged.push(args)
  }
  try {
    const response = await handler(run())

    assertEquals(await response.json(), { pushed: 1, stale: 0, delivered: 0 })
    assertEquals(toHooks(sent), [])
    assertEquals(toPhones(sent).length, 1)
    assertEquals(logged.length, 1)
    assertEquals(String(logged[0][0]).includes('reminder.due'), true)
  } finally {
    console.error = original
  }
})

Deno.test('a chat service is sent a message it can show', async () => {
  const { handler, sent } = handlerWith({
    reminder_rules: [oneOffIn(7)],
    ...garage,
    webhooks: [hook({ url: 'https://discord.com/api/webhooks/1/a' })],
  })

  await handler(run())

  assertEquals(JSON.parse(toHooks(sent)[0].body), {
    content: '🔔 Due in 7 days · Golf\nRegistration · 24 Aug 2026',
    allowed_mentions: { parse: [] },
    flags: 4,
  })
})

// The same hardening an entry gets: the name of a car is typed by a person.
Deno.test('a chat service cannot be pinged through the name of a car', async () => {
  const { handler, sent } = handlerWith({
    reminder_rules: [oneOffIn(7)],
    ...garage,
    vehicles: [{ id: 'v1', nickname: '<!channel> Golf', household_id: 'h1' }],
    webhooks: [hook({ url: 'https://hooks.slack.com/services/A/B/C' })],
  })

  await handler(run())

  assertEquals(
    JSON.parse(toHooks(sent)[0].body).text.split('\n')[0],
    '🔔 Due in 7 days · &lt;!channel&gt; Golf',
  )
})

Deno.test('the signature covers the body a generic receiver is sent', async () => {
  const { handler, sent } = handlerWith({
    reminder_rules: [oneOffIn(7)],
    ...garage,
    webhooks: [
      hook(),
      hook({
        id: 'w2',
        url: 'https://discord.com/api/webhooks/1/a',
        secret: 'other',
      }),
    ],
  })

  await handler(run())

  const [generic, discord] = toHooks(sent)
  assertEquals(
    discord.headers['X-Garage-Signature'],
    await sign('other', generic.body),
    'a chat service ignores the header; what it signs is what a generic ' +
      'receiver would have been sent',
  )
  assertEquals(
    generic.headers['X-Garage-Signature'],
    await sign('s3cret', generic.body),
  )
})

Deno.test('a swap tells the hook which way it goes', async () => {
  const { handler, sent } = handlerWith(
    { ...swapTables('HR'), webhooks: [hook()] },
    () => new Response('{}', { status: 200 }),
    MONTH_BEFORE_WINTER,
  )

  await handler(run())

  const event = JSON.parse(toHooks(sent)[0].body)
  assertEquals(event.due, ['service_tire_swap_seasonal'])
  assertEquals(event.due_date, '2026-11-15')
  assertEquals(event.swap_direction, 'to_winter')
})

// A reminder due by distance used to be dated from today: the distance still to
// go, at 30 km a day, counted from the morning of the run. With no new reading
// the distance to go stayed put, so the days to go did too, and a notice that
// was seven days out on Monday was seven days out on Tuesday. It is now dated
// from the reading the distance was measured at.
const oilRule = {
  id: 'r-oil',
  vehicle_id: 'v1',
  service_type_key: 'service_oil_change',
  interval_km: 15000,
  interval_months: null,
  one_time: false,
  due_date: null,
}

/// The oil change the rule counts from: 50,000 km, so it is due at 65,000.
const lastOilChange = {
  vehicle_id: 'v1',
  entry_date: '2026-03-01',
  odometer_km: 50000,
  service_type_keys: ['service_oil_change'],
}

/// A table that answers as Postgres would for the queries that matter here:
/// nothing past a `lte`, nothing null where `not … is null` was asked, in the
/// order asked for, and no more rows than the limit. The shared fake returns
/// every row, first one first, whatever was asked.
function ordered(rows: Row[]) {
  return (query: RecordedQuery) => {
    const kept = rows.filter((row) =>
      query.filters.every(({ method, args: [column, ...rest] }) => {
        const value = row[column as string] as string | number | null
        if (method === 'lte') {
          return value !== null && value <= (rest[0] as string | number)
        }
        if (method === 'not' && rest[0] === 'is' && rest[1] === null) {
          return value !== null && value !== undefined
        }
        return true
      })
    )
    const orders = query.filters.filter((f) => f.method === 'order')
    const sorted = [...kept].sort((a, b) => {
      for (const { args: [column, options] } of orders) {
        const x = a[column as string] as string | number
        const y = b[column as string] as string | number
        if (x !== y) {
          const ascending = (options as { ascending?: boolean }).ascending
          return (x < y ? -1 : 1) * (ascending === false ? -1 : 1)
        }
      }
      return 0
    })
    const limit = query.filters.find((f) => f.method === 'limit')
    return limit ? sorted.slice(0, limit.args[0] as number) : sorted
  }
}

/// The garage with the oil rule, the service it counts from, and whatever
/// readings the car has had since, by table.
function distanceTables(
  readings: Record<string, { entry_date: string; km: number }[]> = {},
  rules: Row[] = [oilRule],
) {
  const sources: Record<string, string> = {
    fuel_entries: 'odometer_km',
    odometer_entries: 'odometer_km',
    trip_entries: 'end_odometer_km',
  }
  return {
    ...garage,
    reminder_rules: rules,
    service_entries: ordered([lastOilChange]),
    ...Object.fromEntries(
      Object.entries(readings).map(([table, rows]) => [
        table,
        ordered(rows.map(({ entry_date, km }) => ({
          vehicle_id: 'v1',
          entry_date,
          [sources[table]]: km,
        }))),
      ]),
    ),
  }
}

const morningOf = (day: string) => new Date(`${day}T06:00:00.000Z`)

/// The days out of [days] on which a run sent anything, and what it said.
async function sentOn(
  tables: Parameters<typeof handlerWith>[0],
  days: string[],
) {
  const sent: { day: string; data: Record<string, string> }[] = []
  for (const day of days) {
    const morning = handlerWith(tables, undefined, morningOf(day))
    await morning.handler(run())
    for (const push of morning.sent) {
      sent.push({ day, data: JSON.parse(push.body).message.data })
    }
  }
  return sent
}

const SEPTEMBER = ['2026-09-17', '2026-09-18', '2026-09-19']

Deno.test('a reminder due by distance is sent once, not every morning', async () => {
  // Nothing has been logged since 11 September. From there, at 30 km a day:
  const cases: [number, string[]][] = [
    // 14 days: the week's notice falls on the 18th.
    [420, ['2026-09-18']],
    // 37 days: the month's notice falls on the 18th.
    [1110, ['2026-09-18']],
    // 7 days: the week's notice was the 11th itself, and is not repeated.
    [210, []],
  ]
  for (const [toGo, expected] of cases) {
    const tables = distanceTables({
      odometer_entries: [{ entry_date: '2026-09-11', km: 65000 - toGo }],
    })

    const sent = await sentOn(tables, SEPTEMBER)

    assertEquals(sent.map((s) => s.day), expected, `${toGo} km to go`)
  }
})

Deno.test('a reminder due by distance is dated from the reading, not the run', async () => {
  const sent = await sentOn(
    distanceTables({
      odometer_entries: [{ entry_date: '2026-09-11', km: 64580 }],
    }),
    ['2026-09-18'],
  )

  // 420 km to go from 64,580 on the 11th is fourteen days: the 25th.
  assertEquals(sent[0].data.due_date, '2026-09-25')
  assertEquals(sent[0].data.days_until_due, '7')
})

Deno.test('a new reading moves the date', async () => {
  const eleventh = { entry_date: '2026-09-11', km: 64580 }
  // Five days later the car had done 210 km, not the 150 assumed, and the
  // 210 km still to go put the oil change on the 23rd rather than the 25th.
  const sixteenth = { entry_date: '2026-09-16', km: 64790 }

  assertEquals(
    await sentOn(
      distanceTables({ odometer_entries: [eleventh] }),
      ['2026-09-16'],
    ),
    [],
    'from the 11th alone, the 25th is nine days away',
  )
  const moved = await sentOn(
    distanceTables({ odometer_entries: [eleventh, sixteenth] }),
    ['2026-09-16'],
  )
  assertEquals(moved.map((s) => s.data.due_date), ['2026-09-23'])
})

Deno.test('the highest reading counts, whichever table has it', async () => {
  // The later row is the lower one, which makes it a typo: an odometer only
  // goes up. And a fill-up can be further along than any reading.
  const sent = await sentOn(
    distanceTables({
      odometer_entries: [
        { entry_date: '2026-09-11', km: 64580 },
        { entry_date: '2026-09-14', km: 46000 },
      ],
      fuel_entries: [{ entry_date: '2026-09-09', km: 64790 }],
    }),
    ['2026-09-09', '2026-09-11', '2026-09-16'],
  )

  // 210 km to go from the fill-up on the 9th: the 16th, a week out on the 9th.
  assertEquals(sent.map((s) => [s.day, s.data.due_date]), [
    ['2026-09-09', '2026-09-16'],
  ])
})

// Two rows at one odometer say the car stood still between them, so the days
// in between are not days it drove. From the 11th the week's notice would have
// been due on the 11th itself; from the 16th it is due on the 16th.
Deno.test('of two readings at the same odometer, the later one dates it', async () => {
  const sent = await sentOn(
    distanceTables({
      fuel_entries: [{ entry_date: '2026-09-11', km: 64790 }],
      trip_entries: [{ entry_date: '2026-09-16', km: 64790 }],
    }),
    ['2026-09-16'],
  )

  assertEquals(sent.map((s) => [s.day, s.data.due_date]), [
    ['2026-09-16', '2026-09-23'],
  ])
})

Deno.test('the readings are asked for highest first, and latest among equals', async () => {
  const { handler, client } = handlerWith(
    distanceTables({
      odometer_entries: [{ entry_date: '2026-09-11', km: 64580 }],
    }),
    undefined,
    morningOf('2026-09-18'),
  )

  await handler(run())

  for (
    const [table, column] of [
      ['odometer_entries', 'odometer_km'],
      ['trip_entries', 'end_odometer_km'],
    ]
  ) {
    const reading = client.queries.find((q) => q.table === table)!
    assertEquals(reading.select, `${column}, entry_date`)
    assertEquals(
      reading.filters
        .filter((f) => f.method !== 'select')
        .map((f) => [f.method, ...f.args]),
      [
        ['eq', 'vehicle_id', 'v1'],
        ['not', column, 'is', null],
        // A reading dated after today is a typo, as the app has it.
        ['lte', 'entry_date', '2026-09-18'],
        ['order', column, { ascending: false }],
        ['order', 'entry_date', { ascending: false }],
        ['limit', 1],
      ],
      table,
    )
  }
  const baseline = client.queries.find((q) =>
    q.table === 'vehicles' && q.select?.startsWith('baseline')
  )!
  assertEquals(baseline.select, 'baseline_odometer_km, baseline_date')
  assertEquals(
    baseline.filters.filter((f) => f.method === 'eq').map((f) => f.args),
    [['id', 'v1']],
  )
})

Deno.test('with no reading to be had, the service itself is the reading', async () => {
  // Every reading fails to load. The service the rule counts from is a reading
  // too: 50,000 km on the 11th, with 420 km to go, is the 25th.
  const refused = () => ({ error: { message: 'permission denied' } })
  const service = { ...lastOilChange, entry_date: '2026-09-11' }
  const tables = {
    ...garage,
    reminder_rules: [{ ...oilRule, interval_km: 420 }],
    service_entries: (query: RecordedQuery) =>
      query.select === 'entry_date, odometer_km' ? [service] : refused(),
    fuel_entries: refused,
    cost_entries: refused,
    odometer_entries: refused,
    trip_entries: refused,
    income_entries: refused,
  }

  const sent = await sentOn(tables, SEPTEMBER)

  assertEquals(sent.map((s) => [s.day, s.data.due_date]), [
    ['2026-09-18', '2026-09-25'],
  ])
})

Deno.test('a reminder already past its odometer is never sent', async () => {
  for (
    const readings of [
      // 300 km over.
      [{ entry_date: '2026-09-11', km: 65300 }],
      // Exactly at it.
      [{ entry_date: '2026-09-11', km: 65000 }],
      // 210 km to go, as of 1 August: by the estimate that was due on the 8th.
      [{ entry_date: '2026-08-01', km: 64790 }],
    ]
  ) {
    const sent = await sentOn(
      distanceTables({ odometer_entries: readings }),
      ['2026-09-11', ...SEPTEMBER],
    )

    assertEquals(sent, [], JSON.stringify(readings))
  }
})

Deno.test('a reminder due by date is dated as it always was', async () => {
  // Six months from 25 March, whatever the odometer says.
  const byDate = {
    ...oilRule,
    id: 'r-inspection',
    service_type_key: 'service_inspection',
    interval_km: null,
    interval_months: 6,
  }
  const inspection = {
    vehicle_id: 'v1',
    entry_date: '2026-03-25',
    odometer_km: 48000,
    service_type_keys: ['service_inspection'],
  }
  const tables = {
    ...distanceTables({
      odometer_entries: [{ entry_date: '2026-09-11', km: 64580 }],
    }, [byDate]),
    service_entries: ordered([inspection]),
  }

  const sent = await sentOn(tables, SEPTEMBER)

  assertEquals(sent.map((s) => [s.day, s.data.due_date]), [
    ['2026-09-18', '2026-09-25'],
  ])
})

Deno.test('with both intervals, the earlier date still wins', async () => {
  // By distance, 1,110 km from the 11th is 18 October; by date, six months
  // from 25 March is 25 September. And the other way round.
  const both = { ...oilRule, interval_months: 6 }
  const reading = {
    odometer_entries: [{ entry_date: '2026-09-11', km: 63890 }],
  }
  const byDateFirst = {
    ...distanceTables(reading, [both]),
    service_entries: ordered([{ ...lastOilChange, entry_date: '2026-03-25' }]),
  }
  const byDistanceFirst = {
    ...distanceTables(reading, [both]),
    service_entries: ordered([{ ...lastOilChange, entry_date: '2026-06-25' }]),
  }

  assertEquals(
    (await sentOn(byDateFirst, SEPTEMBER)).map((s) => s.data.due_date),
    ['2026-09-25'],
  )
  assertEquals(
    (await sentOn(byDistanceFirst, SEPTEMBER)).map((s) => s.data.due_date),
    ['2026-10-18'],
  )
})

Deno.test('the furthest reading is the highest, then the latest', () => {
  const eleventh = { km: 64580, day: '2026-09-11' }

  assertEquals(furthestReading(null, eleventh), eleventh)
  assertEquals(
    furthestReading(eleventh, { km: 64000, day: '2026-09-14' }),
    eleventh,
    'a lower reading on a later day is a typo',
  )
  assertEquals(
    furthestReading(eleventh, { km: 64580, day: '2026-09-16' }),
    { km: 64580, day: '2026-09-16' },
  )
  assertEquals(
    furthestReading({ km: 64580, day: '2026-09-16' }, eleventh),
    { km: 64580, day: '2026-09-16' },
  )
})

// The app never takes a reading dated after today: a year typed as 2062 would
// otherwise decide where the car stands and when it gets anywhere
// (`OdometerHistory.sorted`). Here it would put the oil change, and its notice,
// forty years out.
Deno.test('a reading dated after today is not a reading', async () => {
  const sent = await sentOn(
    distanceTables({
      odometer_entries: [{ entry_date: '2026-09-11', km: 64580 }],
      fuel_entries: [{ entry_date: '2062-09-16', km: 64790 }],
    }),
    SEPTEMBER,
  )

  assertEquals(sent.map((s) => [s.day, s.data.due_date]), [
    ['2026-09-18', '2026-09-25'],
  ])
})

// The odometer the owner gave when the car was added is where the app starts
// counting (`OdometerHistory.currentKm`). Without it, a car with an old service
// on record and nothing logged since was dated from that service.
Deno.test('the owner baseline is a reading too', async () => {
  const withBaseline = (baseline_date: string) => ({
    ...distanceTables(),
    vehicles: [{
      id: 'v1',
      nickname: 'Golf',
      household_id: 'h1',
      baseline_odometer_km: 64580,
      baseline_date,
    }],
  })

  assertEquals(
    (await sentOn(withBaseline('2026-09-11'), SEPTEMBER))
      .map((s) => [s.day, s.data.due_date]),
    [['2026-09-18', '2026-09-25']],
  )
  // Dated 4 October, the same baseline would put the oil change on 18
  // October, and the month's notice on the 18th.
  assertEquals(
    await sentOn(withBaseline('2026-10-04'), SEPTEMBER),
    [],
    'a baseline dated after today is no more a reading than a fill-up is',
  )
})

// A one-off can be due at an odometer rather than on a date: a timing belt
// good for so many kilometres, a first service at 1,000. `due_odometer_km`
// (0014) was never read, so none of those was ever pushed.
const beltRule = {
  id: 'r-belt',
  vehicle_id: 'v1',
  service_type_key: 'service_timing_belt',
  interval_km: null,
  interval_months: null,
  one_time: true,
  due_date: null,
  due_odometer_km: 65000,
}

Deno.test('a one-off due at an odometer is sent once, dated from the reading', async () => {
  const sent = await sentOn(
    distanceTables({
      odometer_entries: [{ entry_date: '2026-09-11', km: 64580 }],
    }, [beltRule]),
    SEPTEMBER,
  )

  // 420 km from 64,580 on the 11th is fourteen days: the 25th.
  assertEquals(sent.map((s) => [s.day, s.data.due_date]), [
    ['2026-09-18', '2026-09-25'],
  ])
  assertEquals(sent[0].data.service_type_keys, 'service_timing_belt')
  assertEquals(sent[0].data.days_until_due, '7')
})

Deno.test('a one-off goes by its date or its odometer, whichever comes first', async () => {
  // By the calendar the 25th; by the odometer, 1,110 km from the 11th, 18
  // October. The 25th is the only date there is, so no month's notice for the
  // later one goes out on the 18th.
  const dateFirst = await sentOn(
    distanceTables({
      odometer_entries: [{ entry_date: '2026-09-11', km: 63890 }],
    }, [{ ...beltRule, due_date: '2026-09-25' }]),
    SEPTEMBER,
  )
  assertEquals(dateFirst.map((s) => [s.day, s.data.due_date]), [
    ['2026-09-18', '2026-09-25'],
  ])

  // By the calendar 18 October, whose month's notice would be the 18th; by
  // the odometer, 420 km from the 11th, the 25th.
  const odometerFirst = await sentOn(
    distanceTables({
      odometer_entries: [{ entry_date: '2026-09-11', km: 64580 }],
    }, [{ ...beltRule, due_date: '2026-10-18' }]),
    SEPTEMBER,
  )
  assertEquals(odometerFirst.map((s) => [s.day, s.data.due_date]), [
    ['2026-09-18', '2026-09-25'],
  ])
})

Deno.test('a one-off already past its odometer is never sent', async () => {
  const cases: [string, Row, { entry_date: string; km: number }][] = [
    ['300 km over', beltRule, { entry_date: '2026-09-11', km: 65300 }],
    ['exactly at it', beltRule, { entry_date: '2026-09-11', km: 65000 }],
    ['past it by the estimate', beltRule, {
      entry_date: '2026-08-01',
      km: 64790,
    }],
    // The odometer came first, so the item is due already, and a date still
    // ahead does not bring the notice back.
    ['past it, with a date still ahead', {
      ...beltRule,
      due_date: '2026-09-25',
    }, { entry_date: '2026-09-11', km: 65300 }],
  ]
  for (const [name, rule, reading] of cases) {
    const sent = await sentOn(
      distanceTables({ odometer_entries: [reading] }, [rule]),
      ['2026-09-11', ...SEPTEMBER],
    )

    assertEquals(sent, [], name)
  }
})

Deno.test('with nothing to count from, a one-off due at an odometer is not sent', async () => {
  const sent = await sentOn(
    { ...garage, reminder_rules: [beltRule] },
    ['2026-09-11', ...SEPTEMBER],
  )

  assertEquals(sent, [])
})

Deno.test('a one-off due on a date alone reads no odometer', async () => {
  const { handler, client, sent } = handlerWith({
    reminder_rules: [oneOffIn(7)],
    ...garage,
  })

  await handler(run())

  assertEquals(sent.length, 1)
  assertEquals(
    client.queries.some((q) =>
      ['fuel_entries', 'odometer_entries', 'trip_entries'].includes(q.table)
    ),
    false,
  )
})
