import { createClient } from 'jsr:@supabase/supabase-js@2'

// A household's read-only API, for the owner's own automation: a Home
// Assistant dashboard, a script that pages when something is overdue.
//
// Authentication is a key the household issued to itself in the app, presented
// as `Authorization: Bearer grg_…`. The key is matched by SHA-256 hash, which
// resolves to exactly one household; everything served afterwards is scoped to
// that household's vehicles. Nothing here writes.

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      // The API is meant to be called from a home server or a script, and the
      // key is the credential, so a browser origin is not a security boundary.
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, content-type',
    },
  })

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  )
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return json({}, 204)
  }
  if (req.method !== 'GET') {
    return json({ error: 'method not allowed' }, 405)
  }

  const presented = req.headers.get('Authorization')?.replace(/^Bearer /i, '')
  if (!presented) {
    return json({ error: 'missing api key' }, 401)
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const { data: householdId, error: keyError } = await admin.rpc(
    'household_for_api_key',
    { key_hash_input: await sha256Hex(presented) },
  )
  if (keyError || !householdId) {
    return json({ error: 'invalid api key' }, 401)
  }

  const { data: vehicles, error: vehicleError } = await admin
    .from('vehicles')
    .select('id, nickname, make, model, year, plate, fuel_type_key, archived')
    .eq('household_id', householdId)
  if (vehicleError) {
    return json({ error: vehicleError.message }, 500)
  }
  const vehicleIds = (vehicles ?? []).map((vehicle) => vehicle.id)

  // The path after the function name picks the resource. Supabase serves this
  // at /functions/v1/public-api/…, so anything up to and including the
  // function name is dropped rather than matched from the start of the path.
  const path = new URL(req.url).pathname
    .split('/public-api')
    .pop()!
    .replace(/^\/+/, '')
    .replace(/\/+$/, '')

  switch (path) {
    case '':
      return json({
        household: householdId,
        resources: ['vehicles', 'fuel', 'services', 'costs', 'due'],
      })

    case 'vehicles':
      return json({ vehicles })

    case 'fuel': {
      const { data, error } = await admin
        .from('fuel_entries')
        .select(
          'id, vehicle_id, entry_date, odometer_km, volume_l, price_per_l, ' +
            'total, full_tank, missed_fill, station',
        )
        .in('vehicle_id', vehicleIds)
        .order('entry_date', { ascending: false })
        .limit(500)
      return error ? json({ error: error.message }, 500) : json({ fuel: data })
    }

    case 'services': {
      const { data, error } = await admin
        .from('service_entries')
        .select(
          'id, vehicle_id, entry_date, odometer_km, service_type_keys, cost, shop',
        )
        .in('vehicle_id', vehicleIds)
        .order('entry_date', { ascending: false })
        .limit(500)
      return error
        ? json({ error: error.message }, 500)
        : json({ services: data })
    }

    case 'costs': {
      const { data, error } = await admin
        .from('cost_entries')
        .select('id, vehicle_id, entry_date, category, amount, odometer_km')
        .in('vehicle_id', vehicleIds)
        .order('entry_date', { ascending: false })
        .limit(500)
      return error ? json({ error: error.message }, 500) : json({ costs: data })
    }

    case 'due': {
      // The rules as stored, not projected: projection needs the driving rate
      // the app computes, and a consumer of this API wants the raw schedule.
      const { data, error } = await admin
        .from('reminder_rules')
        .select(
          'id, vehicle_id, service_type_key, interval_km, interval_months, ' +
            'one_time, due_date, due_odometer_km, active',
        )
        .in('vehicle_id', vehicleIds)
        .eq('active', true)
      return error ? json({ error: error.message }, 500) : json({ due: data })
    }

    default:
      return json({ error: `unknown resource: ${path}` }, 404)
  }
})
