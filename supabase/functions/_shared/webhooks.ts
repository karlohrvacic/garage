import { deliveryFor, targetFor } from './chat_targets.ts'

// How a household's webhooks are called, whatever they are being told.
//
// Nothing posts to a receiver directly. The database's triggers write one
// `webhook_outbox` row per event, and `push-due-reminders` writes one per
// garage with something due; one drain (`outbox.ts`) turns each row into a
// delivery per hook that is listening and posts those, first attempts and
// retries alike, through `postDelivery` here. A receiver cannot tell which
// event it heard about from the shape of the call, and should not have to —
// the same signature over the same kind of body, the same headers, the same
// retries and the same record of how it went. Written once, here, so the
// events cannot drift.
//
// Directories under `functions/` whose name starts with `_` are not deployed
// as functions. Each function that imports this has it bundled in when it is
// deployed.

/// A `webhooks` row, as much of it as a delivery needs.
export interface Hook {
  id: string
  url: string
  secret: string
  events: string[]
  /// `auto` unless the household chose a shape the URL cannot imply.
  format?: string
  /// Null: every car in the garage.
  vehicle_ids?: string[] | null
  /// `en`, `hr` or `it`: the language the chat text is written in.
  language?: string
  active?: boolean
}

/// The columns a [Hook] is read from.
export const HOOK_COLUMNS =
  'id, url, secret, events, format, vehicle_ids, language, active'

/// A `webhook_deliveries` row, as much of it as a post needs.
export interface Delivery {
  id: string
  webhook_id: string
  event: string
  body: string
  message: string
  attempts: number
}

/// How long a receiver has to answer before the call is abandoned.
const TIMEOUT_MS = 10_000

/// HMAC-SHA256 of [body] keyed with [secret], as lower-case hex: what
/// `hmac.new(secret, body, hashlib.sha256).hexdigest()` prints on the other
/// end.
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

export interface DeliveryDeps {
  /// The service-role client, to read what is due and record how it went.
  // deno-lint-ignore no-explicit-any
  admin: any
  fetch: typeof fetch
  now: () => Date
}

/// Posts one delivery to its hook and resolves to the HTTP status, 0 when
/// the receiver could not be reached. Writes nothing: the drain records the
/// outcome, because it is the drain that knows whether this was the first
/// attempt or the last.
///
/// Discord answers 400 to any body without `content`, and Slack and Telegram
/// have shapes of their own, so what goes over the wire depends on where it
/// is going. The signature is still sent and still covers the generic body:
/// a chat service ignores the header, and a receiver that checks it is by
/// definition a generic one. The delivery id rides along on every attempt so
/// a receiver can tell a retry from a new call.
export async function postDelivery(
  deps: DeliveryDeps,
  delivery: Delivery,
  hook: Hook,
): Promise<number> {
  const outgoing = deliveryFor(
    targetFor(hook.url, hook.format ?? 'auto'),
    delivery.body,
    delivery.message,
    hook.url,
  )
  const signature = await sign(hook.secret, delivery.body)
  try {
    const response = await deps.fetch(outgoing.url ?? hook.url, {
      method: 'POST',
      headers: {
        'Content-Type': outgoing.contentType,
        'X-Garage-Event': delivery.event,
        'X-Garage-Signature': signature,
        'X-Garage-Delivery': delivery.id,
        ...outgoing.headers,
      },
      body: outgoing.body,
      signal: AbortSignal.timeout(TIMEOUT_MS),
    })
    return response.status
  } catch {
    // A home server that is off, or a URL that no longer resolves.
    return 0
  }
}
