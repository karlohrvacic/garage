import { createClient } from 'jsr:@supabase/supabase-js@2'

// A household's read-only API, for the owner's own automation: a Home
// Assistant dashboard, a script that pages when something is overdue.
//
// Authentication is a key the household issued to itself in the app, presented
// as `Authorization: Bearer grg_…`. The key is matched by SHA-256 hash, which
// resolves to exactly one household; everything served afterwards is scoped to
// that household's vehicles. Nothing here writes.

const corsHeaders = {
  'Cache-Control': 'no-store',
  // The API is meant to be called from a home server or a script, and the
  // key is the credential, so a browser origin is not a security boundary.
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  })

/// The preflight answer, which must carry no body at all.
///
/// This used to be `json({}, 204)`, and a 204 may not have one: constructing
/// that Response throws `TypeError: Response with null body status cannot have
/// body`, so every preflight failed inside the handler rather than returning
/// anything. It went unnoticed because the documented consumers are scripts
/// and home servers, which never send one — but the CORS headers above exist
/// precisely so a browser can call this, and until now no browser could.
const noContent = () =>
  new Response(null, { status: 204, headers: corsHeaders })

// deno-lint-ignore no-explicit-any
export type ClientFactory = (url: string, key: string, options?: any) => any

export interface Deps {
  createClient: ClientFactory
}

/// The resource named by a request path.
///
/// Supabase serves this at `/functions/v1/public-api/…`, so everything up to
/// and including the function name is dropped rather than matched from the
/// start of the path — the same handler has to answer on a bare `/public-api`
/// locally and on the full gateway path in production.
export function resourceFromPath(pathname: string): string {
  return pathname
    .split('/public-api')
    .pop()!
    .replace(/^\/+/, '')
    .replace(/\/+$/, '')
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  )
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

export function makeHandler(deps: Deps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') {
      return noContent()
    }
    if (req.method !== 'GET') {
      return json({ error: 'method not allowed' }, 405)
    }

    const presented = req.headers.get('Authorization')?.replace(/^Bearer /i, '')
    if (!presented) {
      return json({ error: 'missing api key' }, 401)
    }

    const admin = deps.createClient(
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
      .select(
        'id, nickname, make, model, year, plate, fuel_type_key, ' +
          'secondary_fuel_type_key, archived',
      )
      .eq('household_id', householdId)
    if (vehicleError) {
      return json({ error: vehicleError.message }, 500)
    }
    // Annotated because the client arrives through `deps` and is deliberately
    // untyped there; the real client would have inferred this.
    const vehicleIds = ((vehicles ?? []) as { id: string }[]).map(
      (vehicle) => vehicle.id,
    )

    // The path after the function name picks the resource.
    const path = resourceFromPath(new URL(req.url).pathname)

    switch (path) {
      case '':
        return json({
          household: householdId,
          resources: [
            'vehicles',
            'fuel',
            'services',
            'costs',
            'readings',
            'trips',
            'income',
            'due',
          ],
        })

      case 'vehicles':
        return json({ vehicles })

      case 'fuel': {
        const { data, error } = await admin
          .from('fuel_entries')
          .select(
            'id, vehicle_id, entry_date, odometer_km, volume_l, price_per_l, ' +
              'total, full_tank, missed_fill, fuel_type_key, station',
          )
          .in('vehicle_id', vehicleIds)
          .order('entry_date', { ascending: false })
          .limit(500)
        return error
          ? json({ error: error.message }, 500)
          : json({ fuel: data })
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
        return error
          ? json({ error: error.message }, 500)
          : json({ costs: data })
      }

      case 'readings': {
        const { data, error } = await admin
          .from('odometer_entries')
          .select('id, vehicle_id, entry_date, odometer_km, notes')
          .in('vehicle_id', vehicleIds)
          .order('entry_date', { ascending: false })
          .limit(500)
        return error
          ? json({ error: error.message }, 500)
          : json({ readings: data })
      }

      case 'trips': {
        const { data, error } = await admin
          .from('trip_entries')
          .select(
            'id, vehicle_id, entry_date, title, from_place, to_place, ' +
              'distance_km, start_odometer_km, end_odometer_km, minutes, purpose',
          )
          .in('vehicle_id', vehicleIds)
          .order('entry_date', { ascending: false })
          .limit(500)
        return error
          ? json({ error: error.message }, 500)
          : json({ trips: data })
      }

      case 'income': {
        const { data, error } = await admin
          .from('income_entries')
          .select('id, vehicle_id, entry_date, category, amount, odometer_km')
          .in('vehicle_id', vehicleIds)
          .order('entry_date', { ascending: false })
          .limit(500)
        return error
          ? json({ error: error.message }, 500)
          : json({ income: data })
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
  }
}

export const handler = makeHandler({ createClient })
