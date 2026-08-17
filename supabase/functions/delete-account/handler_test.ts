import { assertEquals } from 'jsr:@std/assert@1'
import { makeHandler } from './handler.ts'
import { fakeClient, stubEnv } from '../_test/fake_supabase.ts'

stubEnv()

/// The caller's own token is the only thing that decides whose account goes.
/// Everything below is a variation on that one rule.
function handlerWith(config: Parameters<typeof fakeClient>[0]) {
  const client = fakeClient(config)
  return { handler: makeHandler({ createClient: () => client }), client }
}

const post = (headers: Record<string, string> = {}) =>
  new Request('http://localhost/delete-account', { method: 'POST', headers })

Deno.test('only POST deletes anything', async () => {
  const { handler, client } = handlerWith({ user: { id: 'u1' } })

  const response = await handler(
    new Request('http://localhost/delete-account', { method: 'GET' }),
  )

  assertEquals(response.status, 405)
  assertEquals(client.deletedUsers, [])
})

Deno.test('a request with no Authorization header is refused', async () => {
  const { handler, client } = handlerWith({ user: { id: 'u1' } })

  const response = await handler(post())

  assertEquals(response.status, 401)
  assertEquals(await response.json(), { error: 'missing authorization' })
  assertEquals(client.deletedUsers, [])
})

Deno.test('a token the server cannot resolve to a user is refused', async () => {
  const { handler, client } = handlerWith({ user: null })

  const response = await handler(post({ Authorization: 'Bearer nonsense' }))

  assertEquals(response.status, 401)
  assertEquals(await response.json(), { error: 'invalid token' })
  assertEquals(
    client.deletedUsers,
    [],
    'a rejected token must not reach the admin client',
  )
})

Deno.test('the account deleted is the caller own, never one named in the body', async () => {
  const { handler, client } = handlerWith({ user: { id: 'caller-id' } })

  const response = await handler(
    new Request('http://localhost/delete-account', {
      method: 'POST',
      headers: { Authorization: 'Bearer good' },
      body: JSON.stringify({ user_id: 'somebody-else' }),
    }),
  )

  assertEquals(response.status, 200)
  assertEquals(await response.json(), { deleted: true })
  // The whole security property of this function in one assertion: the id
  // comes from the verified token, so a body claiming to be someone else is
  // ignored rather than obeyed.
  assertEquals(client.deletedUsers, ['caller-id'])
})

Deno.test('a failure to delete is reported, not swallowed', async () => {
  const { handler } = handlerWith({
    user: { id: 'u1' },
    deleteUserError: { message: 'user is referenced elsewhere' },
  })

  const response = await handler(post({ Authorization: 'Bearer good' }))

  assertEquals(response.status, 500)
  assertEquals(await response.json(), {
    error: 'user is referenced elsewhere',
  })
})
