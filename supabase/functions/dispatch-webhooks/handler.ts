import { createClient } from 'jsr:@supabase/supabase-js@2'
import { chatMessage, unitsFrom } from './chat_message.ts'
import { deliver, type Hook, HOOK_COLUMNS } from '../_shared/webhooks.ts'
import {
  type ClosingSpan,
  closingSpan,
  fuelRowFrom,
  fuelRowsFrom,
  HISTORY_LIMIT,
} from './economy.ts'

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
// from anything else that finds its URL. Both are `_shared/webhooks.ts`, which
// the daily reminder run delivers through as well.
//
// What is sent says more than the row does. The row is canonical and terse —
// a vehicle id, litres, a category key — and the two things a receiver most
// wants are not on it at all: which car that is, and what the tank worked out
// to. Both are looked up here, after it is known that somebody is listening.
//
// And what arrives is not believed. The trigger calls this function with the
// project's anon key (migration 0025), which ships in every copy of the app,
// so a request proves nothing about who sent it: anybody who knows a vehicle's
// id can post an INSERT that never happened. What they cannot do is write to
// the table. So a payload is allowed to *name* a row — which table, which id,
// which vehicle — and everything that is sent is read back from the table
// with the service-role client. A forgery can then say nothing of its own; the
// most it can do is have a real row announced a second time.
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

const delivered = (count: number) =>
  new Response(JSON.stringify({ delivered: count }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })

interface Vehicle {
  household_id: string
  nickname?: string | null
  fuel_type_key?: string | null
  secondary_fuel_type_key?: string | null
}

/// Everything looked up through this is decoration on a notification that
/// used to arrive without it, so none of it may be the reason one does not:
/// a lookup that fails or throws leaves its part of the message out.
async function optional<T>(lookup: () => PromiseLike<T>): Promise<T | null> {
  try {
    return await lookup()
  } catch {
    return null
  }
}

/// The row a payload names, as the table holds it — or null, and then nothing
/// is sent.
///
/// The opposite of [optional], on purpose. Those lookups are decoration, and a
/// failure leaves them out. This one is the evidence: without it all that is
/// left is the payload's word, and falling back to that would make "cause the
/// read to fail" a way of being believed. A notification missed because the
/// database blinked can be read from the API; a forged one cannot be unsent.
async function storedRow(
  // deno-lint-ignore no-explicit-any
  admin: any,
  table: string,
  id: string,
): Promise<Record<string, unknown> | null> {
  try {
    const { data } = await admin
      .from(table)
      .select('*')
      .eq('id', id)
      .maybeSingle()
    return (data as Record<string, unknown> | null) ?? null
  } catch {
    return null
  }
}

const FUEL_COLUMNS =
  'id, entry_date, odometer_km, volume_l, full_tank, missed_fill, ' +
  'fuel_type_key'

