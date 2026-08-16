import { createClient } from 'jsr:@supabase/supabase-js@2'

// Daily push for maintenance items entering their due window. Run by
// pg_cron/scheduler with the service role (see docs/RUNBOOK-push.md); it is
// deliberately simpler than the client's projector: time-interval rules
// project exactly, distance-interval rules approximate with the same
// 30 km/day fallback the client uses when history is thin.
//
// A reminder is pushed when its projected due date is exactly 14, 7, 1, or 0
// days away — running once per day makes those single-shot notifications
// without any bookkeeping table.

const FALLBACK_KM_PER_DAY = 30
const PUSH_AT_DAYS = new Set([14, 7, 1, 0])

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

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }
  // Only the scheduler (holding the service key) may trigger a push run.
  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.includes(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)) {
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

  const due: { vehicleId: string; key: string; days: number }[] = []
  for (const rule of (rules ?? []) as Rule[]) {
    // A one-off carries its own date and has no history to project from: the
    // vignette was bought, the registration was paid, and the date it runs out
    // is on the rule itself.
    if (rule.due_date) {
      const days = dayDiff(today, new Date(rule.due_date))
      if (PUSH_AT_DAYS.has(days)) {
        due.push({
          vehicleId: rule.vehicle_id,
          key: rule.service_type_key,
          days,
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
      const { data: latestFuel } = await admin
        .from('fuel_entries')
        .select('odometer_km')
        .eq('vehicle_id', rule.vehicle_id)
        .order('entry_date', { ascending: false })
        .limit(1)
        .maybeSingle()
      const currentKm = latestFuel?.odometer_km ?? lastService.odometer_km
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
    const days = dayDiff(today, dueDate)
    if (PUSH_AT_DAYS.has(days)) {
      due.push({ vehicleId: rule.vehicle_id, key: rule.service_type_key, days })
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
  for (const item of due) {
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
            data: {
              type: 'reminder_due',
              vehicle_id: item.vehicleId,
              service_type_key: item.key,
              days_until_due: `${item.days}`,
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
