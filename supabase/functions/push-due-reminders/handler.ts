import { createClient } from 'jsr:@supabase/supabase-js@2'
import { deliver, type Hook, HOOK_COLUMNS } from '../_shared/webhooks.ts'
import {
  REMINDER_EVENT,
  reminderBody,
  type ReminderDue,
  reminderMessage,
} from './reminder_event.ts'
import {
  nextSeasonalSwap,
  SEASONAL_SWAP_KEY,
  type SwapDirection,
  swapsSeasonally,
} from './winter_tyre_period.ts'

// Daily push for maintenance items entering their due window. Run by
// pg_cron/scheduler with the service role (see docs/RUNBOOK-push.md); it is
// deliberately simpler than the client's projector: time-interval rules
// project exactly, distance-interval rules approximate with the same
// 30 km/day fallback the client uses when history is thin, counted from the
// day of the reading they are projected from. A one-off goes by its own date,
// its own odometer by the same estimate, or whichever of the two comes first.
//
// A reminder is pushed when its projected due date is exactly one of
// REMINDER_LEAD_DAYS away — running once per day makes those single-shot
// notifications without any bookkeeping table. That holds only while the date
// stands still between runs, which is why a distance date is not counted from
// the day of the run. A new reading can still move it, onto a lead day or past
// one.
//
// Two nudges: a month out to arrange a garage visit, a week out to keep it.
// Seven days alone was too little to get an appointment. The same two days the
// app schedules its own reminders with (`notificationLeadDays`), because a
// household hearing about one oil change on four different days is being
// nagged by two halves of one feature rather than reminded.
// `test/ci/entry_kinds_wired_test.dart` fails if the two lists drift apart.
//
// The same run sends the `reminder.due` webhook event, about the same visits
// on the same days (`reminder_event.ts`). Firebase is needed for the pushes
// and for nothing else: the hooks are called first, and a project without the
// FCM secret still calls them and then skips the pushes, where it used to
// refuse the whole run before reading a rule.

/// The Supabase client, structurally. Typing the query builder properly would
/// be a page of noise for no gain, and the real types are lost anyway once the
/// client arrives through `Deps` rather than from `createClient` directly.
// deno-lint-ignore no-explicit-any
export type SupabaseLike = any

export type ClientFactory = (
  url: string,
  key: string,
  options?: SupabaseLike,
) => SupabaseLike

export interface Deps {
  createClient: ClientFactory
  fetch: typeof fetch
  /// Today, injected so a test can stand at a fixed distance from a due date
  /// instead of computing one relative to whenever it happens to run.
  now: () => Date
  /// Exchanging a service-account key for an FCM token needs RSA signing and a
  /// round trip to Google. Injected so neither happens in a unit test.
  fcmAccessToken: (serviceAccount: {
    client_email: string
    private_key: string
  }) => Promise<string>
}

export const FALLBACK_KM_PER_DAY = 30
export const REMINDER_LEAD_DAYS = [30, 7]

export interface Rule {
  id: string
  vehicle_id: string
  service_type_key: string
  interval_km: number | null
  interval_months: number | null
  // A dated one-off: a vignette running out, or registration and insurance
  // falling due again a year after they were paid. Both intervals are null on
  // these, so projecting from a past service finds nothing and they were
  // skipped entirely — the reminders most worth pushing were the ones that
  // never pushed.
  one_time: boolean
  due_date: string | null
  // A one-off due at an odometer rather than on a date: a timing belt good for
  // so many kilometres, a first service at 1,000. Never read until September
  // 2026, so none of these was ever pushed either.
  due_odometer_km: number | null
}

interface VehicleRow {
  id: string
  nickname: string
  household_id: string
}

interface MemberRow {
  household_id: string
  user_id: string
}

interface TokenRow {
  token: string
  user_id: string
}

interface GarageHook extends Hook {
  household_id: string
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })

