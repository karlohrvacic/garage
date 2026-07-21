import { createClient } from 'jsr:@supabase/supabase-js@2'

// Deleting the auth user cascades through every table in the schema: rows are
// keyed to auth.users, and a household whose last member leaves is removed by
// the household_members_cleanup trigger. This function exists because that
// delete requires the service role, which must never reach a client.
Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'missing authorization' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const url = Deno.env.get('SUPABASE_URL')!

  // Identify the caller from their own token — never from the request body,
  // which would let anyone delete anyone.
  const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: { user }, error: userError } = await caller.auth.getUser()

  if (userError || !user) {
    return new Response(JSON.stringify({ error: 'invalid token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const { error } = await admin.auth.admin.deleteUser(user.id)

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ deleted: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})
