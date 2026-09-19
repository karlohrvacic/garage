import {
  type Delivery,
  type DeliveryDeps,
  type Hook,
  HOOK_COLUMNS,
  postDelivery,
} from './webhooks.ts'

// What turns an event into calls, and calls into attempts.
//
// Triggers write one row per event into webhook_outbox (migration 0079).
// `queueOutbox` turns each into one webhook_deliveries row per hook that is
// listening, with the body built once and the chat text once per language,
// and `postDue` posts whatever is due — first attempts and retries alike —
// recording each. Both run from `drain`, which the dispatcher runs on every
// poke and the cron runs every five minutes, so a poke that is lost costs a
// receiver five minutes, not the event.

export interface OutboxRow {
  id: string
  household_id: string
  event: string
  payload: Record<string, unknown>
  created_at: string
}

/// What a builder returns: the generic JSON, and the chat text on demand in
/// a language, so a garage with a Croatian Discord and an English Slack gets
/// each in its own words from one body.
export interface Built {
  body: string
  message: (language: string) => string
}

// deno-lint-ignore no-explicit-any
export type Builder = (admin: any, row: OutboxRow) => Promise<Built | null>

/// Minutes to wait before the second, third and fourth attempt. A receiver
/// that is down for an hour gets the event when it is back; one that is gone
/// stops costing anything within the hour.
export const RETRY_MINUTES = [1, 10, 60]
export const MOST_ATTEMPTS = RETRY_MINUTES.length + 1

/// Deliveries given up on, one after another, after which a hook is switched
/// off. Given up on, not merely failed: a receiver that is down for a minute
/// while an import writes a hundred entries has every one of them retried and
/// is never paused, while a URL that is gone is paused once twenty events
/// have each run out of attempts, so a garage that keeps logging stops paying
/// for it.
export const PAUSE_AFTER = 20

/// The one event a hook hears whatever it subscribed to: the app's test
/// button, which a member presses to see this hook answer.
const PING = 'test.ping'

/// How many outbox rows and how many due deliveries one drain takes on. A
/// poke storm from somebody holding the anon key then costs a bounded amount
/// of work that was due anyway.
const OUTBOX_BATCH = 50
const DELIVERY_BATCH = 100

export function subscribed(
  hook: Hook,
  event: string,
  vehicleId: string | null,
): boolean {
  if (hook.active === false) {
    return false
  }
  if (event === PING) {
    return true
  }
  if (!hook.events.includes(event)) {
    return false
  }
  const cars = hook.vehicle_ids
  if (!cars || cars.length === 0 || vehicleId === null) {
    return true
  }
  return cars.includes(vehicleId)
}

const vehicleOf = (row: OutboxRow): string | null =>
  typeof row.payload.vehicle_id === 'string' ? row.payload.vehicle_id : null

/// Outbox rows into delivery rows, oldest first: a sale writes the car
/// returned and then handed over in one transaction, and the receiver hears
/// them in that order.
export async function queueOutbox(
  // deno-lint-ignore no-explicit-any
  admin: any,
  builders: Record<string, Builder>,
  now: () => Date,
): Promise<number> {
  const { data: rows } = await admin
    .from('webhook_outbox')
    .select('id, household_id, event, payload, created_at')
    .is('processed_at', null)
    .order('created_at', { ascending: true })
    .limit(OUTBOX_BATCH)
  let queued = 0
  for (const row of (rows ?? []) as OutboxRow[]) {
    try {
      queued += await queueRow(admin, builders, row, now)
    } catch (cause) {
      // A builder reads the car, the garage and the author, and any of those
      // reads can throw rather than answer; so can the text it writes. The
      // row waits, unprocessed, for the next drain. The rows behind it, other
      // households' among them, do not wait with it.
      console.error(`webhook outbox ${row.id}: ${row.event} not queued`, cause)
    }
  }
  return queued
}

