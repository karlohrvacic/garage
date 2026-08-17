import { createClient } from 'jsr:@supabase/supabase-js@2'

// Fans a database change out to whatever URLs the household has registered.
//
// Wired by trigger on insert into every entry table: the row is posted here,
// this resolves which household it belongs to, and calls that household's
// hooks. A table missing from `entryKinds` below is silently ignored, which is
// why adding an entry kind means adding it in three places — the trigger, this
// map, and the realtime publication.
//
// Delivery is best-effort and one attempt: a home dashboard that missed a
// notification can read the same data from the API, and retry storms are worse
// than a missed ping. Every call is signed, so a receiver can tell a real one
// from anything else that finds its URL.
//
// The logic lives here rather than in `index.ts` so it can be imported without
// starting a server.

export interface DatabaseWebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE'
  table: string
  record: Record<string, unknown> | null
  old_record: Record<string, unknown> | null
}

export const entryKinds: Record<string, string> = {
  fuel_entries: 'fuel',
  service_entries: 'service',
  cost_entries: 'cost',
  odometer_entries: 'odometer',
  trip_entries: 'trip',
  income_entries: 'income',
}

// deno-lint-ignore no-explicit-any
export type ClientFactory = (url: string, key: string, options?: any) => any

export interface Deps {
  createClient: ClientFactory
  fetch: typeof fetch
  /// Injected so a test can assert the timestamp it produced.
  now: () => Date
}

export async function sign(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(body),
  )
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

const delivered = (count: number) =>
  new Response(JSON.stringify({ delivered: count }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })

interface Hook {
  id: string
  url: string
  secret: string
  events: string[]
}

export function makeHandler(deps: Deps) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 })
    }

    const payload = (await req.json()) as DatabaseWebhookPayload
    const entryKind = entryKinds[payload.table]
    if (payload.type !== 'INSERT' || !entryKind || !payload.record) {
      return delivered(0)
    }

    const admin = deps.createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // The row names a vehicle; the vehicle names the household whose hooks to
    // call. Anything else would leak one household's activity to another.
    const vehicleId = payload.record.vehicle_id as string | undefined
    if (!vehicleId) {
      return delivered(0)
    }

    const { data: vehicle } = await admin
      .from('vehicles')
      .select('household_id')
      .eq('id', vehicleId)
      .maybeSingle()
    if (!vehicle) {
      return delivered(0)
    }

    const { data: hooks } = await admin
      .from('webhooks')
      .select('id, url, secret, events')
      .eq('household_id', vehicle.household_id)
      .eq('active', true)

    const body = JSON.stringify({
      event: 'entry.created',
      kind: entryKind,
      vehicle_id: vehicleId,
      entry: payload.record,
      at: deps.now().toISOString(),
    })

    let count = 0
    for (const hook of ((hooks ?? []) as Hook[])) {
      if (!hook.events.includes('entry.created')) {
        continue
      }
      let status = 0
      try {
        const response = await deps.fetch(hook.url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Garage-Event': 'entry.created',
            'X-Garage-Signature': await sign(hook.secret, body),
          },
          body,
          signal: AbortSignal.timeout(10_000),
        })
        status = response.status
        if (response.ok) {
          count++
        }
      } catch {
        // A home server that is off, or a URL that no longer resolves.
        // Recorded below so the household can see the hook failing in the app.
        status = 0
      }
      await admin
        .from('webhooks')
        .update({
          last_delivery_at: deps.now().toISOString(),
          last_delivery_status: status,
        })
        .eq('id', hook.id)
    }

    return delivered(count)
  }
}

export const handler = makeHandler({
  createClient,
  fetch: globalThis.fetch,
  now: () => new Date(),
})