/// The span the new fill-up closed, by the app's own full-tank rule — see
/// `economy.ts` for the rule and for what keeps it honest.
async function spanClosedBy(
  // deno-lint-ignore no-explicit-any
  admin: any,
  vehicleId: string,
  vehicle: Vehicle,
  entry: Record<string, unknown>,
): Promise<ClosingSpan | null> {
  const closing = fuelRowFrom(entry)
  // A partial fill closes nothing, and neither does one that admits to a gap
  // before it. Most of what is asked below is asked to find that out, so it
  // is not asked.
  if (!closing || !closing.full_tank || closing.missed_fill) {
    return null
  }

  // Nearest first, and cut off: a span is a handful of rows and a log is
  // years of them. The order is the chain's own, reversed — including a
  // partial fill before a full one at the same reading on the same day — so
  // what the limit drops is always the farthest row. It can cost a very long
  // span its opening tank, which reads as no figure; it cannot drop a fill
  // from inside a span and leave a flattering one.
  const { data } = await admin
    .from('fuel_entries')
    .select(FUEL_COLUMNS)
    .eq('vehicle_id', vehicleId)
    // The trigger fires after the insert, so the new row is already there.
    .neq('id', closing.id)
    // Nothing past the new reading can be part of a span that ends at it.
    .lte('odometer_km', closing.odometer_km)
    .order('odometer_km', { ascending: false })
    .order('entry_date', { ascending: false })
    .order('full_tank', { ascending: true })
    .limit(HISTORY_LIMIT)
  // No rows is a history; no answer is not, and neither is one that cannot
  // be read.
  const earlier = data && fuelRowsFrom(data)
  if (!earlier) {
    return null
  }

  // The app names a main fuel only for a car that takes two
  // (`economyPointsProvider`), and an unnamed fill joins a chain or stands
  // apart depending on it. Handing over anything else here would split the
  // same log differently and the two figures would part ways.
  const primaryFuelKey = vehicle.secondary_fuel_type_key != null
    ? vehicle.fuel_type_key ?? null
    : null
  return closingSpan(closing, earlier, primaryFuelKey)
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
    // These two ids, and the table, are all a payload is ever taken at its
    // word for — and the word is checked below.
    const { id: entryId, vehicle_id: vehicleId } = payload.record
    if (typeof entryId !== 'string' || typeof vehicleId !== 'string') {
      return delivered(0)
    }

    // The vehicle's fuels come along with the household: they decide which
    // chain a fill-up belongs to and whether it was litres or kilowatt-hours.
    const { data: vehicle } = await admin
      .from('vehicles')
      .select('household_id, nickname, fuel_type_key, secondary_fuel_type_key')
      .eq('id', vehicleId)
      .maybeSingle() as { data: Vehicle | null }
    if (!vehicle) {
      return delivered(0)
    }

    const { data: hooks } = await admin
      .from('webhooks')
      .select(HOOK_COLUMNS)
      .eq('household_id', vehicle.household_id)
      .eq('active', true)
    const subscribed = ((hooks ?? []) as Hook[]).filter((hook) =>
      hook.events.includes('entry.created')
    )
    // Most households have no webhook, and every entry any of them logs comes
    // through here. Nothing below is worth asking for on their behalf.
    if (subscribed.length === 0) {
      return delivered(0)
    }

    // Read back rather than believed, and only now: a household with no hook
    // costs no read. The vehicle has to match as well as the id. The hooks
    // above belong to the vehicle the payload named, the row is whatever the
    // id names, and if the two could differ anybody could have one household's
    // fill-ups delivered to another household's chat — their own, say.
    const entry = await storedRow(admin, payload.table, entryId)
    if (!entry || entry.vehicle_id !== vehicleId) {
      return delivered(0)
    }

    const [household, author, economy] = await Promise.all([
      optional(async () => {
        const { data } = await admin
          .from('households')
          .select('currency_code, distance_unit, volume_unit')
          .eq('id', vehicle.household_id)
          .maybeSingle()
        return data as Record<string, unknown> | null
      }),
      // Who typed the row, which is what `created_by` records. A trip's
      // driver is somebody else and is on the row already.
      optional(async () => {
        if (typeof entry.created_by !== 'string') {
          return null
        }
        const { data } = await admin
          .from('profiles')
          .select('display_name')
          .eq('user_id', entry.created_by)
          .maybeSingle()
        return (data?.display_name as string | undefined) ?? null
      }),
      entryKind === 'fuel'
        ? optional(() => spanClosedBy(admin, vehicleId, vehicle, entry))
        : null,
    ])
    const units = unitsFrom(household)

    const body = JSON.stringify({
      event: 'entry.created',
      kind: entryKind,
      vehicle_id: vehicleId,
      entry,
      at: deps.now().toISOString(),
      // Everything from here down was added later, and added after: a
      // receiver written against the five keys above must not notice.
      vehicle_name: vehicle.nickname ?? null,
      currency: units.currency,
      // Canonical like the row beside it, whatever the household reads:
      // litres per 100 km — kilowatt-hours for an electric car — over
      // kilometres. Only a fill-up has the key at all.
      ...(entryKind === 'fuel' && {
        economy: economy && {
          l_per_100km: economy.litresPer100Km,
          distance_km: economy.distanceKm,
          volume_l: economy.volumeL,
        },
      }),
    })
    const message = chatMessage(entryKind, entry, {
      vehicleName: vehicle.nickname ?? null,
      author,
      units,
      // The fuel that went in, not the car's main one: a plug-in charge on a
      // car that also takes petrol is still kilowatt-hours.
      electric: (entry.fuel_type_key ?? vehicle.fuel_type_key) ===
        'fuel_electric',
      economy,
    })

    const count = await deliver(
      { admin, fetch: deps.fetch, now: deps.now },
      'entry.created',
      subscribed,
      body,
      message,
    )

    return delivered(count)
  }
}

export const handler = makeHandler({
  createClient,
  fetch: globalThis.fetch,
  now: () => new Date(),
})
