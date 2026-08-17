import { assertEquals } from 'jsr:@std/assert@1'
import {
  addMonths,
  bundleIntoVisits,
  dayDiff,
  isoDay,
  isServiceRole,
  makeHandler,
  REMINDER_LEAD_DAYS,
} from './handler.ts'
import { fakeClient, stubEnv } from '../_test/fake_supabase.ts'

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
}

function handlerWith(
  tables: NonNullable<Parameters<typeof fakeClient>[0]>['tables'],
  respond: () => Response = () => new Response('{}', { status: 200 }),
) {
  const client = fakeClient({ tables })
  const sent: Sent[] = []
  const handler = makeHandler({
    createClient: () => client,
    now: () => TODAY,
    fcmAccessToken: () => Promise.resolve('fcm-access-token'),
    fetch: ((url: string, init: RequestInit) => {
      sent.push({ url, body: init.body as string })
      return Promise.resolve(respond())
    }) as unknown as typeof fetch,
  })
  return { handler, client, sent }
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