/// Whether a bearer token is a service-role one.
///
/// The token's signature is verified by the platform ahead of this function;
/// what is left to decide is which role it carries, and an anon token — which
/// every copy of the app holds — must not be able to make the project send
/// notifications to everybody.
export function isServiceRole(authorization: string | null): boolean {
  const token = (authorization ?? '').replace(/^Bearer /i, '').trim()
  const injected = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (injected && token === injected) {
    return true
  }
  const payload = token.split('.')[1]
  if (!payload) {
    return false
  }
  try {
    const decoded = JSON.parse(
      atob(payload.replace(/-/g, '+').replace(/_/g, '/')),
    )
    return decoded.role === 'service_role'
  } catch {
    return false
  }
}

/// The calendar day a date falls on, which is what the whole log is ordered by
/// and what the device derives a notification's identity from.
export function isoDay(date: Date): string {
  return date.toISOString().split('T')[0]
}

export function dayDiff(from: Date, to: Date): number {
  const a = Date.UTC(
    from.getUTCFullYear(),
    from.getUTCMonth(),
    from.getUTCDate(),
  )
  const b = Date.UTC(to.getUTCFullYear(), to.getUTCMonth(), to.getUTCDate())
  return Math.round((b - a) / 86_400_000)
}

export function addMonths(date: Date, months: number): Date {
  const result = new Date(date)
  result.setUTCMonth(result.getUTCMonth() + months)
  return result
}

export async function fcmAccessToken(serviceAccount: {
  client_email: string
  private_key: string
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const claims = btoa(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  )
  const unsigned = `${header}.${claims}`
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '')

  const pem = serviceAccount.private_key
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replaceAll('\n', '')
  const keyData = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0))
  const key = await crypto.subtle.importKey(
    'pkcs8',
    keyData,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  )
  const encodedSignature = btoa(
    String.fromCharCode(...new Uint8Array(signature)),
  )
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '')
  const jwt = `${unsigned}.${encodedSignature}`

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  const json = await response.json()
  if (!response.ok) {
    throw new Error(`token exchange failed: ${JSON.stringify(json)}`)
  }
  return json.access_token as string
}

/// Every table that records where the odometer stood, and the column it keeps
/// it in. Each of them dates the row in `entry_date`.
///
/// All of them, not just fill-ups: a household that logs readings without
/// buying fuel — an EV, or anyone who has stopped recording fill-ups — would
/// otherwise have every distance-based reminder projected from an odometer
/// that stopped moving. This mirrors `OdometerHistory` in the app, which is
/// where the same rule is written for the screens.
export const ODOMETER_SOURCES: [string, string][] = [
  ['fuel_entries', 'odometer_km'],
  ['service_entries', 'odometer_km'],
  ['cost_entries', 'odometer_km'],
  ['odometer_entries', 'odometer_km'],
  ['trip_entries', 'end_odometer_km'],
  ['income_entries', 'odometer_km'],
]

/// Where a vehicle's odometer stood, and on which day.
export interface OdometerReading {
  km: number
  /// `YYYY-MM-DD`.
  day: string
}

/// Whichever of two readings is further along: the higher, and of two at the
/// same odometer, the later. A car still at 64,790 km on the 16th has not moved
/// since it read that on the 11th, and the days it stood still are not days it
/// drove.
///
/// The higher rather than the more recent: an odometer only goes up, so a
/// lower later number is a typo, and reading it as current would push every
/// reminder out by the size of the mistake.
export function furthestReading(
  current: OdometerReading | null,
  candidate: OdometerReading,
): OdometerReading {
  if (current === null || candidate.km > current.km) {
    return candidate
  }
  if (candidate.km === current.km && candidate.day > current.day) {
    return candidate
  }
  return current
}