/// One outbox row into its delivery rows, marked processed once they are
/// written. Resolves to how many were written: none when the row was left
/// for the next drain because a read or the write answered with an error,
/// and none when nobody was listening.
async function queueRow(
  // deno-lint-ignore no-explicit-any
  admin: any,
  builders: Record<string, Builder>,
  row: OutboxRow,
  now: () => Date,
): Promise<number> {
  const { data: hooks, error: hooksError } = await admin
    .from('webhooks')
    .select(HOOK_COLUMNS)
    .eq('household_id', row.household_id)
  if (hooksError) {
    // Unread is not unsubscribed: left for the next drain.
    return 0
  }
  const listening = ((hooks ?? []) as Hook[]).filter((hook) =>
    subscribed(hook, row.event, vehicleOf(row))
  )
  const built: Built | null = listening.length === 0
    ? null
    : await builders[row.event]?.(admin, row) ?? null
  let queued = 0
  if (built) {
    const messages = new Map<string, string>()
    const inserts = listening.map((hook) => {
      const language = hook.language ?? 'en'
      if (!messages.has(language)) {
        messages.set(language, built.message(language))
      }
      return {
        outbox_id: row.id,
        webhook_id: hook.id,
        household_id: row.household_id,
        event: row.event,
        body: built.body,
        message: messages.get(language),
      }
    })
    // A poke and the cron can drain at once, and both read this row before
    // either marks it. The unique index on (outbox_id, webhook_id) makes
    // the second write a no-op rather than a second delivery.
    const { error } = await admin
      .from('webhook_deliveries')
      .upsert(inserts, {
        onConflict: 'outbox_id,webhook_id',
        ignoreDuplicates: true,
      })
    if (error) {
      // Left unprocessed for the next drain rather than marked and lost.
      return 0
    }
    queued = inserts.length
  }
  await admin
    .from('webhook_outbox')
    .update({ processed_at: now().toISOString() })
    .eq('id', row.id)
  return queued
}

/// When a delivery that has just failed its [attempts]th attempt is due
/// again.
const retryAt = (at: Date, attempts: number): string =>
  new Date(at.getTime() + RETRY_MINUTES[attempts - 1] * 60_000).toISOString()

/// Posts every delivery whose time has come and records how it went.
export async function postDue(
  deps: DeliveryDeps,
): Promise<{ delivered: number; failed: number }> {
  // Only for hooks that are on. A paused hook's open rows would otherwise
  // sit at the front of the batch until somebody resumed it, and every other
  // hook's rows behind them.
  const { data: due } = await deps.admin
    .from('webhook_deliveries')
    .select(
      'id, webhook_id, event, body, message, attempts, webhooks!inner(active)',
    )
    .eq('webhooks.active', true)
    .is('delivered_at', null)
    .is('given_up_at', null)
    .lte('next_attempt_at', deps.now().toISOString())
    .order('created_at', { ascending: true })
    .limit(DELIVERY_BATCH)
  const hooks = new Map<string, Hook | null>()
  // Hooks whose receiver could not be reached in this pass. One timeout per
  // receiver that is off: twenty deliveries to it would otherwise hold this
  // drain for two hundred seconds.
  const unreachable = new Set<string>()
  let delivered = 0
  let failed = 0
  for (const delivery of (due ?? []) as Delivery[]) {
    if (!hooks.has(delivery.webhook_id)) {
      const { data } = await deps.admin
        .from('webhooks')
        .select(HOOK_COLUMNS)
        .eq('id', delivery.webhook_id)
        .maybeSingle()
      hooks.set(delivery.webhook_id, (data as Hook | null) ?? null)
    }
    const hook = hooks.get(delivery.webhook_id)
    if (!hook || hook.active === false || unreachable.has(hook.id)) {
      // Deleted or paused since the batch was read, or off right now: the
      // row stays where it is, and the next drain picks it up.
      continue
    }
    const attempts = delivery.attempts + 1
    const last = attempts >= MOST_ATTEMPTS
    // Claimed before it is posted, with the record of a failure written
    // already. A poke racing the cron then posts a row once, whichever of
    // them claims it, and a drain that dies mid-post has spent one attempt
    // rather than none. The clock is read here and again after the post,
    // per row: a hundred rows behind a slow receiver would otherwise all be
    // stamped with the time the batch was read, and each wait counted from
    // before its attempt.
    const claimedAt = deps.now()
    const claim: Record<string, unknown> = {
      attempts,
      given_up_at: last ? claimedAt.toISOString() : null,
    }
    if (!last) {
      claim.next_attempt_at = retryAt(claimedAt, attempts)
    }
    const { data: claimed } = await deps.admin
      .from('webhook_deliveries')
      .update(claim)
      .eq('id', delivery.id)
      .eq('attempts', delivery.attempts)
      .select('id')
    if (!claimed || claimed.length === 0) {
      // Another drain has it.
      continue
    }
    let status: number
    try {
      status = await postDelivery(deps, delivery, hook)
    } catch (cause) {
      // `postDelivery` guards the fetch and nothing before it: a secret that
      // cannot key an HMAC (a member can save an empty one) throws in
      // `sign`. The attempt is claimed, so it is recorded as one that did not
      // get through, and the hooks behind this one still get their turn.
      console.error(`webhook delivery ${delivery.id}: not posted`, cause)
      status = 0
    }
    const ok = status >= 200 && status < 300
    const at = deps.now()
    const now = at.toISOString()
    await deps.admin
      .from('webhook_deliveries')
      .update(
        ok
          ? { delivered_at: now, given_up_at: null, last_status: status }
          : { last_status: status },
      )
      .eq('id', delivery.id)
    await deps.admin
      .from('webhooks')
      .update({ last_delivery_at: now, last_delivery_status: status })
      .eq('id', hook.id)
    if (ok) {
      delivered += 1
      continue
    }
    failed += 1
    if (status === 0) {
      unreachable.add(hook.id)
      // By the wait this row was given; when this row was its last attempt,
      // by the first wait, which is what the next row to be tried gets.
      await deferDue(deps, hook.id, at, last ? 1 : attempts)
    }
    if (last) {
      await pauseIfDead(deps, hook)
    }
  }
  return { delivered, failed }
}

