import { assertEquals, assertNotEquals } from 'jsr:@std/assert@1'
import { makeHandler, resourceFromPath, sha256Hex } from './handler.ts'
import { fakeClient, stubEnv } from '../_test/fake_supabase.ts'

stubEnv()

const KEY = 'grg_testkey'
const HOUSEHOLD = 'household-1'

/// A client that recognises [KEY] and owns two cars.
function handlerWith(config: Parameters<typeof fakeClient>[0] = {}) {
  const client = fakeClient({
    rpc: { household_for_api_key: HOUSEHOLD },
    ...config,
    // After the spread, not before: a caller adding one table must not lose
    // the vehicles every resource is scoped by.
    tables: {
      vehicles: [
        { id: 'v1', nickname: 'Golf' },
        { id: 'v2', nickname: 'Clio' },
      ],
      ...config.tables,
    },
  })
  return { handler: makeHandler({ createClient: () => client }), client }
}

const get = (path = '', key: string | null = KEY) =>
  new Request(`http://localhost/public-api${path}`, {
    method: 'GET',
    headers: key ? { Authorization: `Bearer ${key}` } : {},
  })

Deno.test('the resource is read from the end of the path, not the start', () => {
  // Supabase serves this at /functions/v1/public-api/…; a local call has no
  // such prefix. Both have to name the same resource.
  assertEquals(resourceFromPath('/functions/v1/public-api/fuel'), 'fuel')
  assertEquals(resourceFromPath('/public-api/fuel'), 'fuel')
  assertEquals(resourceFromPath('/public-api/fuel/'), 'fuel')
  assertEquals(resourceFromPath('/public-api'), '')
  assertEquals(resourceFromPath('/public-api/'), '')
})

Deno.test('a browser preflight is answered without a key', async () => {
  const { handler } = handlerWith()

  const response = await handler(
    new Request('http://localhost/public-api', { method: 'OPTIONS' }),
  )

  assertEquals(response.status, 204)
  assertEquals(response.headers.get('Access-Control-Allow-Origin'), '*')
})

Deno.test('the API is read-only, so a write verb is refused', async () => {
  const { handler } = handlerWith()

  const response = await handler(
    new Request('http://localhost/public-api/fuel', { method: 'POST' }),
  )

  assertEquals(response.status, 405)
})

Deno.test('a request with no key is refused before anything is read', async () => {
  const { handler, client } = handlerWith()

  const response = await handler(get('/vehicles', null))

  assertEquals(response.status, 401)
  assertEquals(await response.json(), { error: 'missing api key' })
  assertEquals(client.queries, [], 'nothing should have been queried')
})

Deno.test('a key that resolves to no household is refused', async () => {
  const client = fakeClient({ rpc: {} })
  const handler = makeHandler({ createClient: () => client })

  const response = await handler(get('/vehicles'))

  assertEquals(response.status, 401)
  assertEquals(await response.json(), { error: 'invalid api key' })
  assertEquals(client.queries, [])
})

Deno.test('the key is matched by hash, and never sent as itself', async () => {
  const { handler, client } = handlerWith()

  await handler(get('/vehicles'))

  const params = client.rpcCalls[0].params as { key_hash_input: string }
  assertEquals(client.rpcCalls[0].name, 'household_for_api_key')
  assertEquals(params.key_hash_input, await sha256Hex(KEY))
  assertNotEquals(
    params.key_hash_input,
    KEY,
    'the key itself must never leave the request; only its hash is stored',
  )
})

Deno.test('the root lists what can be asked for', async () => {
  const { handler } = handlerWith()

  const response = await handler(get(''))
  const body = await response.json()

  assertEquals(response.status, 200)
  assertEquals(body.household, HOUSEHOLD)
  assertEquals(body.resources.includes('fuel'), true)
  assertEquals(body.resources.includes('due'), true)
})

Deno.test('vehicles are scoped to the household the key belongs to', async () => {
  const { handler, client } = handlerWith()

  const response = await handler(get('/vehicles'))

  assertEquals(response.status, 200)
  const scoping = client.queries[0].filters.find((f) => f.method === 'eq')
  assertEquals(
    scoping?.args,
    ['household_id', HOUSEHOLD],
    'every row served afterwards hangs off this filter',
  )
})

Deno.test('entries are scoped to that household cars, and capped', async () => {
  const { handler, client } = handlerWith({
    tables: { fuel_entries: [{ id: 'f1', vehicle_id: 'v1' }] },
  })

  const response = await handler(get('/fuel'))

  assertEquals(response.status, 200)
  assertEquals(await response.json(), {
    fuel: [{ id: 'f1', vehicle_id: 'v1' }],
  })

  const entries = client.queries[1]
  assertEquals(entries.table, 'fuel_entries')
  assertEquals(
    entries.filters.find((f) => f.method === 'in')?.args,
    ['vehicle_id', ['v1', 'v2']],
    'a household that could read another household cars would be the whole bug',
  )
  assertEquals(entries.filters.find((f) => f.method === 'limit')?.args, [500])
})

Deno.test('every documented resource answers', async () => {
  const resources: [string, string][] = [
    ['/vehicles', 'vehicles'],
    ['/fuel', 'fuel'],
    ['/services', 'services'],
    ['/costs', 'costs'],
    ['/readings', 'readings'],
    ['/trips', 'trips'],
    ['/income', 'income'],
    ['/due', 'due'],
  ]

  for (const [path, key] of resources) {
    const { handler } = handlerWith()
    const response = await handler(get(path))
    assertEquals(response.status, 200, `${path} should be served`)
    assertEquals(
      Object.hasOwn(await response.json(), key),
      true,
      `${path} should answer under "${key}"`,
    )
  }
})

Deno.test('an unknown resource says which one it did not know', async () => {
  const { handler } = handlerWith()

  const response = await handler(get('/spaceships'))

  assertEquals(response.status, 404)
  assertEquals(await response.json(), { error: 'unknown resource: spaceships' })
})

Deno.test('a database error is reported as a server error, not as empty data', async () => {
  const { handler } = handlerWith({
    tables: { fuel_entries: () => ({ error: { message: 'connection lost' } }) },
  })

  const response = await handler(get('/fuel'))

  assertEquals(response.status, 500)
  assertEquals(await response.json(), { error: 'connection lost' })
})

Deno.test('nothing served is cacheable', async () => {
  const { handler } = handlerWith()

  const response = await handler(get('/vehicles'))

  assertEquals(response.headers.get('Cache-Control'), 'no-store')
})