/// The furthest reading any source has for a vehicle as of [today], or null
/// when it has none — or when none could be read.
///
/// Two rules come from the app's `OdometerHistory`. The odometer the owner
/// gave when the car was added counts, so the car is never taken to be below
/// it. And nothing dated after today counts: a year typed as 2062 would
/// otherwise decide both where the car stands and the day it stood there, and
/// put every distance date decades out.
export async function currentOdometer(
  admin: SupabaseLike,
  vehicleId: string,
  today: Date,
): Promise<OdometerReading | null> {
  const asOf = isoDay(today)
  let current: OdometerReading | null = null
  const consider = (km: unknown, day: unknown) => {
    if (typeof km === 'number' && typeof day === 'string' && day <= asOf) {
      current = furthestReading(current, { km, day })
    }
  }

  const { data: vehicle } = await admin
    .from('vehicles')
    .select('baseline_odometer_km, baseline_date')
    .eq('id', vehicleId)
    .maybeSingle()
  consider(vehicle?.baseline_odometer_km, vehicle?.baseline_date)

  for (const [table, column] of ODOMETER_SOURCES) {
    const { data } = await admin
      .from(table)
      .select(`${column}, entry_date`)
      .eq('vehicle_id', vehicleId)
      .not(column, 'is', null)
      .lte('entry_date', asOf)
      .order(column, { ascending: false })
      .order('entry_date', { ascending: false })
      .limit(1)
      .maybeSingle()
    consider(data?.[column], data?.entry_date)
  }
  return current
}

/// The day a car that stood at [reading] covers [remainingKm] more, at the
/// assumed rate — or null when the reading's day does not parse.
///
/// Counted from the day of the reading, not from today. From today, a car
/// with no new reading kept its distance to go, and with it its days to go: a
/// notice seven days out on Monday was seven days out on Tuesday, and went
/// again.
export function dayAtDistance(
  reading: OdometerReading,
  remainingKm: number,
): Date | null {
  const day = new Date(reading.day)
  day.setUTCDate(
    day.getUTCDate() + Math.round(remainingKm / FALLBACK_KM_PER_DAY),
  )
  return Number.isNaN(day.getTime()) ? null : day
}

/// The earlier of two dates, either of which may be missing.
function earlier(a: Date | null, b: Date | null): Date | null {
  if (a === null || (b !== null && b < a)) {
    return b
  }
  return a
}

export interface DueItem {
  vehicleId: string
  key: string
  dueDate: Date
  /// Set only on a seasonal tyre swap in a country with a dated window, so the
  /// device can say *fit winter tyres* rather than *seasonal tyre swap*. The
  /// device cannot work this out for itself: a push is handled in a background
  /// isolate with no provider container, so it has no idea which country the
  /// household is in.
  swapDirection?: SwapDirection
}

export interface Visit {
  vehicleId: string
  dueDate: Date
  keys: string[]
  swapDirection?: SwapDirection
}

/// What a vehicle's household requires, and whether the car swaps at all.
///
/// Two facts the seasonal swap needs and nothing else does, so they are read
/// only for a vehicle that actually has such a rule — a fleet with no seasonal
/// rules costs no extra query.
export interface SeasonalContext {
  countryCode: string
  swapsSeasonally: boolean
}

export async function seasonalContextFor(
  admin: SupabaseLike,
  vehicleId: string,
): Promise<SeasonalContext> {
  const { data: vehicle } = await admin
    .from('vehicles')
    .select('household_id')
    .eq('id', vehicleId)
    .maybeSingle()

  let countryCode = 'HR'
  if (vehicle?.household_id) {
    const { data: household } = await admin
      .from('households')
      .select('country_code')
      .eq('id', vehicle.household_id)
      .maybeSingle()
    if (typeof household?.country_code === 'string') {
      countryCode = household.country_code
    }
  }

  const { data: tyres } = await admin
    .from('tyre_sets')
    .select('season, retired_at')
    .eq('vehicle_id', vehicleId)

  return {
    countryCode,
    swapsSeasonally: swapsSeasonally(tyres ?? []),
  }
}