/// Pushes back everything else due for a hook whose receiver is off, to
/// when a row that has just failed its [attempts]th attempt is due, without
/// spending an attempt of theirs. Left due, a dead hook's rows would sit at
/// the front of every batch, one hundred at a time, and every other hook's
/// rows behind them would wait until the dead one was paused. A flat minute
/// would not do: the cron runs every five, so the backlog would be due again
/// at every one of its drains.
async function deferDue(
  deps: DeliveryDeps,
  hookId: string,
  at: Date,
  attempts: number,
): Promise<void> {
  await deps.admin
    .from('webhook_deliveries')
    .update({ next_attempt_at: retryAt(at, attempts) })
    .eq('webhook_id', hookId)
    .is('delivered_at', null)
    .is('given_up_at', null)
    .lte('next_attempt_at', at.toISOString())
}

/// Switches a hook off once its last PAUSE_AFTER deliveries were all given
/// up on. Asked only when one has just been, since nothing else can make it
/// so.
async function pauseIfDead(deps: DeliveryDeps, hook: Hook): Promise<void> {
  const { data: recent } = await deps.admin
    .from('webhook_deliveries')
    .select('given_up_at')
    .eq('webhook_id', hook.id)
    .order('created_at', { ascending: false })
    .limit(PAUSE_AFTER)
  const rows = (recent ?? []) as { given_up_at: string | null }[]
  const allGivenUp = rows.length >= PAUSE_AFTER &&
    rows.every((row) => row.given_up_at !== null)
  if (!allGivenUp) {
    return
  }
  await deps.admin
    .from('webhooks')
    .update({ active: false, paused_reason: 'failing' })
    .eq('id', hook.id)
  hook.active = false
}

export async function drain(
  // deno-lint-ignore no-explicit-any
  admin: any,
  deps: DeliveryDeps,
  builders: Record<string, Builder>,
): Promise<{ queued: number; delivered: number; failed: number }> {
  const queued = await queueOutbox(admin, builders, deps.now)
  const posted = await postDue(deps)
  return { queued, ...posted }
}
