import { createClient } from 'jsr:@supabase/supabase-js@2'

// Deleting the auth user cascades through every table in the schema: rows are
// keyed to auth.users, and a household whose last member leaves is removed by
// the household_members_cleanup trigger. This function exists because that
// delete requires the service role, which must never reach a client.
//
// The logic lives here rather than in `index.ts` so it can be imported without
// starting a server. `index.ts` is the entry point and does nothing else.

// deno-lint-ignore no-explicit-any
export type ClientFactory = (url: string, key: string, options?: any) => any

export interface Deps {
  createClient: ClientFactory
}

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })

export function makeHandler(deps: Deps) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 })
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return json({ error: 'missing authorization' }, 401)
    }

    const url = Deno.env.get('SUPABASE_URL')!

    // Identify the caller from their own token — never from the request body,
    // which would let anyone delete anyone.
    const caller = deps.createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: { user }, error: userError } = await caller.auth.getUser()

    if (userError || !user) {
      return json({ error: 'invalid token' }, 401)
    }

    const admin = deps.createClient(
      url,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )
    const { error } = await admin.auth.admin.deleteUser(user.id)

    if (error) {
      return json({ error: error.message }, 500)
    }

    return json({ deleted: true }, 200)
  }
}

export const handler = makeHandler({ createClient })
