// A stand-in for the Supabase client, good enough for the four edge functions
// and no more.
//
// The real client is a builder: `from(t).select(c).eq(a, b).limit(1)` returns
// something awaitable. The functions under test use a dozen of those methods
// and care only about the rows that come back, so this records the calls and
// answers with whatever the test set up.
//
// Directories under `functions/` whose name starts with `_` are not deployed
// as functions, which is why this one is named the way it is.

export interface RecordedQuery {
  table: string
  select?: string
  filters: { method: string; args: unknown[] }[]
  operation: 'select' | 'update' | 'delete' | 'insert'
  payload?: unknown
}

export interface FakeConfig {
  /// Rows to answer with, by table. A function receives the recorded query, so
  /// a test can answer differently depending on what was asked.
  tables?: Record<
    string,
    | unknown[]
    | ((query: RecordedQuery) => unknown[] | { error: { message: string } })
  >
  /// Results for `rpc(name, params)`.
  rpc?: Record<string, unknown | { error: { message: string } }>
  /// What `auth.getUser()` resolves to.
  user?: { id: string } | null
  /// An error for `auth.admin.deleteUser`.
  deleteUserError?: { message: string } | null
}

export interface FakeClient {
  // deno-lint-ignore no-explicit-any
  from: (table: string) => any
  // deno-lint-ignore no-explicit-any
  rpc: (name: string, params?: unknown) => any
  auth: {
    getUser: () => Promise<{ data: { user: unknown }; error: unknown }>
    admin: { deleteUser: (id: string) => Promise<{ error: unknown }> }
  }
  /// Every query the code under test ran, in order.
  queries: RecordedQuery[]
  /// Every `rpc` call, in order.
  rpcCalls: { name: string; params?: unknown }[]
  /// The ids passed to `auth.admin.deleteUser`.
  deletedUsers: string[]
}

/// Chainable filter methods. Each records itself and returns the builder, so
/// the shape of a query can be asserted without a database.
const CHAINABLE = [
  'select',
  'eq',
  'in',
  'not',
  'contains',
  'order',
  'limit',
  'gte',
  'lte',
  'neq',
]

export function fakeClient(config: FakeConfig = {}): FakeClient {
  const queries: RecordedQuery[] = []
  const rpcCalls: { name: string; params?: unknown }[] = []
  const deletedUsers: string[] = []

  function resolve(query: RecordedQuery) {
    const source = config.tables?.[query.table]
    if (source === undefined) {
      return { data: [], error: null }
    }
    const rows = typeof source === 'function' ? source(query) : source
    if (rows && !Array.isArray(rows) && 'error' in rows) {
      return { data: null, error: rows.error }
    }
    return { data: rows, error: null }
  }

  function builder(query: RecordedQuery) {
    // deno-lint-ignore no-explicit-any
    const self: any = {
      then: (
        // deno-lint-ignore no-explicit-any
        onFulfilled: (value: any) => unknown,
        // deno-lint-ignore no-explicit-any
        onRejected?: (reason: any) => unknown,
      ) => Promise.resolve(resolve(query)).then(onFulfilled, onRejected),
      maybeSingle: () => {
        const { data, error } = resolve(query)
        const rows = data as unknown[] | null
        return Promise.resolve({
          data: rows && rows.length > 0 ? rows[0] : null,
          error,
        })
      },
      single: () => {
        const { data, error } = resolve(query)
        const rows = data as unknown[] | null
        return Promise.resolve({
          data: rows && rows.length > 0 ? rows[0] : null,
          error,
        })
      },
    }
    for (const method of CHAINABLE) {
      self[method] = (...args: unknown[]) => {
        if (method === 'select') {
          query.select = args[0] as string
        }
        query.filters.push({ method, args })
        return self
      }
    }
    for (const method of ['update', 'delete', 'insert'] as const) {
      self[method] = (payload?: unknown) => {
        query.operation = method
        query.payload = payload
        return self
      }
    }
    return self
  }

  return {
    from(table: string) {
      const query: RecordedQuery = { table, filters: [], operation: 'select' }
      queries.push(query)
      return builder(query)
    },
    rpc(name: string, params?: unknown) {
      rpcCalls.push({ name, params })
      const result = config.rpc?.[name]
      if (result && typeof result === 'object' && 'error' in result) {
        return Promise.resolve({
          data: null,
          error: (result as { error: unknown }).error,
        })
      }
      return Promise.resolve({ data: result ?? null, error: null })
    },
    auth: {
      getUser: () =>
        Promise.resolve({
          data: { user: config.user ?? null },
          error: config.user ? null : { message: 'invalid token' },
        }),
      admin: {
        deleteUser: (id: string) => {
          deletedUsers.push(id)
          return Promise.resolve({ error: config.deleteUserError ?? null })
        },
      },
    },
    queries,
    rpcCalls,
    deletedUsers,
  }
}

/// The environment the functions read. Set once per test file.
export function stubEnv(
  values: Record<string, string> = {},
): void {
  const defaults: Record<string, string> = {
    SUPABASE_URL: 'http://localhost:54321',
    SUPABASE_ANON_KEY: 'anon-key',
    SUPABASE_SERVICE_ROLE_KEY: 'service-key',
  }
  for (const [key, value] of Object.entries({ ...defaults, ...values })) {
    Deno.env.set(key, value)
  }
}