/// One message per car per due day, not one per item.
///
/// The app bundles items due near each other into a single visit, and firing
/// one notification per item would undo exactly what that is for. The server
/// cannot reproduce the app's window — that needs the measured driving rate —
/// so it groups by what it does know: the same car, the same day. The device
/// renders whatever arrives, and the id it lands on is derived from the same
/// car, keys and date, so a repeat run replaces rather than stacks.
export function bundleIntoVisits(due: DueItem[]): Visit[] {
  const visits = new Map<string, Visit>()
  for (const item of due) {
    const day = isoDay(item.dueDate)
    const key = `${item.vehicleId}|${day}`
    const visit = visits.get(key)
    if (visit) {
      if (!visit.keys.includes(item.key)) visit.keys.push(item.key)
      // A visit that covers more than the swap is announced as a visit. Naming
      // it after one of its items would hide the others.
      visit.swapDirection = undefined
    } else {
      visits.set(key, {
        vehicleId: item.vehicleId,
        dueDate: item.dueDate,
        keys: [item.key],
        swapDirection: item.swapDirection,
      })
    }
  }
  return [...visits.values()]
}

/// Each visit, posted to the webhooks of the garage that owns the car — or
/// null when no hook in those garages listens for it, which is most runs.
async function announceVisits(
  deps: Deps,
  admin: SupabaseLike,
  visits: Visit[],
  vehicles: VehicleRow[],
  today: Date,
): Promise<number | null> {
  const householdIds = [...new Set(vehicles.map((v) => v.household_id))]
  if (householdIds.length === 0) {
    return null
  }
  const { data: hooks } = await admin
    .from('webhooks')
    .select(`household_id, ${HOOK_COLUMNS}`)
    .in('household_id', householdIds)
    .eq('active', true)
  const listening = ((hooks ?? []) as GarageHook[]).filter((hook) =>
    hook.events.includes(REMINDER_EVENT)
  )

  const calls = visits.flatMap((visit) => {
    const vehicle = vehicles.find((v) => v.id === visit.vehicleId)
    if (!vehicle) {
      return []
    }
    // A webhook belongs to a garage, and hears about the cars that garage
    // owns: not a neighbour's, and not one a member of it only borrows on a
    // guest pass. Matched here as well as asked for above, because one run
    // covers every garage with something due.
    const garageHooks = listening.filter((hook) =>
      hook.household_id === vehicle.household_id
    )
    if (garageHooks.length === 0) {
      return []
    }
    const due: ReminderDue = {
      vehicleId: visit.vehicleId,
      vehicleName: vehicle.nickname,
      keys: visit.keys,
      dueDate: isoDay(visit.dueDate),
      daysUntilDue: dayDiff(today, visit.dueDate),
      swapDirection: visit.swapDirection,
    }
    return [{ hooks: garageHooks, due }]
  })
  if (calls.length === 0) {
    return null
  }

  const delivered = await Promise.all(
    calls.map(({ hooks, due }) =>
      deliver(
        { admin, fetch: deps.fetch, now: deps.now },
        REMINDER_EVENT,
        hooks,
        reminderBody(due, deps.now()),
        reminderMessage(due),
      )
    ),
  )
  return delivered.reduce((sum, count) => sum + count, 0)
}

