import { createClient } from 'jsr:@supabase/supabase-js@2'

// Daily push for maintenance items entering their due window. Run by
// pg_cron/scheduler with the service role (see docs/RUNBOOK-push.md); it is
// deliberately simpler than the client's projector: time-interval rules
// project exactly, distance-interval rules approximate with the same
// 30 km/day fallback the client uses when history is thin.
//
// A reminder is pushed when its projected due date is exactly one of
// REMINDER_LEAD_DAYS away — running once per day makes those single-shot
// notifications without any bookkeeping table.
//
// Two nudges: a month out to arrange a garage visit, a week out to keep it.
// Seven days alone was too little to get an appointment. The same two days the
// app schedules its own reminders with (`notificationLeadDays`), because a
// household hearing about one oil change on four different days is being
// nagged by two halves of one feature rather than reminded.
// `test/ci/entry_kinds_wired_test.dart` fails if the two lists drift apart.

const FALLBACK_KM_PER_DAY = 30
const REMINDER_LEAD_DAYS = [30, 7]

interface Rule {
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

/// Whether a bearer token is a service-role one.
///
/// The token's signature is verified by the platform ahead of this function;
/// what is left to decide is which role it carries, and an anon token — which
/// every copy of the app holds — must not be able to make the project send
/// notifications to everybody.
function isServiceRole(authorization: string | null): boolean {
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
function isoDay(date: Date): string {
  return date.toISOString().split('T')[0]
}

function dayDiff(from: Date, to: Date): number {
  const a = Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), from.getUTCDate())
  const b = Date.UTC(to.getUTCFullYear(), to.getUTCMonth(), to.getUTCDate())
  return Math.round((b - a) / 86_400_000)
}

function addMonths(date: Date, months: number): Date {
  const result = new Date(date)
  result.setUTCMonth(result.getUTCMonth() + months)
  return result
}

async function fcmAccessToken(serviceAccount: {
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
  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
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
/// it in.
///
/// All of them, not just fill-ups: a household that logs readings without
/// buying fuel — an EV, or anyone who has stopped recording fill-ups — would
/// otherwise have every distance-based reminder projected from an odometer
/// that stopped moving. This mirrors `OdometerHistory` in the app, which is
/// where the same rule is written for the screens.
const ODOMETER_SOURCES: [string, string][] = [
  ['fuel_entries', 'odometer_km'],
  ['service_entries', 'odometer_km'],
  ['cost_entries', 'odometer_km'],
  ['odometer_entries', 'odometer_km'],
  ['trip_entries', 'end_odometer_km'],
  ['income_entries', 'odometer_km'],
]

/// The highest reading any source has for a vehicle, or null when it has none.
///
/// The highest rather than the most recent: an odometer only goes up, so a
/// lower later number is a typo, and reading it as current would push every
/// reminder out by the size of the mistake.
// deno-lint-ignore no-explicit-any
async function currentOdometerKm(
  admin: any,
  vehicleId: string,
): Promise<number | null> {
  let highest: number | null = null
  for (const [table, column] of ODOMETER_SOURCES) {
    const { data } = await admin
      .from(table)
      .select(column)
      .eq('vehicle_id', vehicleId)
      .not(column, 'is', null)
      .order(column, { ascending: false })
      .limit(1)
      .maybeSingle()
    const value = data?.[column]
    if (typeof value === 'number' && (highest === null || value > highest)) {
      highest = value
    }
  }
  return highest
}

Deno.serve(async (req: Request) => {
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

  const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT')
  if (!serviceAccountJson) {
    return new Response(
      JSON.stringify({ error: 'FCM_SERVICE_ACCOUNT secret not configured' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
  const serviceAccount = JSON.parse(serviceAccountJson)

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const today = new Date()
  const { data: rules, error: rulesError } = await admin
    .from('reminder_rules')
    .select(
      'id, vehicle_id, service_type_key, interval_km, interval_months, one_time, due_date',
    )
    .eq('active', true)
  if (rulesError) {
    return new Response(JSON.stringify({ error: rulesError.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const due: { vehicleId: string; key: string; dueDate: Date }[] = []
  for (const rule of (rules ?? []) as Rule[]) {
    // A one-off carries its own date and has no history to project from: the
    // vignette was bought, the registration was paid, and the date it runs out
    // is on the rule itself.
    if (rule.due_date) {
      const oneOff = new Date(rule.due_date)
      if (REMINDER_LEAD_DAYS.includes(dayDiff(today, oneOff))) {
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
      dueDate = addMonths(new Date(lastService.entry_date), rule.interval_months)
    }
    if (rule.interval_km && lastService?.odometer_km != null) {
      const latestKm = await currentOdometerKm(admin, rule.vehicle_id)
      const currentKm = latestKm ?? lastService.odometer_km
      const remainingKm =
        lastService.odometer_km + rule.interval_km - currentKm
      const daysOut = Math.round(remainingKm / FALLBACK_KM_PER_DAY)
      const fromDistance = new Date(today)
      fromDistance.setUTCDate(fromDistance.getUTCDate() + daysOut)
      if (dueDate === null || fromDistance < dueDate) {
        dueDate = fromDistance
      }
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
    return new Response(JSON.stringify({ pushed: 0 }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Vehicle -> household -> member tokens.
  const vehicleIds = [...new Set(due.map((d) => d.vehicleId))]
  const { data: vehicles } = await admin
    .from('vehicles')
    .select('id, nickname, household_id')
    .in('id', vehicleIds)
  const householdIds = [...new Set(((vehicles ?? []) as VehicleRow[]).map((v) => v.household_id))]
  const { data: members } = await admin
    .from('household_members')
    .select('household_id, user_id')
    .in('household_id', householdIds)
  const userIds = [...new Set(((members ?? []) as MemberRow[]).map((m) => m.user_id))]
  const { data: tokens } = await admin
    .from('device_tokens')
    .select('token, user_id')
    .in('user_id', userIds)

  const accessToken = await fcmAccessToken(serviceAccount)
  const endpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`

  let pushed = 0
  const stale: string[] = []
  // One message per car per due day, not one per item.
  //
  // The app bundles items due near each other into a single visit, and firing
  // one notification per item would undo exactly what that is for. The server
  // cannot reproduce the app's window — that needs the measured driving rate —
  // so it groups by what it does know: the same car, the same day. The device
  // renders whatever arrives, and the id it lands on is derived from the same
  // car, keys and date, so a repeat run replaces rather than stacks.
  const visits = new Map<
    string,
    { vehicleId: string; dueDate: Date; keys: string[] }
  >()
  for (const item of due) {
    const day = isoDay(item.dueDate)
    const key = `${item.vehicleId}|${day}`
    const visit = visits.get(key)
    if (visit) {
      if (!visit.keys.includes(item.key)) visit.keys.push(item.key)
    } else {
      visits.set(key, {
        vehicleId: item.vehicleId,
        dueDate: item.dueDate,
        keys: [item.key],
      })
    }
  }

  for (const item of visits.values()) {
    const vehicle = ((vehicles ?? []) as VehicleRow[]).find((v) => v.id === item.vehicleId)
    if (!vehicle) continue
    const vehicleMembers = ((members ?? []) as MemberRow[])
      .filter((m) => m.household_id === vehicle.household_id)
      .map((m) => m.user_id)
    const vehicleTokens = ((tokens ?? []) as TokenRow[]).filter((t) =>
      vehicleMembers.includes(t.user_id),
    )
    for (const { token } of vehicleTokens) {
      const response = await fetch(endpoint, {
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

  return new Response(JSON.stringify({ pushed, stale: stale.length }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