export function makeHandler(deps: Deps) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 })
    }
    // Only the scheduler may trigger a push run, and "the scheduler" means a
    // caller holding a service-role credential.
    //
    // Checked by *role*, not by string-matching the injected
    // SUPABASE_SERVICE_ROLE_KEY, which is what this used to do and which made
    // the function uncallable: on a project with the newer secret keys, the
    // injected value is an `sb_secret_…` string, while the gateway's own
    // `verify_jwt` only lets a JWT through at all. No caller could satisfy both
    // — the legacy key passed the gateway and failed the comparison (403), the
    // secret key failed the gateway (401) — so every scheduled run since the
    // function was written has been rejected.
    //
    // The signature is already verified by the gateway before this code runs,
    // so reading the role out of the payload is enough; nothing here trusts an
    // unverified token.
    if (!isServiceRole(req.headers.get('Authorization'))) {
      return new Response('Forbidden', { status: 403 })
    }

    // Firebase is what the pushes need, and all it is needed for. Its absence
    // is noted here and acted on only once the hooks have been called: a
    // project that never turned push on still has webhooks, and a phone that
    // has stood its own reminders down is waiting on exactly the pushes this
    // would skip — so the answer says so, every run.
    const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT')
    const skipped = serviceAccountJson
      ? {}
      : { push_skipped: 'FCM_SERVICE_ACCOUNT secret not configured' }

    const admin = deps.createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const today = deps.now()
    const { data: rules, error: rulesError } = await admin
      .from('reminder_rules')
      .select(
        'id, vehicle_id, service_type_key, interval_km, interval_months, one_time, due_date, due_odometer_km',
      )
      .eq('active', true)
    if (rulesError) {
      return json({ error: rulesError.message }, 500)
    }

    const due: DueItem[] = []
    // Read once per vehicle rather than once per rule: a car with a seasonal
    // swap usually has a dozen other rules beside it.
    const seasonalContexts = new Map<string, SeasonalContext>()
    const seasonalContext = async (vehicleId: string) => {
      const cached = seasonalContexts.get(vehicleId)
      if (cached) return cached
      const context = await seasonalContextFor(admin, vehicleId)
      seasonalContexts.set(vehicleId, context)
      return context
    }

    for (const rule of (rules ?? []) as Rule[]) {
      // The seasonal swap is not an interval, whatever the rule says.
      //
      // Two things the client has always done and the server never did, which
      // is the half that matters wherever push is configured: the client stops
      // scheduling dated reminders entirely in that case, so an all-season
      // household was still being told twice a year to swap tyres it does not
      // own, and the date came from a six-month interval anchored on whenever
      // the last swap happened to be logged.
      if (rule.service_type_key === SEASONAL_SWAP_KEY) {
        const context = await seasonalContext(rule.vehicle_id)
        if (!context.swapsSeasonally) continue

        const swap = nextSeasonalSwap(context.countryCode, today)
        if (swap) {
          if (REMINDER_LEAD_DAYS.includes(dayDiff(today, swap.date))) {
            due.push({
              vehicleId: rule.vehicle_id,
              key: rule.service_type_key,
              dueDate: swap.date,
              swapDirection: swap.direction,
            })
          }
          continue
        }
        // No verified window for this country, so the interval below is the
        // only thing there is. Inventing a date would look authoritative and
        // be wrong.
      }

      // A one-off carries its own target and has no history to project from:
      // the vignette was bought, the registration was paid, and the date it
      // runs out is on the rule itself — or the odometer it is good until is.
      // With both, the earlier of the two dates is the one. The app goes by the
      // due date alone unless it has measured how the car is driven, which
      // this never has; here the estimate counts as well. An odometer already
      // passed gives a date already gone, and nothing is sent.
      if (rule.due_date || rule.due_odometer_km) {
        let oneOff = rule.due_date ? new Date(rule.due_date) : null
        if (rule.due_odometer_km) {
          const reading = await currentOdometer(admin, rule.vehicle_id, today)
          if (reading) {
            oneOff = earlier(
              oneOff,
              dayAtDistance(reading, rule.due_odometer_km - reading.km),
            )
          }
        }
        if (oneOff && REMINDER_LEAD_DAYS.includes(dayDiff(today, oneOff))) {
          due.push({
            vehicleId: rule.vehicle_id,
            key: rule.service_type_key,
            dueDate: oneOff,
          })
        }
        continue
      }

      const { data: lastService } = await admin
        .from('service_entries')
        .select('entry_date, odometer_km')
        .eq('vehicle_id', rule.vehicle_id)
        .contains('service_type_keys', [rule.service_type_key])
        .order('entry_date', { ascending: false })
        .limit(1)
        .maybeSingle()

      let dueDate: Date | null = null
      if (rule.interval_months && lastService?.entry_date) {
        dueDate = addMonths(
          new Date(lastService.entry_date),
          rule.interval_months,
        )
      }
      if (rule.interval_km && lastService?.odometer_km != null) {
        // Dated from the furthest reading. The service is itself a reading,
        // and the only one there is when none can be read.
        const reading = furthestReading(
          await currentOdometer(admin, rule.vehicle_id, today),
          { km: lastService.odometer_km, day: lastService.entry_date },
        )
        dueDate = earlier(
          dueDate,
          dayAtDistance(
            reading,
            lastService.odometer_km + rule.interval_km - reading.km,
          ),
        )
      }
      if (dueDate === null) {
        continue
      }
      if (REMINDER_LEAD_DAYS.includes(dayDiff(today, dueDate))) {
        due.push({
          vehicleId: rule.vehicle_id,
          key: rule.service_type_key,
          dueDate,
        })
      }
    }

    if (due.length === 0) {
      return json({ pushed: 0, ...skipped })
    }

    const visits = bundleIntoVisits(due)
    // Vehicle -> household, which both the hooks and the tokens hang off.
    const vehicleIds = [...new Set(due.map((d) => d.vehicleId))]
    const { data: vehicleData } = await admin
      .from('vehicles')
      .select('id, nickname, household_id')
      .in('id', vehicleIds)
    const vehicles = (vehicleData ?? []) as VehicleRow[]

    // The hooks first. Everything after this needs Firebase and can fail for
    // reasons of its own — a secret that does not parse, a token exchange
    // Google refuses — and none of that is any business of a household's
    // webhooks.
    const delivered = await announceVisits(deps, admin, visits, vehicles, today)
    // Only a run that called a hook says how that went, which leaves the
    // answer a project without webhooks gets exactly as it was.
    const announced = delivered === null ? {} : { delivered }

    if (!serviceAccountJson) {
      return json({ pushed: 0, ...announced, ...skipped })
    }
    const serviceAccount = JSON.parse(serviceAccountJson)

    // Household -> member tokens.
    const householdIds = [...new Set(vehicles.map((v) => v.household_id))]
    const { data: members } = await admin
      .from('household_members')
      .select('household_id, user_id')
      .in('household_id', householdIds)
    const userIds = [
      ...new Set(((members ?? []) as MemberRow[]).map((m) => m.user_id)),
    ]
    const { data: tokens } = await admin
      .from('device_tokens')
      .select('token, user_id')
      .in('user_id', userIds)

    const accessToken = await deps.fcmAccessToken(serviceAccount)
    const endpoint =
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`

    let pushed = 0
    const stale: string[] = []

    for (const item of visits) {
      const vehicle = vehicles.find((v) => v.id === item.vehicleId)
      if (!vehicle) continue
      const vehicleMembers = ((members ?? []) as MemberRow[])
        .filter((m) => m.household_id === vehicle.household_id)
        .map((m) => m.user_id)
      const vehicleTokens = ((tokens ?? []) as TokenRow[]).filter((t) =>
        vehicleMembers.includes(t.user_id)
      )
      for (const { token } of vehicleTokens) {
        const response = await deps.fetch(endpoint, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token,
              // Keys, not sentences: the server has no idea what language the
              // person holding this phone reads, and a language stored per
              // device is one more thing that can be stale. The device turns
              // these into words (`lib/core/notifications/push_reminder.dart`).
              data: {
                type: 'reminder_due',
                vehicle_id: item.vehicleId,
                service_type_keys: item.keys.join(','),
                due_date: isoDay(item.dueDate),
                days_until_due: `${dayDiff(today, item.dueDate)}`,
                vehicle_nickname: vehicle.nickname,
                ...(item.swapDirection
                  ? { swap_direction: item.swapDirection }
                  : {}),
              },
            },
          }),
        })
        if (response.ok) {
          pushed++
        } else if (response.status === 404 || response.status === 410) {
          stale.push(token)
        }
      }
    }

    if (stale.length > 0) {
      await admin.from('device_tokens').delete().in('token', stale)
    }

    return json({ pushed, stale: stale.length, ...announced })
  }
}

export const handler = makeHandler({
  createClient,
  fetch: globalThis.fetch,
  now: () => new Date(),
  fcmAccessToken,
})
